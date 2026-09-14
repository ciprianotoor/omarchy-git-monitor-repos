import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.ciprianotoor.omarchy-git-monitor-repos"

  property var configuredRepos: []
  property var notifications: []
  property string state: "Not configured"
  property string error: ""
  property bool popupOpen: false
  readonly property int unreadCount: notifications.length
  readonly property int attentionCount: notifications.filter(function(item) {
    return item.attention
  }).length
  readonly property color stateColor: error !== "" ? Color.urgent
    : attentionCount > 0 ? "#f2cc60"
    : unreadCount > 0 ? "#ef4444"
    : "#60a5fa"
  readonly property string configPath: Quickshell.env("HOME")
    + "/.config/omarchy/omarchy-git-monitor-repos.json"

  function parseConfig(raw) {
    try {
      var config = JSON.parse(String(raw || ""))
      var repos = config && Array.isArray(config.repos) ? config.repos : []
      root.configuredRepos = repos.map(function(repo) {
        return String(repo).trim()
      }).filter(function(repo) {
        return /^[^/]+\/[^/]+$/.test(repo)
      })
      root.state = root.configuredRepos.length > 0
        ? "Ready (" + root.configuredRepos.length + " repositories)"
        : "Add repositories to the config file"
      root.error = ""
      if (root.configuredRepos.length > 0) root.refresh()
    } catch (exception) {
      root.configuredRepos = []
      root.state = "Invalid configuration"
      root.error = "Invalid JSON in " + root.configPath
    }
  }

  function parseNotifications(raw) {
    try {
      var all = JSON.parse(String(raw || ""))
      var allowed = {}
      for (var i = 0; i < root.configuredRepos.length; i++)
        allowed[root.configuredRepos[i].toLowerCase()] = true

      var next = []
      for (var j = 0; j < all.length; j++) {
        var item = all[j]
        var repo = item && item.repository ? String(item.repository.full_name || "") : ""
        if (item && item.unread && allowed[repo.toLowerCase()]) {
          var reason = String(item.reason || "")
          next.push({
            repo: repo,
            title: String(item.subject && item.subject.title || "GitHub activity"),
            type: String(item.subject && item.subject.type || "Notification"),
            url: root.webUrl(item.subject && item.subject.url),
            reason: reason,
            attention: ["assign", "mention", "review_requested", "team_mention"]
              .indexOf(reason) >= 0,
            updatedAt: String(item.updated_at || "")
          })
        }
      }
      root.notifications = next
      root.state = next.length > 0
        ? next.length + " unread GitHub notification" + (next.length === 1 ? "" : "s")
        : "No unread activity"
      root.error = ""
    } catch (exception) {
      root.notifications = []
      root.state = "GitHub returned invalid data"
      root.error = "Could not read GitHub notifications"
    }
  }

  function webUrl(apiUrl) {
    var value = String(apiUrl || "")
    if (value === "") return ""
    value = value.replace("https://api.github.com/repos/", "https://github.com/")
    return value.replace("/pulls/", "/pull/")
  }

  function refresh() {
    if (root.configuredRepos.length === 0 || notificationProcess.running) return
    root.error = ""
    notificationProcess.command = [
      "gh", "api", "notifications?all=false&per_page=50"
    ]
    notificationProcess.running = true
  }

  function openNotification(item) {
    if (!item || !item.url) return
    Quickshell.execDetached(["xdg-open", item.url])
  }

  function openConfig() {
    Quickshell.execDetached(["xdg-open", root.configPath])
  }

  function tooltip() {
    if (root.error !== "") return root.error
    if (root.configuredRepos.length === 0)
      return "GitHub monitor: configure " + root.configPath
    return root.state
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseConfig(text())
    onFileChanged: reload()
    onLoadFailed: {
      root.configuredRepos = []
      root.notifications = []
      root.state = "Configuration file not found"
      root.error = "Copy config.example.json to " + root.configPath
    }
  }

  Process {
    id: notificationProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseNotifications(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message) root.error = message
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.error === "")
        root.error = "GitHub request failed; run gh auth login"
    }
  }

  Timer {
    interval: Math.max(30, parseInt(root.setting("refreshIntervalSec", 300), 10) || 300) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: barSize

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊢" + (root.unreadCount > 0 ? " " + root.unreadCount : "")
    foreground: root.stateColor
    useActiveColor: false
    tooltipText: root.tooltip()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(430))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: "GitHub repositories"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        text: root.error !== "" ? root.error : root.state
        color: root.error !== "" ? Color.urgent : Qt.darker(root.bar.foreground, 1.35)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Text {
        text: "Blue: no changes  •  Red: new activity  •  Yellow: needs attention"
        color: Qt.darker(root.bar.foreground, 1.25)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      PanelSeparator { foreground: root.bar.foreground }

      Text {
        visible: root.notifications.length === 0
        text: root.configuredRepos.length === 0
          ? "Create the configuration file to start monitoring."
          : "No unread activity in the selected repositories."
        color: Qt.darker(root.bar.foreground, 1.25)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Repeater {
        model: root.notifications

        Button {
          required property var modelData
          width: content.width
          text: modelData.type + " · " + modelData.repo + "\n"
            + modelData.title
            + (modelData.attention ? "\nNeeds your attention" : "")
          foreground: modelData.attention ? "#f2cc60" : root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: root.openNotification(modelData)
        }
      }

      Row {
        spacing: Style.space(6)

        Button {
          text: "Refresh"
          foreground: root.bar.foreground
          onClicked: root.refresh()
        }

        Button {
          text: "Edit config"
          foreground: root.bar.foreground
          tooltipText: "Open " + root.configPath + " in your default editor"
          onClicked: root.openConfig()
        }
      }
    }
  }
}
