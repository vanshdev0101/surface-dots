import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../lib" as Lib

Item {
    id: root
    Layout.fillWidth: true

    property QtObject parentTheme: null
    property bool active: false
    signal wallpaperRequested()
    signal backRequested()
    signal toastRequested(string msg)

    readonly property QtObject theme: parentTheme
    readonly property bool themed: parentTheme !== null

    property real contentHeight: contentLayout.implicitHeight + 8
    implicitHeight: root.active ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    visible: implicitHeight > 1
    clip: true

    // --- Color helpers (ported from task-bar's SettingsPanel.qml) ------------
    function hexToHsl(hex) {
        hex = String(hex).replace(/[^0-9a-fA-F]/g, '')
        if (hex.length !== 6) return {h:0,s:50,l:50}
        var r=parseInt(hex.slice(0,2),16)/255, g=parseInt(hex.slice(2,4),16)/255, b=parseInt(hex.slice(4,6),16)/255
        var mx=Math.max(r,g,b), mn=Math.min(r,g,b), h=0, s=0, l=(mx+mn)/2
        if (mx!==mn){var d=mx-mn;s=l>0.5?d/(2-mx-mn):d/(mx+mn);if(mx===r)h=((g-b)/d+(g<b?6:0))/6;else if(mx===g)h=((b-r)/d+2)/6;else h=((r-g)/d+4)/6}
        return {h:Math.round(h*360),s:Math.round(s*100),l:Math.round(l*100)}
    }
    function hslToHex(h,s,l){s/=100;l/=100;var a=s*Math.min(l,1-l);function f(n){var k=(n+h/30)%12,c=l-a*Math.max(Math.min(k-3,9-k,1),-1),v=Math.round(255*c);return(v<16?'0':'')+v.toString(16)}return '#'+f(0)+f(8)+f(4)}
    function validHex(s){return /^#[0-9a-fA-F]{6}$/.test(String(s))}
    function hex6(c){var s=String(c);return s.length===9 ? "#"+s.slice(3) : s}

    // Currently-active power-menu accent field name, based on style + theme mode
    function currentPmAccentKey() {
        var style = Lib.Configuration.powerMenuStyle === "cassini" ? "Cassini" : "Life"
        var mode = (root.themed && root.parentTheme.isDarkMode) ? "Dark" : "Light"
        return "powerMenu" + style + "Accent" + mode
    }
    function currentPmAccentValue() {
        var key = currentPmAccentKey()
        var v = Lib.Configuration[key]
        if (v && v !== "") return v
        // fall back to each skin's own built-in default
        var dark = root.themed && root.parentTheme.isDarkMode
        if (Lib.Configuration.powerMenuStyle === "cassini") return dark ? "#d57fb069" : "#759b61"
        return dark ? "#859866" : "#6c8453"
    }

    ColumnLayout {
        id: contentLayout
        // root is a plain Item, not a Layout, so Layout.fillWidth here was a no-op and
        // the column collapsed to its implicit width -- which is what made the cards overlap.
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Rectangle {
                width: 26; height: 26; radius: 6
                color: root.theme ? root.theme.bgItem : "#2d353b"
                border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                Text { anchors.centerIn: parent; text: "←"; color: root.theme ? root.theme.textPrimary : "#dde5df"; font.pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.backRequested() }
            }
            Text {
                text: "Settings"
                color: root.theme ? root.theme.textPrimary : "#dde5df"
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 16; font.weight: 700
            }
            Item { Layout.fillWidth: true }
        }

        ColumnLayout {
            id: cardsGrid
            Layout.fillWidth: true
            spacing: 8

            // ---------------- Appearance (full width) ----------------
            SCard {
                label: "Appearance"
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    SLabel { text: "Theme" }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 70; height: 26; radius: 6
                        color: root.theme ? root.theme.bgItem : "#2d353b"
                        border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                        Text {
                            anchors.centerIn: parent
                            text: root.themed && root.parentTheme.isDarkMode ? "Dark" : "Light"
                            color: root.theme ? root.theme.accent : "#a7c080"; font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c",
                                "bash ~/.config/quickshell/top-bar/bar/theme-mode.sh " +
                                (root.themed && root.parentTheme.isDarkMode ? "light" : "dark")])
                        }
                    }
                }

                SDivider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    CPicker {
                        Layout.fillWidth: true; label: "Hub accent"
                        currentHex: Lib.Configuration.useCustomColors ? root.hex6(Lib.Configuration.customAccent)
                                                                        : root.hex6(root.theme ? root.theme.accent : "#a7c080")
                        onPicked: (hex) => { Lib.Configuration.customAccent = hex; Lib.Configuration.useCustomColors = true; Lib.Configuration.save() }
                    }
                    CPicker {
                        Layout.fillWidth: true; label: "Background"
                        currentHex: Lib.Configuration.useCustomColors ? root.hex6(Lib.Configuration.customBg)
                                                                        : root.hex6(root.theme ? root.theme.bgMain : "#141719")
                        onPicked: (hex) => { Lib.Configuration.customBg = hex; Lib.Configuration.useCustomColors = true; Lib.Configuration.save() }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    SBtn { label: "Reset colors"; onTriggered: { Lib.Configuration.useCustomColors = false; Lib.Configuration.save() } }
                    Item { Layout.fillWidth: true }
                    SBtn { label: "Wallpaper"; accent: true; onTriggered: root.wallpaperRequested() }
                }
            }

            // ---------------- Weather API + Power Menu (side by side) ----------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SCard {
                    label: "Weather API"
                    Layout.fillWidth: true; Layout.fillHeight: true

                    SField {
                        label: "API Key (OpenWeatherMap)"
                        text: Lib.Configuration.weatherApiKey
                        isPassword: true
                        onEditingFinished: { Lib.Configuration.weatherApiKey = text; Lib.Configuration.save() }
                    }
                    SField {
                        label: "Latitude"
                        text: Lib.Configuration.weatherLat
                        onEditingFinished: { Lib.Configuration.weatherLat = text; Lib.Configuration.save() }
                    }
                    SField {
                        label: "Longitude"
                        text: Lib.Configuration.weatherLon
                        onEditingFinished: { Lib.Configuration.weatherLon = text; Lib.Configuration.save() }
                    }
                }

                SCard {
                    label: "Power Menu"
                    Layout.fillWidth: true; Layout.fillHeight: true

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        SBtn {
                            label: "Living Things"; accent: Lib.Configuration.powerMenuStyle !== "cassini"
                            onTriggered: { Lib.Configuration.powerMenuStyle = "life"; Lib.Configuration.save() }
                        }
                        SBtn {
                            label: "Cassini"; accent: Lib.Configuration.powerMenuStyle === "cassini"
                            onTriggered: { Lib.Configuration.powerMenuStyle = "cassini"; Lib.Configuration.save() }
                        }
                    }

                    SDivider {}

                    CPicker {
                        Layout.fillWidth: true; label: "Accent"
                        currentHex: root.currentPmAccentValue()
                        onPicked: (hex) => { Lib.Configuration[root.currentPmAccentKey()] = hex; Lib.Configuration.save() }
                    }
                    SLabel {
                        text: (Lib.Configuration.powerMenuStyle === "cassini" ? "Cassini" : "Living Things") + " · "
                              + ((root.themed && root.parentTheme.isDarkMode) ? "dark mode" : "light mode")
                        font.pixelSize: 11; opacity: 0.55
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        SBtn { label: "Reset accents"; onTriggered: Lib.Configuration.resetPowerMenuAccents() }
                        Item { Layout.fillWidth: true }
                    }

                    SLabel {
                        text: "Per light/dark theme accent for the ALT+F4 power menu."
                        font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
                    }
                }
            }

            // ---------------- Layout & Bar (half width) ----------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SCard {
                    label: "Layout & Bar"
                    Layout.fillWidth: true; Layout.fillHeight: true

                    RowLayout {
                        Layout.fillWidth: true
                        SLabel { text: "Bar height" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Lib.Configuration.barExclusiveZone + " px"
                            font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 13
                            color: root.theme ? root.theme.textSecondary : "#888"
                        }
                    }
                    SSlider {
                        from: 30; to: 80; value: Lib.Configuration.barExclusiveZone
                        onMoved: (v) => { Lib.Configuration.barExclusiveZone = v; Lib.Configuration.save() }
                    }

                    SDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        SBtn {
                            label: "→ Task-bar layout"; accent: true
                            onTriggered: Quickshell.execDetached(["bash", "-c",
                                "pkill -f '^qs -c'; sleep 0.5; setsid qs -c task-bar >/dev/null 2>&1 & disown"])
                        }
                    }
                }

                // ---------------- Screen Borders (half width) ----------------
                SCard {
                    label: "Screen Borders"
                    Layout.fillWidth: true; Layout.fillHeight: true

                    SToggle {
                        label: "Enabled"; checked: Lib.Configuration.bordersEnabled
                        onToggled: (v) => {
                            Lib.Configuration.bordersEnabled = v; Lib.Configuration.save()
                            if (v) root.toastRequested("adjust gaps_out in your hypr config")
                        }
                    }
                    SToggle {
                        label: "Always visible"; checked: Lib.Configuration.bordersForceVisible
                        onToggled: (v) => {
                            Lib.Configuration.bordersForceVisible = v; Lib.Configuration.save()
                            if (v) root.toastRequested("adjust gaps_out in your hypr config")
                        }
                    }
                    SDivider {}
                    RowLayout {
                        Layout.fillWidth: true
                        SLabel { text: "Thickness" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Lib.Configuration.borderThickness + " px"
                            font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 13
                            color: root.theme ? root.theme.textSecondary : "#888"
                        }
                    }
                    SSlider {
                        from: 1; to: 20; value: Lib.Configuration.borderThickness
                        onMoved: (v) => {
                            Lib.Configuration.borderThickness = v; Lib.Configuration.save()
                            root.toastRequested("adjust gaps_out in your hypr config")
                        }
                    }
                    SDivider {}
                    SToggle {
                        label: "Custom border color"; checked: Lib.Configuration.borderUseCustomColor
                        onToggled: (v) => { Lib.Configuration.borderUseCustomColor = v; Lib.Configuration.save() }
                    }
                    CPicker {
                        Layout.fillWidth: true; label: "Border color"
                        currentHex: root.hex6(Lib.Configuration.borderFrameColor)
                        onPicked: (hex) => { Lib.Configuration.borderFrameColor = hex; Lib.Configuration.save() }
                    }
                }
            }

            // ---------------- Profile (full width) ----------------
            SCard {
                label: "Profile"
                Layout.fillWidth: true

                SField {
                    label: "Profile picture path"
                    text: Lib.Configuration.profileImageOverride
                    onEditingFinished: { Lib.Configuration.profileImageOverride = text; Lib.Configuration.save() }
                }
                SField {
                    label: "GitHub username (for the Hub's GitHub card)"
                    text: Lib.Configuration.githubUsername
                    onEditingFinished: { Lib.Configuration.githubUsername = text; Lib.Configuration.save() }
                }
            }
        }
    }

    // ==================== Inline components (ported from task-bar) ====================

    component SCard: Rectangle {
        id: sc
        default property alias items: scCol.data
        property string label: ""
        Layout.fillWidth: true
        color: root.theme ? root.theme.bgCard : "#1e2326"
        radius: root.theme ? root.theme.radiusOuter : 12
        border.width: 1
        border.color: scHov.hovered
            ? Qt.rgba(root.theme ? root.theme.accent.r : 0.46, root.theme ? root.theme.accent.g : 0.61, root.theme ? root.theme.accent.b : 0.38, 0.45)
            : (root.theme ? root.theme.outline : "#333")
        implicitHeight: scCol.implicitHeight + 20
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        HoverHandler { id: scHov }

        ColumnLayout {
            id: scCol
            anchors { fill: parent; margins: 10 }
            spacing: 8
            Text {
                text: sc.label
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 16; font.weight: 600
                color: root.theme ? root.theme.accent : "#9da9a0"
                opacity: 0.8
                Layout.bottomMargin: 2
            }
        }
    }

    component SLabel: Text {
        font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
        color: root.theme ? root.theme.textPrimary : "#dde5df"; Layout.fillWidth: true
    }

    component SDivider: Rectangle {
        Layout.fillWidth: true; height: 1
        color: root.theme ? root.theme.outline : "#333"; opacity: 0.5
    }

    component SField: ColumnLayout {
        id: sf; property string label: ""; property alias text: sfIn.text; property bool isPassword: false
        signal editingFinished()
        Layout.fillWidth: true; spacing: 3
        Text { text: sf.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 13
            color: root.theme ? root.theme.textSecondary : "#888" }
        Rectangle {
            Layout.fillWidth: true; height: 30; radius: 7
            color: sfIn.activeFocus
                ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.07) : "#2d353b")
                : sfHov.hovered ? (root.theme ? root.theme.bgItemHover : "#374145")
                : (root.theme ? root.theme.bgItem : "#2d353b")
            Behavior on color { ColorAnimation { duration: 150 } }
            border.width: 1; border.color: sfIn.activeFocus ? (root.theme ? root.theme.accent : "#759b61")
                : sfHov.hovered ? Qt.rgba(root.theme ? root.theme.accent.r : 0.46, root.theme ? root.theme.accent.g : 0.61, root.theme ? root.theme.accent.b : 0.38, 0.35)
                : (root.theme ? root.theme.outline : "#333")
            Behavior on border.color { ColorAnimation { duration: 150 } }
            HoverHandler { id: sfHov }
            TextInput {
                id: sfIn
                anchors { fill: parent; margins: 7 }
                verticalAlignment: Text.AlignVCenter
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 13
                color: root.theme ? root.theme.textPrimary : "#dde5df"; clip: true; selectByMouse: true
                echoMode: sf.isPassword ? TextInput.Password : TextInput.Normal
                selectionColor: root.theme ? Qt.rgba(root.theme.accent.r,root.theme.accent.g,root.theme.accent.b,0.35) : "#40759b61"
                onEditingFinished: sf.editingFinished()
            }
        }
    }

    component SToggle: Item {
        id: tog; property string label: ""; property bool checked: false
        signal toggled(bool v)
        Layout.fillWidth: true
        implicitHeight: togRow.implicitHeight + 10

        Rectangle {
            anchors { fill: parent; leftMargin: -4; rightMargin: -4 }
            radius: 8
            color: togHov.hovered
                ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.08) : "#1e2326")
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        HoverHandler { id: togHov; cursorShape: Qt.PointingHandCursor }

        RowLayout {
            id: togRow
            anchors { fill: parent; topMargin: 5; bottomMargin: 5 }
            spacing: 8
            Text {
                text: tog.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 15
                color: root.theme ? root.theme.textPrimary : "#dde5df"; Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 42; height: 24; radius: 12
                color: tog.checked ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.subtleFill : "#2d353b")
                Behavior on color { ColorAnimation { duration: 200 } }
                border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                Rectangle {
                    x: tog.checked ? parent.width-width-3 : 3; y: 3; width: 18; height: 18; radius: 9; color: "white"
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tog.toggled(!tog.checked) }
            }
        }
    }

    component SSlider: Item {
        id: ssl; property int from: 1; property int to: 20; property int value: 7
        signal moved(int v)
        height: 28; Layout.fillWidth: true
        HoverHandler { id: slHov }
        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: slHov.hovered ? 7 : 5; radius: 3
            color: root.theme ? root.theme.bgItem : "#2d353b"; border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Rectangle {
                width: (ssl.value-ssl.from)/Math.max(1,ssl.to-ssl.from)*parent.width
                height: parent.height; radius: parent.radius
                color: root.theme ? root.theme.accent : "#759b61"
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        Rectangle {
            x: (ssl.value-ssl.from)/Math.max(1,ssl.to-ssl.from)*(ssl.width-width)
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9; color: "white"
            border.width: 2
            border.color: sDrag.pressed ? (root.theme ? root.theme.accent : "#759b61")
                        : slHov.hovered ? Qt.rgba(root.theme ? root.theme.accent.r : 0.46, root.theme ? root.theme.accent.g : 0.61, root.theme ? root.theme.accent.b : 0.38, 0.6)
                        : Qt.rgba(0,0,0,0.25)
            scale: sDrag.pressed ? 1.18 : (slHov.hovered ? 1.09 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: sDrag; anchors.fill: parent; anchors.margins: -5
            function go(mx) { var f=Math.max(0,Math.min(1,mx/ssl.width)); var v=Math.round(ssl.from+f*(ssl.to-ssl.from)); ssl.value=v; ssl.moved(v) }
            onPressed: (m)=>go(m.x); onPositionChanged: (m)=>go(m.x)
        }
    }

    component SBtn: Item {
        id: sb; property string label: ""; property bool accent: false
        signal triggered()
        implicitWidth: bTxt.implicitWidth+22; implicitHeight: 30
        scale: bMa.containsPress ? 0.91 : (bMa.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Rectangle {
            anchors.fill: parent; radius: 8
            color: sb.accent
                ? (bMa.containsPress ? Qt.darker(root.theme ? root.theme.accent : "#759b61", 1.08)
                    : bMa.containsMouse ? Qt.lighter(root.theme ? root.theme.accent : "#759b61", 1.14)
                    : (root.theme ? root.theme.accent : "#759b61"))
                : (bMa.containsPress ? (root.theme ? root.theme.bgItem : "#2d353b")
                    : bMa.containsMouse ? (root.theme ? root.theme.subtleFillHover : "#374145")
                    : (root.theme ? root.theme.subtleFill : "#2d353b"))
            Behavior on color { ColorAnimation { duration: 100 } }
            border.width: 1
            border.color: sb.accent
                ? Qt.rgba(1,1,1, bMa.containsMouse ? 0.18 : 0.0)
                : (root.theme ? root.theme.outline : "#333")
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Text { id: bTxt; anchors.centerIn: parent; text: sb.label
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                color: sb.accent ? (root.theme ? root.theme.textOnAccent : "#232a2e") : (root.theme ? root.theme.textPrimary : "#dde5df") }
        }
        MouseArea { id: bMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: sb.triggered() }
    }

    // Color picker: label + swatch + hex input, click swatch to expand H/S/L
    component CPicker: ColumnLayout {
        id: cp; property string label: ""; property string currentHex: "#759b61"
        signal picked(string hex)
        Layout.fillWidth: true; spacing: 5

        property int  _h: 0; property int _s: 50; property int _l: 50
        property bool _open: false; property bool _lock: false; property bool _userEditing: false

        onCurrentHexChanged: {
            if (!_userEditing && !_lock && root.validHex(currentHex)) {
                _lock = true
                var hsl=root.hexToHsl(currentHex); _h=hsl.h; _s=hsl.s; _l=hsl.l
                hexIn.text=currentHex
                _lock = false
            }
        }
        Timer { id: editReset; interval: 300; onTriggered: cp._userEditing = false }
        function applyHex(hex) {
            if (_lock) return; _lock=true; _userEditing=true; editReset.restart()
            if (root.validHex(hex)) { hexIn.text=hex; var hsl=root.hexToHsl(hex); _h=hsl.h; _s=hsl.s; _l=hsl.l; cp.picked(hex) }
            _lock=false
        }
        function applyHsl() {
            if (_lock) return; _lock=true; _userEditing=true; editReset.restart()
            var hex=root.hslToHex(_h,_s,_l); hexIn.text=hex; cp.picked(hex); _lock=false
        }
        Component.onCompleted: {
            if (root.validHex(currentHex)) { var hsl=root.hexToHsl(currentHex); _h=hsl.h; _s=hsl.s; _l=hsl.l; hexIn.text=currentHex }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Text { text: cp.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                color: root.theme ? root.theme.textPrimary : "#dde5df"
                Layout.fillWidth: true; elide: Text.ElideRight; clip: true }
            Rectangle {
                width: 24; height: 24; radius: 6
                color: root.validHex(hexIn.text) ? hexIn.text : (root.theme ? root.theme.accent : "#759b61")
                border.width: 2; border.color: cp._open ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.outline : "#333")
                Behavior on color { ColorAnimation { duration: 100 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp._open=!cp._open }
            }
            Rectangle {
                width: 82; height: 26; radius: 6
                color: root.theme ? root.theme.bgItem : "#2d353b"
                border.width: 1; border.color: hexIn.activeFocus ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.outline : "#333")
                Behavior on border.color { ColorAnimation { duration: 150 } }
                TextInput {
                    id: hexIn
                    anchors { fill: parent; margins: 5 }
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 12; font.letterSpacing: 0.5
                    color: root.theme ? root.theme.textPrimary : "#dde5df"; clip: true; selectByMouse: true
                    selectionColor: root.theme ? Qt.rgba(root.theme.accent.r,root.theme.accent.g,root.theme.accent.b,0.35) : "#40759b61"
                    validator: RegularExpressionValidator { regularExpression: /^#?[0-9a-fA-F]{0,6}$/ }
                    onEditingFinished: { var h=text.startsWith('#')?text:'#'+text; cp.applyHex(h) }
                }
            }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: cp._open ? sliderCol.implicitHeight + 4 : 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            ColumnLayout {
                id: sliderCol; width: parent.width; spacing: 5
                CSlider { label: "H"; value: cp._h/360
                    c0:"#ff0000"; c1:"#ffff00"; c2:"#00ff00"; c3:"#00ffff"; c4:"#0000ff"; c5:"#ff00ff"; c6:"#ff0000"
                    onMv: (v)=>{cp._h=Math.round(v*360); cp.applyHsl()} }
                CSlider { label: "S"; value: cp._s/100
                    c0:Qt.hsla(cp._h/360,0,cp._l/100,1); c1:Qt.hsla(cp._h/360,0.17,cp._l/100,1)
                    c2:Qt.hsla(cp._h/360,0.33,cp._l/100,1); c3:Qt.hsla(cp._h/360,0.5,cp._l/100,1)
                    c4:Qt.hsla(cp._h/360,0.67,cp._l/100,1); c5:Qt.hsla(cp._h/360,0.83,cp._l/100,1)
                    c6:Qt.hsla(cp._h/360,1,cp._l/100,1)
                    onMv: (v)=>{cp._s=Math.round(v*100); cp.applyHsl()} }
                CSlider { label: "L"; value: cp._l/100
                    c0:"#000000"; c1:Qt.hsla(cp._h/360,cp._s/100,0.17,1)
                    c2:Qt.hsla(cp._h/360,cp._s/100,0.33,1); c3:Qt.hsla(cp._h/360,cp._s/100,0.5,1)
                    c4:Qt.hsla(cp._h/360,cp._s/100,0.67,1); c5:Qt.hsla(cp._h/360,cp._s/100,0.83,1)
                    c6:"#ffffff"
                    onMv: (v)=>{cp._l=Math.round(v*100); cp.applyHsl()} }
            }
        }
    }

    component CSlider: RowLayout {
        id: cs; property string label: ""; property real value: 0.5
        property color c0:"black"; property color c1:"black"; property color c2:"gray"
        property color c3:"gray";  property color c4:"gray";  property color c5:"white"; property color c6:"white"
        signal mv(real v)
        Layout.fillWidth: true; spacing: 5
        Text { text: cs.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 10
            color: root.theme ? root.theme.textSecondary : "#888"; width: 10 }
        Item {
            Layout.fillWidth: true; height: 20
            Rectangle {
                id: csTk; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 8; radius: 4; border.width: 1; border.color: Qt.rgba(0,0,0,0.2)
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0.000; color: cs.c0 }
                    GradientStop { position: 0.167; color: cs.c1 }
                    GradientStop { position: 0.333; color: cs.c2 }
                    GradientStop { position: 0.500; color: cs.c3 }
                    GradientStop { position: 0.667; color: cs.c4 }
                    GradientStop { position: 0.833; color: cs.c5 }
                    GradientStop { position: 1.000; color: cs.c6 }
                }
            }
            Rectangle {
                x: Math.max(0,Math.min(cs.value*(parent.width-width),parent.width-width))
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8; color: "white"
                border.width: 2; border.color: csDrag.pressed ? (root.theme ? root.theme.accent : "#759b61") : Qt.rgba(0,0,0,0.3)
                scale: csDrag.pressed ? 1.12 : 1.0; Behavior on scale { NumberAnimation { duration: 100 } }
            }
            MouseArea { id: csDrag; anchors.fill: parent; anchors.margins: -4
                onPressed:        (m)=>cs.mv(Math.max(0,Math.min(1,m.x/csTk.width)))
                onPositionChanged:(m)=>cs.mv(Math.max(0,Math.min(1,m.x/csTk.width)))
            }
        }
    }
}
