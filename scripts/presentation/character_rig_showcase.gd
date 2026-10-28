extends Node3D
## Standalone preview scene for the new real 3D skeletal characters.
const CharacterRig = preload("res://scripts/presentation/character_3d.gd")
const ROLES := ["WORKER", "GUARD", "SCOUT", "MYSTIC", "GIANT", "GUARD"]
var characters: Array[Node3D] = []
var elapsed := 0.0

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101a2a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bdcbe0")
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.6
	camera.position = Vector3(0, 2.8, 11.5)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -25, 0)
	key_light.light_energy = 1.6
	add_child(key_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-4, 5, 4)
	fill.light_energy = 0.7
	fill.omni_range = 18.0
	add_child(fill)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(11.0, 0.12, 2.0)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -0.08, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#273448")
	floor_mat.roughness = 0.9
	floor.material_override = floor_mat
	add_child(floor)

	for i in ROLES.size():
		var faction := Color("#3d8bfd") if i < 3 else Color("#d64545")
		var character = CharacterRig.new(str(ROLES[i]), faction)
		character.name = "Rig_" + str(i)
		character.position = Vector3((float(i) - 2.5) * 1.55, 0, 0)
		character.scale = Vector3.ONE * (0.76 if ROLES[i] != "GIANT" else 0.68)
		character.rotation.y = PI * 0.5
		add_child(character)
		characters.append(character)

		var label := Label3D.new()
		label.text = str(ROLES[i])
		label.font_size = 26
		label.pixel_size = 0.006
		label.modulate = Color("#f0f4fa")
		label.position = character.position + Vector3(0, 2.25, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

func _process(delta: float) -> void:
	elapsed += delta
	for i in characters.size():
		var phase := elapsed * (3.0 + float(i % 3) * 0.6) + float(i) * 0.9
		var action := "work" if i == 0 else ("focus" if i == 3 else "")
		var jump := maxf(0.0, sin(elapsed * 1.7 + float(i)) - 0.86) * 1.5
		characters[i].animate_pose(i != 4, i % 2 == 0, phase, jump, 0.0, false, action, fposmod(elapsed * 0.7 + float(i) * 0.13, 1.0))
