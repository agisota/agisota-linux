import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#121216"

    property string accentColor: "#FF6B35"
    property string fgColor: "#E8EAEC"
    property string dimColor: "#A1A9B1"
    property string bgColor: "#232629"

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.3
    }

    // Logo
    Image {
        id: logo
        source: "logo.png"
        width: 180
        height: 180
        fillMode: Image.PreserveAspectFit
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: loginBox.top
        anchors.bottomMargin: 40
    }

    // Title
    Text {
        id: title
        text: "AGISOTA"
        font.family: "Victor Mono"
        font.pixelSize: 28
        font.bold: true
        color: root.accentColor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: logo.top
        anchors.bottomMargin: 16
    }

    // Login box
    Rectangle {
        id: loginBox
        anchors.centerIn: parent
        width: 380
        height: 260
        radius: 12
        color: Qt.rgba(0.14, 0.15, 0.16, 0.85)
        border.color: Qt.rgba(1, 0.42, 0.21, 0.3)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 16

            // Username
            TextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: "Имя пользователя"
                font.family: "Victor Mono"
                font.pixelSize: 14
                color: root.fgColor
                background: Rectangle {
                    radius: 6
                    color: "#1B1E21"
                    border.color: userField.activeFocus ? root.accentColor : "#3A3F44"
                    border.width: 1
                }
                leftPadding: 12
                topPadding: 10
                bottomPadding: 10
                Keys.onReturnPressed: sddm.login(userField.text, passField.text, sessionModel.lastIndex)
            }

            // Password
            TextField {
                id: passField
                Layout.fillWidth: true
                placeholderText: "Пароль"
                echoMode: TextInput.Password
                font.family: "Victor Mono"
                font.pixelSize: 14
                color: root.fgColor
                background: Rectangle {
                    radius: 6
                    color: "#1B1E21"
                    border.color: passField.activeFocus ? root.accentColor : "#3A3F44"
                    border.width: 1
                }
                leftPadding: 12
                topPadding: 10
                bottomPadding: 10
                Keys.onReturnPressed: sddm.login(userField.text, passField.text, sessionModel.lastIndex)
            }

            // Login button
            Button {
                id: loginButton
                Layout.fillWidth: true
                text: "Войти"
                font.family: "Victor Mono"
                font.pixelSize: 14
                font.bold: true
                onClicked: sddm.login(userField.text, passField.text, sessionModel.lastIndex)
                background: Rectangle {
                    radius: 6
                    color: loginButton.pressed ? "#CC5529" : root.accentColor
                }
                contentItem: Text {
                    text: loginButton.text
                    font: loginButton.font
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                height: 44
            }
        }
    }

    // Clock
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: "Victor Mono"
        font.pixelSize: 48
        font.bold: true
        color: root.fgColor
        opacity: 0.7
        text: Qt.formatDateTime(new Date(), "HH:mm")

        Timer {
            interval: 30000
            running: true
            repeat: true
            onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm")
        }
    }

    // Session selector
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 35
        anchors.right: parent.right
        anchors.rightMargin: 30
        font.family: "Victor Mono"
        font.pixelSize: 12
        color: root.dimColor
        text: "AGISOTA Linux"
    }

    Component.onCompleted: userField.forceActiveFocus()
}
