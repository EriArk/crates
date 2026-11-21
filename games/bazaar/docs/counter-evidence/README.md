# Festival Park counter services · Bazaar 0.0.11

Vale’s [rental map](office-places.png) shows an orthographic capture of the park.
Numbers follow the world coordinates of the twelve stalls. Focusing a number
shows its rental terms beside the map. Gardens, town, fountain, harbor and north
are labelled. Map tests check that every marker and label fits the visible shelf.

At a [market counter](stall-stock.png), the game frames the stall and its keeper
while the player navigates stock. Item badges use the inventory service’s icon
field. Selection shows the originating game, price and item facts. The pictured
stock is fixture data. The rental office also previews [seller models](office-frog.png).
[THREAD](thread-clothing.png) shows three costume sketches alongside the visitor; these are patterns
for future garments. Transactions are disabled in this alpha.

The [service suite](services.json) exercised the scene entry points, map geometry,
controller focus, seller previews, offline and empty inventory, stale replies and
return to exploration. OpenGL captures and the official world walkthrough passed.
Linux x86-64, Linux ARM64 and Windows exports completed using Godot 4.7.2.

The game was installed independently on Flip 2 and Odin 2 with 0.0.10 kept for
rollback. The ARM64 binary started all three worlds headlessly on both devices.
During forced headless shutdown on Odin, the engine reported outstanding fountain
audio playback. Physical controller/touch and interactive device acceptance of the
new shops are pending. The exported Linux desktop game exited normally through
its Leave Bazaar button with no audio errors. Game source revision 27be661, separate Bazaar branch.
