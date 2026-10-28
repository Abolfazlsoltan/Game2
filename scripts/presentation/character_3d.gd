extends Node3D
## Original low-poly 3D character built from bone-attached meshes.
## Uses a real Godot Skeleton3D and procedural skeletal animation.
var role := "GUARD"
var faction_color := Color("#3d8bfd")
var skeleton: Skeleton3D
var pivot: Node3D
var bone_ids: Dictionary = {}
var materials: Dictionary = {}

func _init(role_name: String = "GUARD", faction: Color = Color("#3d8bfd")) -> void:
	role = role_name
	faction_color = faction

func _ready() -> void:
	_build_rig()

func _build_rig() -> void:
	pivot = Node3D.new()
	pivot.name = "RigPivot"
	add_child(pivot)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	pivot.add_child(skeleton)
	var data := [
		["root", -1, Vector3.ZERO],
		["pelvis", 0, Vector3(0, 0.88, 0)],
		["spine", 1, Vector3(0, 0.22, 0)],
		["head", 2, Vector3(0, 0.48, 0)],
		["upper_arm_l", 2, Vector3(-0.27, 0.25, 0)],
		["forearm_l", 4, Vector3(-0.20, -0.19, 0)],
		["upper_arm_r", 2, Vector3(0.27, 0.25, 0)],
		["forearm_r", 6, Vector3(0.20, -0.19, 0)],
		["thigh_l", 1, Vector3(-0.13, -0.08, 0)],
		["shin_l", 8, Vector3(0, -0.34, 0)],
		["foot_l", 9, Vector3(0, -0.31, 0.035)],
		["thigh_r", 1, Vector3(0.13, -0.08, 0)],
		["shin_r", 11, Vector3(0, -0.34, 0)],
		["foot_r", 12, Vector3(0, -0.31, 0.035)]
	]
	for item in data:
		var idx := skeleton.get_bone_count()
		skeleton.add_bone(str(item[0]))
		skeleton.set_bone_parent(idx, int(item[1]))
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, item[2]))
		bone_ids[str(item[0])] = idx
	_attach_geometry()
	pivot.scale = Vector3.ONE * (1.32 if role == "GIANT" else 1.0)

func _mat(key: String, color: Color, metal: float = 0.0) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.7
	materials[key] = m
	return m

func _attach(bone: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.name = "Bone_" + bone
	a.bone_name = bone
	skeleton.add_child(a)
	return a

func _mesh(parent: Node3D, mesh_data: PrimitiveMesh, color: Color, pos: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh_data
	m.position = pos
	m.rotation = rot
	m.material_override = _mat(key, color, 0.12 if key.contains("metal") else 0.0)
	parent.add_child(m)
	return m

func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, key: String) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(parent, b, color, pos, key)

func _sphere(parent: Node3D, radius: float, color: Color, pos: Vector3, key: String) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 8
	_mesh(parent, s, color, pos, key)

func _capsule(parent: Node3D, radius: float, length: float, color: Color, pos: Vector3, key: String) -> void:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length + radius * 2.0
	c.radial_segments = 8
	c.rings = 4
	_mesh(parent, c, color, pos, key)

func _attach_geometry() -> void:
	var spine := _attach("spine")
	var pelvis := _attach("pelvis")
	var head := _attach("head")
	var upper_l := _attach("upper_arm_l")
	var fore_l := _attach("forearm_l")
	var upper_r := _attach("upper_arm_r")
	var fore_r := _attach("forearm_r")
	var thigh_l := _attach("thigh_l")
	var shin_l := _attach("shin_l")
	var foot_l := _attach("foot_l")
	var thigh_r := _attach("thigh_r")
	var shin_r := _attach("shin_r")
	var foot_r := _attach("foot_r")
	var skin := Color("#e4c9ae")
	var dark := Color("#252e40")
	var metal := Color("#aeb9c8")
	var leather := Color("#6f4b31")
	var accent := Color("#e2b34a")
	var torso_color := faction_color
	var arm_color := Color("#74539a") if role == "MYSTIC" else metal
	var leg_color := Color("#62544d") if role == "GIANT" else dark
	_box(spine, Vector3(0.43, 0.52, 0.29), torso_color, Vector3(0, -0.04, 0), "torso_" + role)
	_box(spine, Vector3(0.47, 0.13, 0.32), _role_accent(), Vector3(0, 0.17, 0), "shoulder_" + role)
	_box(pelvis, Vector3(0.34, 0.15, 0.30), leather, Vector3(0, -0.03, 0), "belt")
	_sphere(head, 0.15 if role == "GIANT" else 0.13, skin, Vector3.ZERO, "skin")
	_sphere(head, 0.027, Color("#1b2029"), Vector3(0.07, 0.015, 0.118), "eye")
	_box(upper_l, Vector3(0.15, 0.30, 0.16), arm_color, Vector3(0, -0.12, 0), "upperarm_l")
	_capsule(fore_l, 0.06, 0.22, arm_color, Vector3(0, -0.15, 0), "forearm_l")
	_box(upper_r, Vector3(0.15, 0.30, 0.16), arm_color, Vector3(0, -0.12, 0), "upperarm_r")
	_capsule(fore_r, 0.06, 0.22, arm_color, Vector3(0, -0.15, 0), "forearm_r")
	_sphere(fore_l, 0.065, skin, Vector3(0, -0.28, 0.015), "hand_l")
	_sphere(fore_r, 0.065, skin, Vector3(0, -0.28, 0.015), "hand_r")
	for limb in [thigh_l, thigh_r]:
		_capsule(limb, 0.08 if role != "GIANT" else 0.10, 0.29, leg_color, Vector3(0, -0.16, 0), "thigh")
	for limb in [shin_l, shin_r]:
		_capsule(limb, 0.065, 0.25, dark, Vector3(0, -0.15, 0), "shin")
	for foot in [foot_l, foot_r]:
		_box(foot, Vector3(0.23, 0.11, 0.30), dark, Vector3(0.035, -0.02, 0.08), "boot")
	_sphere(spine, 0.055, accent, Vector3(0, 0.02, 0.16), "crest")
	_apply_role_details(head, spine)

func _role_accent() -> Color:
	match role:
		"WORKER": return Color("#b98a49")
		"SCOUT": return Color("#4e7959")
		"MYSTIC": return Color("#74539a")
		"GIANT": return Color("#8b7769")
		_: return Color("#e2b34a")

func _apply_role_details(head: Node3D, spine: Node3D) -> void:
	match role:
		"WORKER":
			var helmet := CylinderMesh.new()
			helmet.top_radius = 0.13
			helmet.bottom_radius = 0.15
			helmet.height = 0.08
			_mesh(head, helmet, Color("#87919c"), Vector3(0, 0.12, 0), "worker_helmet")
			_box(head, Vector3(0.18, 0.035, 0.045), Color("#e2b34a"), Vector3(0, 0.10, 0.13), "lamp")
		"SCOUT":
			_box(head, Vector3(0.28, 0.07, 0.24), Color("#6f4b31"), Vector3(0, 0.095, 0), "scout_hood")
		"MYSTIC":
			var hood := PrismMesh.new()
			hood.size = Vector3(0.30, 0.30, 0.30)
			_mesh(head, hood, Color("#74539a"), Vector3(0, 0.17, 0), "mystic_hood", Vector3(0, 0, PI))
			_sphere(head, 0.045, Color("#a9d2ff"), Vector3(0, 0.07, 0.14), "glowing_gem")
		"GIANT":
			_box(head, Vector3(0.34, 0.12, 0.27), Color("#776b63"), Vector3(0, 0.10, 0), "giant_helm")
		_:
			_box(head, Vector3(0.28, 0.07, 0.25), Color("#aeb9c8"), Vector3(0, 0.10, 0), "guard_helm")

func _set_pose(bone: String, angle: float) -> void:
	if not bone_ids.has(bone):
		return
	skeleton.set_bone_pose_rotation(int(bone_ids[bone]), Quaternion(Vector3(0, 0, 1), angle))

func animate_pose(walking: bool, running: bool, phase: float, jump: float, hit_react: float, stunned: bool, action: String, progress: float) -> void:
	if skeleton == null:
		return
	var stride := 0.72 if running else 0.43
	var gait := sin(phase) if walking else 0.0
	_set_pose("thigh_l", gait * stride)
	_set_pose("thigh_r", -gait * stride)
	_set_pose("shin_l", maxf(0.0, -gait) * 0.62 if walking else 0.0)
	_set_pose("shin_r", maxf(0.0, gait) * 0.62 if walking else 0.0)
	_set_pose("upper_arm_l", -gait * 0.52)
	_set_pose("upper_arm_r", gait * 0.52)
	_set_pose("forearm_l", 0.12)
	_set_pose("forearm_r", 0.12)
	_set_pose("spine", -0.20 if hit_react > 0.0 else (0.12 if stunned else 0.0))
	if jump > 0.0:
		_set_pose("thigh_l", -0.48)
		_set_pose("thigh_r", 0.40)
		_set_pose("shin_l", 0.60)
		_set_pose("shin_r", 0.48)
		pivot.position.y = 0.22
	else:
		pivot.position.y = 0.015 * absf(gait)
	if action == "work" and role == "WORKER":
		var lift := sin(progress * PI)
		_set_pose("upper_arm_l", -0.48 - lift * 0.60)
		_set_pose("upper_arm_r", -0.28 - lift * 0.65)
		_set_pose("forearm_l", -0.30)
		_set_pose("forearm_r", -0.40)
	elif action == "focus" and role == "MYSTIC":
		_set_pose("upper_arm_r", -0.90 - sin(progress * PI) * 0.20)
		_set_pose("forearm_r", -0.40)
	pivot.rotation.z = 0.22 if hit_react > 0.0 else (0.08 if stunned else 0.0)
