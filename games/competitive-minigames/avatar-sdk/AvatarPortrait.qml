// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Item {
    id: root
    property var descriptor: ({})
    property var capture: null
    property int generation: 0
    property bool rendering: false
    onDescriptorChanged: {
        generation++
        capture=null
        renderer.active=false
        rendering=descriptor && descriptor.source !== undefined
        if(rendering) renderer.active=true
    }
    // Anonymous fallback is deliberately distinct from a Trainer portrait.
    Rectangle {anchors.centerIn:parent;anchors.verticalCenterOffset:-height*0.35;width:parent.width*0.28;height:width;radius:width/2;color:"#8ca49b";visible:!root.capture}
    Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:parent.height*0.55;width:parent.width*0.6;height:parent.height*0.3;radius:height*0.5;color:"#8ca49b";visible:!root.capture}
    Loader {
        id:renderer
        objectName:"portraitRenderer"
        active:false
        width:256;height:256;scale:root.width/256;transformOrigin:Item.TopLeft
        source:"AvatarPortraitScene.qml"
        onLoaded: {item.modelSource=root.descriptor.source;item.ticket=root.generation}
    }
    Connections {
        target:renderer.item
        function onCaptured(result,ticket) {
            if(ticket!==root.generation)return
            root.capture=result
            root.rendering=false
            Qt.callLater(function(){if(ticket===root.generation)renderer.active=false})
        }
    }
    Image {anchors.fill:parent;source:root.capture?root.capture.url:"";fillMode:Image.PreserveAspectFit}
}
