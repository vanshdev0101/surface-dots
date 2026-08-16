# apptracker

A Quickshell widget for tracking job applications: which role, which resume
went out, what is due next.

Add and edit entries in the widget itself — every change is written straight
back to `~/.local/share/apptracker/applications.json`, so the file on disk is
the only copy of the truth. There is no separate in-app state to drift out of
sync with it, and the file stays hand-editable and diffable in git.

## Run

```sh
qs -p ~/apptracker
```

Already wired into the Hyprland config: `config/autostart.lua` starts it hidden
at login, and `config/binds.lua` binds **SUPER+SHIFT+A** to toggle it (SUPER+A
was already the notification panel).

```
qs -p ~/apptracker ipc call tracker toggle    # also: show, hide, state
```

`APPTRACKER_START_HIDDEN=1` makes it start hidden — set on the autostart line
only, so running it by hand still shows it immediately.

The panel is created on demand rather than hidden and re-shown: a layer-shell
window that is constructed invisible never gets its surface mapped, so
toggling `visible` on a pre-built window silently does nothing. It appears on
whichever monitor is active when you open it.

## Using it

- **`+`** adds an entry. Click any row to edit or delete it.
- **`×` or Escape** hides the widget. It sits above your windows while open, so
  bind the toggle key below rather than leaving it up.
- **Status** is a chip in the editor and a coloured edge on the row, so what is
  live reads at a glance without a legend: gold drafting, blue submitted or in
  testing, green interview or offer, red rejected, grey closed.
- **Sorting** is by urgency, not entry order — live applications first, soonest
  deadline first, undated below dated, closed always last.
- **The header** counts down to the next date on any application that is still
  alive — rejected, closed and accepted rows are skipped. It turns red once that
  date has passed.
- **Due dates** are typed as `2026-08-17 09:30` and stored ISO-style.

## Data

```json
{
  "version": 1,
  "applications": [
    {
      "id": "keysight-multiphysics",
      "company": "Keysight",
      "role": "Multiphysics Modeling & Engineering Automation Intern",
      "status": "drafting",
      "due": "2026-08-17T09:30",
      "resume": "Vansh-Keysight-Multiphysics.pdf",
      "location": "Gurugram",
      "notes": "free text"
    }
  ]
}
```

`status` is one of `drafting`, `submitted`, `test`, `interview`, `offer`,
`rejected`, `closed`. Every field except `id` may be empty.

If the file is ever corrupt, the widget says so in the header and **refuses to
save over it** — fix the JSON by hand and it reloads on its own, since the file
is watched.

## Tests

```sh
./tests/run.sh
```

Drives the store through add, edit, delete, ordering and the next-deadline
calculation against a throwaway data directory, asserting after each step that
the change actually reached the disk rather than only the model. The UI cannot
be clicked from a script, so this covers the persistence path underneath it;
the QML views themselves are verified by looking at them.

## Layout

| File | |
|---|---|
| `shell.qml` | Panel window, header, list, row rendering |
| `Store.qml` | The JSON file: load, save, sort, deadline maths |
| `Editor.qml` | Add/edit form |
| `theme.js` | Everforest tokens, matched to surface-dots |

`theme.js` is a deliberate copy of the palette from
`surface-dots/.config/quickshell/theme.js` rather than an import, so this
config runs standalone. If the rice palette changes, copy it across — or point
the import at the rice and drop this file.
