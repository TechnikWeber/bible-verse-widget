import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Settings")
        icon: "preferences-desktop"
        source: "ConfigAppearance.qml"
    }
}
