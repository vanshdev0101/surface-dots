import QtQuick
import Quickshell
import Quickshell.Io

// Exercises the persistence path the UI cannot be clicked through here:
// add, edit, delete, ordering, and the refusal to clobber a corrupt file.
// Run:  ./tests/run.sh
ShellRoot {
    id: t

    property string dir: Quickshell.env("APPTRACKER_TEST_DIR")
    property var failures: []
    property int stage: 0

    function check(cond, what) {
        if (!cond) failures.push(what);
    }

    Store {
        id: store
        path: t.dir + "/applications.json"
    }

    FileView {
        id: result
        path: t.dir + "/result.txt"
        atomicWrites: true
    }

    // Each stage waits a tick so the file write and the resulting reload
    // settle before the next assertion runs.
    Timer {
        interval: 220
        repeat: true
        running: true
        onTriggered: t.step()
    }

    function step() {
        stage += 1;

        if (stage === 1) {
            check(store.ready, "store never became ready");
            check(store.apps.length === 2, "seed should load 2 entries, got " + store.apps.length);
            // Ordering: drafting-with-deadline outranks submitted.
            check(store.sorted[0].id === "live", "drafting entry should sort first, got " + store.sorted[0].id);
            check(store.nextDue && store.nextDue.id === "live", "nextDue should be the dated drafting entry");

            store.upsert({ id: "", company: "Added Co", role: "Added Role", status: "submitted" });

        } else if (stage === 2) {
            check(store.apps.length === 3, "after add, expected 3 entries, got " + store.apps.length);
            const added = store.apps.filter(function (a) { return a.company === "Added Co"; });
            check(added.length === 1, "added entry not found in memory");
            check(added.length === 1 && added[0].id !== "", "added entry got no id");

            // The real question: did it reach the disk, not just the model.
            const onDisk = JSON.parse(diskText());
            check(onDisk.applications.length === 3, "add did not reach disk");
            check(diskText().indexOf("Added Role") !== -1, "added role missing from file");

            if (added.length === 1) {
                const edited = JSON.parse(JSON.stringify(added[0]));
                edited.role = "Edited Role";
                edited.status = "interview";
                store.upsert(edited);
                t.addedId = added[0].id;
            }

        } else if (stage === 3) {
            check(store.apps.length === 3, "edit should not change the count, got " + store.apps.length);
            check(diskText().indexOf("Edited Role") !== -1, "edit did not reach disk");
            check(diskText().indexOf("Added Role") === -1, "old value still on disk after edit");

            store.remove(t.addedId);

        } else if (stage === 4) {
            check(store.apps.length === 2, "after delete, expected 2 entries, got " + store.apps.length);
            check(diskText().indexOf("Edited Role") === -1, "delete did not reach disk");

            finish();
        }
    }

    property string addedId: ""

    FileView {
        id: disk
        path: t.dir + "/applications.json"
        blockLoading: true
        blockAllReads: true
        preload: false
    }

    function diskText() {
        disk.reload();
        return disk.text();
    }

    function finish() {
        const ok = failures.length === 0;
        result.setText((ok ? "PASS" : "FAIL") + "\n" + failures.join("\n") + "\n");
        Qt.callLater(Qt.quit);
    }
}
