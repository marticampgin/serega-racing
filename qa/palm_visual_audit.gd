extends SceneTree

const OUTPUT_PATH := "res://qa/artifacts/palm_variants.png"
const PALMS := [
	"res://scenes/manual_scenery/presets/vegetation/palm_small.tscn",
	"res://scenes/manual_scenery/presets/vegetation/palm_tall.tscn",
	"res://scenes/manual_scenery/presets/vegetation/palm_wide.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("palm visual audit requires a rendering display")
		quit(2)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	_add_ground(stage)
	for index in range(PALMS.size()):
		var palm := (load(PALMS[index]) as PackedScene).instantiate() as Node3D
		palm.position = Vector3(float(index - 1) * 9.0, 0, 0)
		stage.add_child(palm)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -28, 0)
	light.light_energy = 1.35
	stage.add_child(light)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b51d82")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8c2ff")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	stage.add_child(environment_node)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 8.5, 27)
	camera.look_at_from_position(camera.position, Vector3(0, 5.0, 0), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	for frame in range(5):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := image.save_png(output)
	print("PALM VISUAL QA: %s" % ["PASS" if error == OK else "FAIL"])
	if error == OK:
		print("PALM VISUAL: ", output)
	quit(0 if error == OK else 1)


func _add_ground(parent: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(40, 0.35, 20)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8b58d")
	material.roughness = 0.9
	mesh.material = material
	ground.mesh = mesh
	ground.position.y = -0.18
	parent.add_child(ground)
