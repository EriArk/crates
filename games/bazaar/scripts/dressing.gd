# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Small authored set dressing, pooled into the world's static mesh batches.
var world: Node3D
var meshes: Dictionary = {}
var materials: Dictionary = {}

func setup(owner_world: Node3D) -> void:
	world=owner_world
	var box := BoxMesh.new();box.size=Vector3.ONE;meshes["box"]=box
	var cylinder := CylinderMesh.new();cylinder.top_radius=0.5;cylinder.bottom_radius=0.5;cylinder.height=1;cylinder.radial_segments=12;meshes["round"]=cylinder
	var sphere := SphereMesh.new();sphere.radius=0.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6;meshes["orb"]=sphere
	var ring := TorusMesh.new();ring.inner_radius=0.42;ring.outer_radius=0.5;ring.rings=24;ring.ring_segments=6;meshes["ring"]=ring

func piece(kind: String, at: Vector3, size: Vector3, color: String, yaw := 0.0) -> Node3D:
	var root := Node3D.new();add_child(root);root.position=at;root.rotation.y=yaw
	var mesh := MeshInstance3D.new();mesh.mesh=meshes[kind];mesh.scale=size
	if not materials.has(color):materials[color]=world.material(color)
	mesh.material_override=materials[color];root.add_child(mesh);world.prop_roots.append(root)
	return root

func jar(at: Vector3, color: String, size := 1.0) -> void:
	piece("round",at+Vector3(0,0.14*size,0),Vector3(0.24,0.28,0.24)*size,color)
	piece("round",at+Vector3(0,0.29*size,0),Vector3(0.27,0.045,0.27)*size,"c2a775")
	piece("orb",at+Vector3(0,0.33*size,0),Vector3.ONE*0.06*size,"856b48")

func cup(at: Vector3) -> void:
	piece("round",at+Vector3(0,0.025,0),Vector3(0.25,0.035,0.25),"d9d6ba")
	piece("round",at+Vector3(0,0.10,0),Vector3(0.15,0.15,0.15),"d8cba8")
	piece("round",at+Vector3(0,0.178,0),Vector3(0.12,0.006,0.12),"6d4c32")

func crate(at: Vector3) -> void:
	piece("box",at+Vector3(0,0.22,0),Vector3(0.65,0.44,0.5),"916c47")
	for y in [0.07,0.36]:piece("box",at+Vector3(0,y,0.265),Vector3(0.7,0.065,0.04),"c29a63")
	for x in [-0.27,0.27]:piece("box",at+Vector3(x,0.22,0.27),Vector3(0.055,0.44,0.05),"c29a63")

func park() -> void:
	# A real entrance marker with open space below it, outside the stall rows.
	for side in [-1,1]:
		world.block(Vector3(side*4.8,2,23),Vector3(0.24,4,0.24),"775c42")
		piece("box",Vector3(side*4.8,0.2,23),Vector3(0.55,0.4,0.55),"c5b998")
		world.lantern(Vector3(side*3.9,3.5,23),"edc68a")
		for z in [-15.0,15.0]:
			world.model("hedge",Vector3(side*17,0,z),Vector3(2.8,1.3,1.6))
		# Gravel edge bands keep the promenade readable without blocking movement.
		piece("box",Vector3(side*6.85,0.032,0),Vector3(0.30,0.025,44),"bcb49a")
	piece("box",Vector3(0,4.05,23),Vector3(10.2,0.22,0.3),"886b48")
	piece("box",Vector3(0,3.95,23.18),Vector3(3.9,0.65,0.12),"305950")
	world.text3d("FESTIVAL PARK",Vector3(0,3.95,23.26),0.009)
	# Small mosaics break up the large paved surface around the fountain.
	piece("ring",Vector3(0,0.04,0),Vector3(8.4,0.06,8.4),"c5aa76")
	for i in 8:
		var a := i*TAU/8
		piece("box",Vector3(sin(a)*4.5,0.036,cos(a)*4.5),Vector3(0.26,0.025,0.55),"b6c7b1",-a)
	# Work/storage belongs behind the counter, never in the walking lane.
	# Display cloth is decoration, not advertised inventory.
	for slot in range(1,13):
		var layout: Dictionary=world.stall_layout(slot)
		var at: Vector3=layout.position
		crate(Vector3(layout.side*7.1,0,at.z+0.65))
		for n in 3:piece("box",Vector3(at.x,0.82+n*0.07,at.z),Vector3(0.38,0.06,0.65),["e1c397","779f91","b87565"][n])
	# Rest pockets off the cross promenade, not in front of sellers.
	for side in [-1,1]:
		for z in [-2.0,2.0]:
			var at := Vector3(side*11,0,z)
			table(at)
			for x in [-1.2,1.2]:world.model("stall-stool",at+Vector3(x,0,0),Vector3.ONE*1.6)

func storefront(at: Vector3, yaw: float, index: int) -> void:
	var palette := ["537e70","ad766c","687c92","b29350"]
	var color: String=palette[index]
	# An awning and hanging lamps frame the same physical entry used by interaction.
	for side in [-1,1]:
		var p := at+Vector3(side*2.3,1.9,3.1).rotated(Vector3.UP,yaw)
		world.lantern(p,"ecc98c")
		piece("box",at+Vector3(side*2.3,2.36,2.95).rotated(Vector3.UP,yaw),Vector3(0.08,0.08,0.65),"665a44",yaw)
	for i in 9:
		var p := at+Vector3((i-4)*0.42,2.13,2.95).rotated(Vector3.UP,yaw)
		var canopy := piece("box",p,Vector3(0.42,0.09,1.1),color if i%2==0 else "ded0ac",yaw)
		canopy.rotation.x=-0.12*cos(yaw);canopy.rotation.z=0.12*sin(yaw)
		piece("box",at+Vector3((i-4)*0.42,1.96,3.48).rotated(Vector3.UP,yaw),Vector3(0.42,0.26,0.04),color if i%2==0 else "ded0ac",yaw)

func table(at: Vector3) -> void:
	piece("round",at+Vector3(0,0.66,0),Vector3(1.2,0.12,1.2),"bc9263")
	piece("round",at+Vector3(0,0.32,0),Vector3(0.15,0.64,0.15),"795d42")
	piece("round",at+Vector3(0,0.05,0),Vector3(0.55,0.1,0.55),"795d42")
	world.collider(self,at+Vector3(0,0.35,0),Vector3(1.1,0.7,1.1))
	for side in [-1,1]:world.model("stall-stool",at+Vector3(side*1.05,0,0),Vector3.ONE*1.1)
	cup(at+Vector3(0.27,0.72,0.2));cup(at+Vector3(-0.25,0.72,-0.2));jar(at+Vector3(0,0.72,0),"709184",0.8)

func room(center: Vector3, index: int) -> void:
	var color: String=["527e71","a16d67","566f87","977a42"][index]
	# Wood floor, rug and beams give each preview a room scale and identity.
	for i in 20:piece("box",center+Vector3(-4.75+i*0.5,0.031,0),Vector3(0.487,0.025,10),"8e7356" if i%3==0 else "a48762")
	piece("box",center+Vector3(0,0.052,0.6),Vector3(3.7,0.014,3.8),"c9b188")
	piece("box",center+Vector3(0,0.061,0.6),Vector3(3.45,0.012,3.55),color)
	for z in [-3.5,0,3.5]:piece("box",center+Vector3(0,3.7,z),Vector3(10,0.20,0.20),"795f44")
	for x in [-4.8,4.8]:piece("box",center+Vector3(x,0.17,0),Vector3(0.15,0.28,10),"896c4c")
	# A tangible exit door, aligned with the local exit trigger.
	piece("box",center+Vector3(0,1,4.83),Vector3(1.5,2,0.08),"5c5848")
	for x in [-0.85,0.85]:piece("box",center+Vector3(x,1.1,4.72),Vector3(0.12,2.2,0.12),"b79b71")
	piece("box",center+Vector3(0,2.2,4.72),Vector3(1.82,0.12,0.12),"b79b71")
	piece("orb",center+Vector3(-0.50,0.9,4.72),Vector3.ONE*0.10,"d7b36e")
	# Lower worktop suits the shared chibi-sized visitor.
	piece("box",center+Vector3(0,0.82,-2.5),Vector3(6.2,0.12,1.05),"c4a477")
	if index==0:
		for x in [-2.5,2.5]:table(center+Vector3(x,0,0))
		for i in 5:jar(center+Vector3(-1.5+i*0.72,0.9,-2.5),"71927a",1.0)
	elif index==1:
		for x in [-3.8,-2.8]:piece("box",center+Vector3(x,1.0,-0.4),Vector3(0.08,2,0.08),"9b7b55")
		piece("box",center+Vector3(-3.3,2.0,-0.4),Vector3(1.25,0.08,0.08),"9b7b55")
		for i in 4:piece("box",center+Vector3(-3.7+i*0.27,1.35,-0.4),Vector3(0.22,1.1,0.12),["a76e64","72958a","d1b37a","788b9f"][i])
		for i in 6:
			var bolt := piece("round",center+Vector3(2.8,0.18+(i/3)*0.34,-0.6+(i%3)*0.38),Vector3(0.3,1.2,0.3),["d6bd91","b68179","719489"][i%3]);bolt.rotation.z=PI/2
		for i in 5:piece("box",center+Vector3(-1.1+i*0.5,0.94,-2.5),Vector3(0.42,0.12,0.65),["d6bd91","b68179","719489"][i%3])
	elif index==3:
		# Park plan, lease ledger and twelve hooks distinguish the rental office.
		piece("box",center+Vector3(-3.2,1.8,-4.65),Vector3(2.2,1.65,0.09),"d5c393")
		for side in [-1,1]:
			for n in 6:piece("box",center+Vector3(-3.2+side*0.55,1.25+n*0.22,-4.56),Vector3(0.45,0.13,0.04),"607e68")
		for n in 4:piece("box",center+Vector3(-1+n*0.5,0.94,-2.5),Vector3(0.4,0.12,0.55),"ddc995")
		world.text3d("FESTIVAL PARK",center+Vector3(-3.2,2.82,-4.55),0.004)
	else:
		for side in [-1,1]:
			var p := center+Vector3(side*2.65,0,-0.1)
			piece("round",p+Vector3(0,0.38,0),Vector3(0.9,0.76,0.9),"9c8f73")
			piece("orb",p+Vector3(0,1.08,0),Vector3.ONE*0.62,"7db1b3")
			var ring := piece("ring",p+Vector3(0,1.08,0),Vector3.ONE*0.9,"c5a467");ring.rotation.x=0.65
			world.collider(self,p+Vector3(0,0.4,0),Vector3(0.85,0.8,0.85))
		for i in 6:piece("box",center+Vector3(-1.7+i*0.55,1.04,-2.5),Vector3(0.16,0.3+(i%2)*0.12,0.3),["789b8f","b28472","c4ac7e"][i%3])
		crate(center+Vector3(3.5,0,-3.4))
	for side in [-1,1]:
		for i in 3:jar(center+Vector3(side*3.8+(i-1)*0.35,1.67,-3.8),color,0.8)
