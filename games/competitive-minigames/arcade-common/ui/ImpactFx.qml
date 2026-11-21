// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Canvas {
    id:fx
    property bool brick: false
    property var sparks: []
    property var rings: []
    property double lastTime: 0
    // Positions are normalized to the board, so effects follow every screen size.
    function burst(x,y,colour,strength) {
        var list=sparks.slice(-100), halo=rings.slice(-8)
        for(var n=0;n<strength;n++) {
            var angle=n*2.39996, speed=0.05+(n%7)*0.015
            list.push({x:x,y:y,vx:Math.cos(angle)*speed,vy:Math.sin(angle)*speed,age:0,life:0.45+(n%5)*0.09,c:colour})
        }
        halo.push({x:x,y:y,age:0,c:colour});sparks=list;rings=halo;lastTime=Date.now();requestPaint()
    }
    Timer { interval:33;running:fx.sparks.length>0||fx.rings.length>0;repeat:true
        onTriggered:{
            var now=Date.now(),dt=Math.min(0.05,(now-fx.lastTime)/1000);fx.lastTime=now
            fx.sparks=fx.sparks.filter(function(p){p.age+=dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.vy+=0.12*dt;return p.age<p.life})
            fx.rings=fx.rings.filter(function(p){p.age+=dt;return p.age<0.5});fx.requestPaint()
        }
    }
    onPaint:{
        var c=getContext("2d");c.reset()
        for(var i=0;i<rings.length;i++){var r=rings[i];c.globalAlpha=(1-r.age/0.5)*0.7;c.strokeStyle=r.c;c.lineWidth=3;c.beginPath();if(brick){var radius=5+r.age*Math.min(width,height)*0.22;c.rect(r.x*width-radius,r.y*height-radius,radius*2,radius*2)}else c.arc(r.x*width,r.y*height,5+r.age*Math.min(width,height)*0.22,0,Math.PI*2);c.stroke()}
        for(i=0;i<sparks.length;i++){var p=sparks[i];c.globalAlpha=1-p.age/p.life;c.fillStyle=p.c;c.beginPath();var size=Math.max(2,Math.min(width,height)*0.008)*(1-p.age/p.life*0.6);if(brick)c.rect(p.x*width-size,p.y*height-size,size*2,size*2);else c.arc(p.x*width,p.y*height,size,0,Math.PI*2);c.fill()}
    }
}
