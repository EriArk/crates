// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Item {
    id: root
    objectName:"avatarPortrait"
    property var descriptor: ({})
    property var capture: null
    property int generation: 0
    property bool rendering: false
    property bool brickStyle:false
    property string renderedSource:""
    onVisibleChanged:renderer.active=visible&&rendering
    onCaptureChanged:if(capture&&brickStyle)lcd.loadImage(capture.url)
    onDescriptorChanged: {
        var next=descriptor&&descriptor.source!==undefined?String(descriptor.source):""
        if(next===renderedSource)return
        renderedSource=next
        generation++
        capture=null
        renderer.active=false
        rendering=descriptor && descriptor.source !== undefined
        if(rendering&&visible) renderer.active=true
    }
    // Anonymous fallback is deliberately distinct from a Trainer portrait.
    Rectangle {anchors.centerIn:parent;anchors.verticalCenterOffset:-height*0.35;width:parent.width*0.28;height:width;radius:root.brickStyle?0:width/2;color:root.brickStyle?"#34432c":"#8ca49b";visible:!root.capture}
    Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:parent.height*0.55;width:parent.width*0.6;height:parent.height*0.3;radius:root.brickStyle?0:height*0.5;color:root.brickStyle?"#34432c":"#8ca49b";visible:!root.capture}
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
    Image {anchors.fill:parent;visible:!root.brickStyle;source:root.capture?root.capture.url:"";fillMode:Image.PreserveAspectFit}
    Canvas {
        id:lcd;visible:root.brickStyle&&root.capture!==null
        anchors.centerIn:parent;width:32;height:32;scale:Math.min(parent.width,parent.height)/32;smooth:false
        onImageLoaded:requestPaint()
        onPaint:{
            if(!root.capture||!isImageLoaded(root.capture.url))return
            var c=getContext("2d");c.reset();c.drawImage(root.capture.url,0,0,32,32)
            var pixels=c.getImageData(0,0,32,32),d=pixels.data
            c.clearRect(0,0,32,32)
            for(var y=0;y<32;y++)for(var x=0;x<32;x++){
                var i=(y*32+x)*4
                if(d[i+3]<128)continue
                c.fillStyle=(d[i]*0.299+d[i+1]*0.587+d[i+2]*0.114)<155?"#34432c":"#adb991"
                c.fillRect(x,y,1,1)
            }
        }
    }
}
