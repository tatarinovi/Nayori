pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    default property alias pageData: column.data

    function reveal(item) {
        const flick = contentItem
        if (!flick || !item)
            return
        const point = item.mapToItem(flick.contentItem, 0, 0)
        if (point.y < flick.contentY)
            flick.contentY = point.y
        else if (point.y + item.height > flick.contentY + flick.height)
            flick.contentY = point.y + item.height - flick.height
    }

    Column {
        id: column
        width: Math.min(960, Math.max(0, root.availableWidth - 12))
        spacing: 16
    }
}
