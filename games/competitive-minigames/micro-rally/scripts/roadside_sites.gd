# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Art=preload("art.gd")
const Prop=preload("roadside_prop.gd")

static func populate(road: Node3D, theme: String) -> void:
	var stations: Array = {
		"valley":[0.012,0.175,0.305,0.460,0.568,0.742,0.900],
		"quarry":[0.022,0.156,0.292,0.455,0.529,0.710,0.885],
		"timber":[0.035,0.168,0.283,0.437,0.535,0.699,0.842],
		"circuit":[0.003,0.095,0.208,0.355,0.487,0.641,0.782,0.936]
	}[theme]
	for site in stations.size():
		var at:=int(float(stations[site])*road.COUNT)
		var side:=1 if site%2==0 else -1
		if road._bridge_segment(at): continue
		var edge: float=road.half_width(at)
		# Loose equipment sits between the track and its guardrail; fixed
		# installations are well outside the shoulder.
		for i in 3:
			var item:=Prop.new()
			item.slot=road.props.size()
			var index: int=(at+road.steps_ahead(at,3.0*i))%road.COUNT if i else at
			road.add_child(item)
			item.transform=road.road_pose(index,(road.half_width(index)+0.28)*side,0)
			var kinds:=["cone","crate","barrel"]
			item.build(kinds[(site+i)%3])
			road.props.append(item)
		var pose: Transform3D=road.road_pose(at,(edge+6.1)*side,0)
		var nearest: int=road.nearest(pose.origin)
		if road.on_road(pose.origin,nearest,3.0): continue
		var site_root:=Node3D.new()
		road.add_child(site_root)
		site_root.position=pose.origin
		site_root.rotation.y=pose.basis.get_euler().y
		if theme=="quarry" and site%2==0:
			ore_cart(site_root)
		elif theme=="timber" and site%2==0:
			for n in 6:
				var log_mesh:=CylinderMesh.new()
				log_mesh.height=4.1; log_mesh.top_radius=0.29; log_mesh.bottom_radius=0.32
				log_mesh.radial_segments=8; log_mesh.rings=0
				var log_piece:=MeshInstance3D.new()
				log_piece.mesh=log_mesh; log_piece.material_override=Art.material(Color("a4794f"))
				log_piece.rotation.x=PI/2
				log_piece.position=Vector3((n%3-1)*0.57+(0.16 if n>=3 else 0.0),0.32+0.51*(n/3),0)
				site_root.add_child(log_piece)
			Art.collider(site_root,Vector3(1.75,1.20,4.1),Vector3.UP*0.60)
		else:
			var cloth:=Color("c36937") if theme=="quarry" else Color("2c7975") if site%2==0 else Color("ad5448")
			for x in [-1.45,1.45]:
				for z in [-1.15,1.15]:
					Art.box(site_root,Vector3(0.12,2.6,0.12),Vector3(x,1.30,z),Color("766b54"))
					Art.collider(site_root,Vector3(0.12,2.6,0.12),Vector3(x,1.30,z))
			for x in [-1,1]:
				var eave=Art.box(site_root,Vector3(1.84,0.16,2.85),Vector3(0.86*x,2.86,0),cloth)
				eave.rotation.z=-x*0.29
			Art.box(site_root,Vector3(2.4,0.85,0.95),Vector3.UP*0.425,Color("b59068"))
			Art.collider(site_root,Vector3(2.4,0.85,0.95),Vector3.UP*0.425)
		for node in site_root.get_children():
			if node is GeometryInstance3D: node.visibility_range_end=140

static func ore_cart(site: Node3D) -> void:
	var iron:=Color("4e5353")
	var ochre:=Color("c88c43")
	for x in [-1.02,1.02]:
		for z in [-1.25,1.25]:
			var wheel:=CylinderMesh.new()
			wheel.radial_segments=12; wheel.rings=0; wheel.height=0.32
			wheel.top_radius=0.46; wheel.bottom_radius=0.46
			var rim:=MeshInstance3D.new()
			rim.mesh=wheel; rim.material_override=Art.material(iron)
			rim.position=Vector3(x,0.46,z); rim.rotation.z=PI/2
			site.add_child(rim)
		Art.box(site,Vector3(0.17,1.2,3.9),Vector3(x,1.29,0),ochre).rotation.z=-x*0.16
	for z in [-1.86,1.86]:
		Art.box(site,Vector3(2.08,1.18,0.15),Vector3(0,1.29,z),ochre)
	Art.box(site,Vector3(2.05,0.23,3.88),Vector3.UP*0.76,iron)
	for n in 6:
		var rock:=SphereMesh.new()
		rock.radial_segments=5; rock.rings=2; rock.radius=0.58; rock.height=0.86
		var ore:=MeshInstance3D.new()
		ore.mesh=rock; ore.material_override=Art.material(Color("a3664d") if n%2 else Color("936653"))
		ore.position=Vector3((n%2-0.5)*0.8,1.76,(n/2-1)*1.08)
		ore.rotation.y=n*0.77; site.add_child(ore)
	Art.collider(site,Vector3(2.22,1.85,3.94),Vector3.UP*1.02)
