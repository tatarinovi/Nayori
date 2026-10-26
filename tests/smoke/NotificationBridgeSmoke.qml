import QtQuick
import Quickshell
import Quickshell.Io
import "services/island"
ShellRoot {
    NotificationModel { id: notificationModel }
    Notifications { id: bridge; model: notificationModel; enabled: Quickshell.env("NAYORI_ISLAND_NOTIFICATION_TEST") === "1" }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({available:bridge.available,diagnostic:bridge.diagnostic,running:bridge.host.running,pid:String(bridge.host.processId),command:bridge.host.command,records:notificationModel.records,current:notificationModel.current,unread:notificationModel.unreadCount}) }
        function view(open: bool): void { notificationModel.view("test",open,open) }
        function remove(id: int): void { notificationModel.remove(id) }
        function markRead(id: int): void { notificationModel.markRead(id) }
    }
}
