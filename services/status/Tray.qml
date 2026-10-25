import QtQuick
import Quickshell.Services.SystemTray

// Хост трея. Импорт Quickshell.Services.SystemTray регистрирует
// org.kde.StatusNotifierWatcher, если имя ещё свободно.
// Второй хост этот файл не поднимает: синглтон в процессе один.
QtObject {
    readonly property bool available: true
    readonly property var items: SystemTray.items
}
