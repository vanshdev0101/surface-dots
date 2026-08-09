import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Lib.Card {
    id: root
    Layout.fillWidth: true

    property bool active: false

    readonly property bool themed: root.theme !== null
    readonly property color textPrimary:   themed ? root.theme.textPrimary   : "#d3c6aa"
    readonly property color textSecondary: themed ? root.theme.textSecondary : "#9da9a0"
    readonly property color accent:        themed ? root.theme.accent        : "#a7c080"

    readonly property string username: Lib.Configuration.githubUsername
    readonly property bool configured: username !== ""

    property real contentHeight: contentLayout.implicitHeight + (root.pad * 2)
    implicitHeight: (root.active && root.configured) ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    opacity: (root.active && root.configured) ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    visible: implicitHeight > 1
    clip: true

    Lib.CommandPoll {
        id: profilePoll
        running: root.active && root.configured
        interval: 600000
        command: root.configured
            ? ["bash", "-lc", "curl -s --max-time 5 https://api.github.com/users/" + root.username]
            : []
        parse: function(out) {
            try { return JSON.parse(out) } catch (e) { return null }
        }
    }

    Lib.CommandPoll {
        id: reposPoll
        running: root.active && root.configured
        interval: 600000
        command: root.configured
            ? ["bash", "-lc", "curl -s --max-time 5 'https://api.github.com/users/" + root.username + "/repos?per_page=100'"]
            : []
        parse: function(out) {
            try {
                var repos = JSON.parse(out)
                if (!Array.isArray(repos)) return null
                var stars = 0, forks = 0, langCounts = {}
                for (var i = 0; i < repos.length; i++) {
                    stars += repos[i].stargazers_count || 0
                    forks += repos[i].forks_count || 0
                    var lang = repos[i].language
                    if (lang) langCounts[lang] = (langCounts[lang] || 0) + 1
                }
                var topLang = ""
                var topCount = 0
                for (var l in langCounts) {
                    if (langCounts[l] > topCount) { topCount = langCounts[l]; topLang = l }
                }
                return { stars: stars, forks: forks, topLang: topLang }
            } catch (e) { return null }
        }
    }

    readonly property var profile: profilePoll.value
    readonly property var repoStats: reposPoll.value
    readonly property bool profileValid: profile && !profile.message

    ColumnLayout {
        id: contentLayout
        spacing: 8
        Layout.fillWidth: true
        z: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 28; height: 28; radius: 14
                color: root.themed ? root.theme.bgItem : "#2d353b"
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.profileValid ? (root.profile.avatar_url || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: root.profileValid ? (root.profile.name || root.username) : root.username
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "GitHub"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                }
            }
        }

        Text {
            visible: !root.profileValid
            text: root.profile ? "GitHub: user not found" : "Loading…"
            color: root.textSecondary
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 11
            opacity: 0.7
        }

        RowLayout {
            visible: root.profileValid
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Repos"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: root.profileValid ? String(root.profile.public_repos || 0) : "—"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Followers"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: root.profileValid ? String(root.profile.followers || 0) : "—"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Stars"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: root.repoStats ? String(root.repoStats.stars) : "—"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        Text {
            visible: root.repoStats && root.repoStats.topLang !== ""
            text: "Mostly " + (root.repoStats ? root.repoStats.topLang : "")
            color: root.accent
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 10
        }
    }
}
