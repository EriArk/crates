# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Each row is one conversation. Repeat visits alternate between the two.
const LINES := {
	"Pip": [["Smell that? Pears. The good ones smell sweet before you even pick them up.", "I had six this morning. Now I have five pears and a very good breakfast."], ["Would you call a tomato a fruit?", "Good. Would you call six of them lunch? I'm packing mine."]],
	"Moru": [["This bolt of blue cloth used to be twice as long.", "No, I didn't sell it. I measured myself for a scarf."], ["Put your cheek against this wool. Go on.", "Soft, right? That's my professional opinion. I have two very qualified cheeks."]],
	"Nim": [["I've tucked a seed into every pocket of my apron.", "Come spring, please remind me to empty my pockets before laundry day."], ["There's a bee asleep in my lavender.", "I've put the price tag on the other pot. She's paid up till noon."]],
	"Bram": [["The wind keeps lifting that corner of my awning.", "I've tied it down with a very scholarly book about knots."], ["I leave this aisle wide enough for two carts.", "Or one friend telling a story with both hands."]],
	"Tavi": [["I count the pigeons while the kettle boils.", "Seven today. Unless that plump one is two pigeons in a coat."], ["The fountain makes a fine clock.", "When the spray reaches my chair, it's time to move my chair."]],
	"Oru": [["One of my jars hums when the wind blows.", "I tuned the other two. Now my pickles sing in harmony."], ["See that shadow under the table?", "Perfect for cooling a pie. Terrible for hiding one."]],
	"Moss": [["Listen to the kettle. That little sigh is the sweet spot.", "A second whistle and the leaves get bossy."], ["I put out a tiny cup for the steam.", "Silly, I know. But look how nicely it curls around the rim."]],
	"Wisp": [["Hold still. There's a thread on your shoulder.", "There. No charge. It was one of mine anyway."], ["Every coat I make has a secret pocket.", "What for? That's up to whoever finds it."]],
	"Rook": [["This compass points to the nearest spoon.", "Utterly useless at sea. Quite wonderful at breakfast."], ["Look through this little piece of blue glass.", "Now even the dust looks expensive."]],
	"Vale": [["The little squares on the rental map are the stalls. My desk is the coffee ring.", "I keep meaning to draw a proper desk. The coffee keeps beating me to it."], ["I like a tidy ledger. One line for each stall.", "The pigeon on the windowsill has requested a line for crumbs."]],
	"Kip": [["I drew these stripes on the sign myself.", "Ran out of brush halfway through. My tail did a respectable job."], ["If you hear something tapping under the counter, that's me.", "My feet know the tune before the rest of me does."]],
	"Sora": [["From the roof you can see the whole row of awnings.", "I tried counting them once. Then somebody opened a bag of millet."], ["I polished my bell so well I could see my beak.", "We bowed at exactly the same time. Very polite fellow."]],
	"Nell": [["I take the long way past the stalls on purpose.", "There's always one more good smell just around the corner."], ["Want a quiet spot? Try the garden benches.", "Take the sunny end. The other end squeaks."]],
	"Clover": [["My left ear says the kettle's on. My right ear says the fountain.", "It's nice having the whole morning in stereo."], ["I was in a hurry until I saw that cloud.", "It looked like a carrot. You would've stopped too."]],
	"Finn": [["I came to the park for one lap.", "That was three laps ago. I keep remembering another stall to look at."], ["Hear those little clicks on the paving?", "New shoes. I'm getting to know them."]],
	"Lumi": [["Everyone thinks I like the cold. I like warm paving stones.", "Especially one for each foot."], ["I knitted mittens for the festival.", "Then I remembered I was the one selling hot buns."]],
	"Ada": [["The tailor puts a light in the window before anyone else is up.", "I like walking past when the street is still blue."], ["I used to know every paving stone in town.", "They replaced one yesterday. We're getting acquainted."]],
	"Elm": [["I bought a bell so I'd hear my keys when they fell.", "Now I can hear exactly where I've forgotten them."], ["When the wind turns, the whole street smells like Moss's tea.", "That's usually when my walk takes a little detour."]],
	"Ripple": [["Hold on. The fountain nearly had the rhythm right.", "One splash, two splashes... there! I can sing over that."], ["That bench stays cool all afternoon.", "I've tested it very thoroughly. For science."]],
	"Stall keeper": [["I turned the display toward the aisle this morning.", "Now I get to see who stops and smiles at it."], ["Small things go up front, tall things at the back.", "That's the whole secret. Took me all morning."]]
}
static func pages(speaker: String, visit: int) -> Array:
	var choices: Array = LINES.get(speaker, LINES["Stall keeper"])
	return choices[posmod(visit, choices.size())]
