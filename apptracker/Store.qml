import QtQuick
import Quickshell
import Quickshell.Io

// Owns the JSON file. Every mutation goes through here and is written
// straight back to disk, so the file on disk is the only copy of the truth --
// there is no in-memory draft that can drift away from it.
Item {
    id: root

    property string path: Quickshell.env("HOME") + "/.local/share/apptracker/applications.json"

    property var apps: []
    property bool ready: false
    property string error: ""

    // Soonest real deadline first, then by status weight, then alphabetical.
    // A closed application never outranks a live one however near its date.
    readonly property var sorted: {
        const weight = {
            drafting: 0, test: 1, interview: 1, submitted: 2,
            offer: 3, rejected: 4, closed: 4
        };
        return apps.slice().sort(function (a, b) {
            const wa = weight[a.status] === undefined ? 2 : weight[a.status];
            const wb = weight[b.status] === undefined ? 2 : weight[b.status];
            if (wa !== wb) return wa - wb;

            const da = a.due ? Date.parse(a.due) : NaN;
            const db = b.due ? Date.parse(b.due) : NaN;
            const va = isNaN(da), vb = isNaN(db);
            if (va !== vb) return va ? 1 : -1;   // undated sinks below dated
            if (!va && da !== db) return da - db;

            return (a.company + a.role).localeCompare(b.company + b.role);
        });
    }

    readonly property var nextDue: {
        const now = Date.now();
        let best = null;
        for (const a of apps) {
            if (a.status === "closed" || a.status === "rejected" || a.status === "offer") continue;
            if (!a.due) continue;
            const t = Date.parse(a.due);
            if (isNaN(t) || t < now) continue;
            if (best === null || t < Date.parse(best.due)) best = a;
        }
        return best;
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onLoaded: root.parse(file.text())
        onFileChanged: reload()
        onLoadFailed: function (err) {
            // First run: no file yet. Seed one rather than sitting broken.
            root.apps = [];
            root.ready = true;
            root.save();
        }
        onSaveFailed: function (err) {
            root.error = "could not write " + root.path;
        }
    }

    function parse(text) {
        try {
            const doc = JSON.parse(text);
            const list = Array.isArray(doc) ? doc : (doc.applications || []);
            root.apps = list.map(normalise);
            root.error = "";
        } catch (e) {
            // Keep whatever is on screen and say so, rather than silently
            // replacing the user's list with an empty one.
            root.error = "applications.json is not valid JSON -- not overwriting it";
        }
        root.ready = true;
    }

    function normalise(a) {
        return {
            id: a.id || String(Date.now()) + Math.random().toString(16).slice(2, 6),
            company: a.company || "",
            role: a.role || "",
            status: a.status || "drafting",
            due: a.due || "",
            resume: a.resume || "",
            location: a.location || "",
            notes: a.notes || ""
        };
    }

    function save() {
        if (root.error.indexOf("not valid JSON") !== -1) return;  // refuse to clobber
        file.setText(JSON.stringify({ version: 1, applications: root.apps }, null, 2) + "\n");
    }

    function upsert(entry) {
        const next = root.apps.slice();
        const i = next.findIndex(function (a) { return a.id === entry.id; });
        if (i === -1) next.push(normalise(entry));
        else next[i] = normalise(entry);
        root.apps = next;
        save();
    }

    function remove(id) {
        root.apps = root.apps.filter(function (a) { return a.id !== id; });
        save();
    }

    function blank() {
        return normalise({ status: "drafting" });
    }

    // "in 18h", "in 3d", "today", "2d ago" -- a countdown is the one number
    // that actually changes behaviour.
    function relative(due) {
        if (!due) return "";
        const t = Date.parse(due);
        if (isNaN(t)) return "";
        const mins = Math.round((t - Date.now()) / 60000);
        const abs = Math.abs(mins);
        let s;
        if (abs < 60) s = abs + "m";
        else if (abs < 60 * 24) s = Math.round(abs / 60) + "h";
        else s = Math.round(abs / (60 * 24)) + "d";
        return mins >= 0 ? "in " + s : s + " ago";
    }

    function overdue(due) {
        if (!due) return false;
        const t = Date.parse(due);
        return !isNaN(t) && t < Date.now();
    }

    function formatDate(due) {
        if (!due) return "no date";
        const d = new Date(due);
        if (isNaN(d.getTime())) return due;
        return Qt.formatDateTime(d, "ddd d MMM, HH:mm");
    }
}
