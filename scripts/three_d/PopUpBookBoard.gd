extends Node3D
## A self-contained interactive art study. Its sample field never changes a match.

const PaperCraftScript = preload("res://scripts/three_d/PaperCraft.gd")
const MAIN_SCENE := "res://scenes/main_3d.tscn"
const PAPER := Color("f6ebd1")
const INK := Color("354c50")
const TEAL := Color("568c87")
const CORAL := Color("c16c57")
const GOLD := Color("cba052")
const RANK_Z := [-3.78, -1.35, 1.35, 3.78]
const LANE_X := [-5.65, -2.83, 0.0, 2.83, 5.65]
const CARD_SCRIPTS := {
	"thor": "res://scripts/cards/Gods/Thor.gd",
	"mummu": "res://scripts/cards/Gods/Mummu.gd",
	"warrior": "res://scripts/cards/Creatures/Berserker.gd",
	"byggvir": "res://scripts/cards/Creatures/Byggvir.gd",
	"mage": "res://scripts/cards/Creatures/HariiShaman.gd",
	"lion": "res://scripts/cards/Creatures/WingedLion.gd",
	"wolf": "res://scripts/cards/Creatures/RabidWolf.gd",
	"priest": "res://scripts/cards/Creatures/GududPriest.gd",
	"mead": "res://scripts/cards/Powers/BerserkerMead.gd",
	"bloodlust": "res://scripts/cards/Powers/NorseBloodlust.gd",
	"valkyrie": "res://scripts/cards/Powers/CallOfTheValkyrie.gd",
	"wisdom": "res://scripts/cards/Powers/AncientWisdom.gd",
	"dreams": "res://scripts/cards/Powers/AltarOfDreams.gd",
	"laws": "res://scripts/cards/Powers/LawsOfCivilization.gd",
}

var _paper := PaperCraftScript.new()
var _book: Node3D
var _left_page: Node3D
var _right_page: Node3D
var _camera: Camera3D
var _hud: Control
var _hand: HBoxContainer
var _detail_title: Label
var _detail_meta: Label
var _detail_body: RichTextLabel
var _status: Label
var _fold_button: Button
var _cards: Dictionary = {}
var _slots: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _hovered: int = -1
var _selected_piece: int = -1
var _selected_hand: String = ""
var _hand_kinds: Array[String] = ["warrior", "byggvir", "mage", "wolf"]
var _folded: bool = false
var _folding: bool = false
var _fold_tween: Tween
var _orbit: Vector2 = Vector2(0.0, 0.78)
var _zoom: float = 17.6
var _time: float = 0.0
var _floating: Array[Node3D] = []
var _scenery_folds: Array[Node3D] = []
var _inspect_targets: Array[Dictionary] = []
var _selection_ring: MeshInstance3D
var _pending_slot: int = -1
var _last_pointer: Vector2 = Vector2.INF

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_card_data()
	_build_environment()
	_build_tabletop()
	_build_book()
	_build_landscape()
	_build_field()
	_build_god(_left_page, Vector3(-8.65, 0.16, 2.55), "thor", TEAL)
	_build_god(_right_page, Vector3(8.65, 0.16, -2.55), "mummu", CORAL)
	_build_side_piles()
	_build_camera()
	_build_hud()
	_reset_field()
	get_viewport().size_changed.connect(_fit_camera)
	_left_page.rotation.z = -0.22
	_right_page.rotation.z = 0.22
	for piece in _pieces:
		var figure: Node3D = piece["root"]
		figure.rotation.x = -PI * 0.47
	_animate_book(false)
	print("[PopUpBook] Interactive art study ready: 5 lanes, 20 field slots, 2 gods, 6 powers.")

func _load_card_data() -> void:
	for kind in CARD_SCRIPTS:
		var card_script := load(str(CARD_SCRIPTS[kind])) as Script
		if card_script != null:
			_cards[kind] = card_script.new()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("cbbf9f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d4")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-53, -31, 0)
	key.light_color = Color("fff0d5")
	key.light_energy = 1.45
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 65.0
	key.shadow_blur = 2.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 135, 0)
	fill.light_color = Color("dae6de")
	fill.light_energy = 0.38
	add_child(fill)

func _build_tabletop() -> void:
	_paper.box(self, Vector3(0, -0.91, 0), Vector3(200, 0.35, 200), Color("bbac8c"))
	# Oversized, quiet cloth mat behind the book.
	var mat := _paper.box(self, Vector3(0, -0.71, 0), Vector3(27, 0.045, 19), Color("c8bd9e"))
	mat.rotation.y = -0.025
	for i in range(31):
		_paper.box(self, Vector3(-13.0 + i * 0.87, -0.68, 0), Vector3(0.012, 0.008, 18.6), Color("bfb498"))
	# A pencil and two offcuts make the scale read as a handmade tabletop object.
	var pencil := _paper.box(self, Vector3(12.65, -0.51, 3.9), Vector3(0.15, 0.15, 4.8), CORAL)
	pencil.rotation.y = -0.32
	_paper.box(self, Vector3(11.91, -0.51, 6.12), Vector3(0.17, 0.17, 0.35), GOLD)
	for i in range(2):
		var scrap := _paper.box(self, Vector3(-12.1 - i * 0.45, -0.62 + i * 0.025, 4.9 + i), Vector3(1.1, 0.02, 1.65), PAPER)
		scrap.rotation.y = -0.2 + i * 0.5

func _build_book() -> void:
	_book = Node3D.new()
	_book.name = "ClothboundBook"
	add_child(_book)
	_book.position.y = -0.19
	_left_page = Node3D.new()
	_left_page.name = "LeftLeaf"
	_book.add_child(_left_page)
	_right_page = Node3D.new()
	_right_page.name = "RightLeaf"
	_book.add_child(_right_page)
	for page in [_left_page, _right_page]:
		var side := -1.0 if page == _left_page else 1.0
		_paper.box(page, Vector3(side * 5.73, -0.29, 0), Vector3(11.57, 0.32, 14.55), Color("335958"))
		_paper.box(page, Vector3(side * 5.72, -0.11, 0), Vector3(11.37, 0.06, 14.32), GOLD)
		for layer in range(7):
			_paper.box(page, Vector3(side * 5.67, -0.06 + layer * 0.026, 0), Vector3(11.21, 0.025, 14.12 - layer * 0.022), Color("d4c5a7").lerp(PAPER, float(layer) / 6.0))
		for z in [-6.81, 6.81]:
			_paper.box(page, Vector3(side * 5.72, 0.125, z), Vector3(10.65, 0.013, 0.023), GOLD)
		_paper.box(page, Vector3(side * 10.99, 0.125, 0), Vector3(0.023, 0.013, 13.63), GOLD)
		for z in [-6.70, 6.70]:
			for x in [side * 0.50, side * 10.85]:
				var ornament := _paper.star(page, Vector3(x, 0.14, z), 0.12, GOLD)
				ornament.rotation.x = -PI * 0.5
		var page_number := _paper.label(page, "18" if side < 0 else "19", Vector3(side * 10.40, 0.15, 6.39), 27, Color("938161"))
		page_number.rotation.x = -PI * 0.5
	# Thin printed gutter and a real ribbon bookmark spilling out below the book.
	_paper.box(_book, Vector3(0, 0.11, 0), Vector3(0.11, 0.035, 14.0), Color("bbab8b"))
	var bookmark := _paper.polygon(_book, PackedVector2Array([Vector2(-0.22, 0), Vector2(0.22, 0), Vector2(0.22, -2.2), Vector2(0, -1.98), Vector2(-0.22, -2.2)]), CORAL)
	bookmark.rotation.x = -PI * 0.5
	bookmark.position = Vector3(1.1, -0.12, 6.6)
	var title := _paper.label(_left_page, "A TALE OF OTHER GODS", Vector3(-4.7, 0.16, -6.38), 38, INK)
	title.rotation.x = -PI * 0.5
	var subtitle := _paper.label(_right_page, "where little legends come to life", Vector3(5.0, 0.16, 6.36), 27, INK)
	subtitle.rotation.x = -PI * 0.5

func _page_for_x(x: float) -> Node3D:
	return _left_page if x < 0.0 else _right_page

func _build_landscape() -> void:
	# Low paper islands stay outside the play lanes and leave the middle legible.
	for side in [-1.0, 1.0]:
		var page := _page_for_x(side)
		var island := _paper.polygon(page, PackedVector2Array([Vector2(-2.0, -5.6), Vector2(-2.3, -3.0), Vector2(-1.9, 0), Vector2(-2.4, 3.2), Vector2(-1.7, 5.8), Vector2(1.0, 5.9), Vector2(1.45, 3.5), Vector2(1.1, 0), Vector2(1.4, -3.8), Vector2(0.8, -5.7)]), Color("d8dfbd") if side < 0 else Color("e8d4a4"))
		island.rotation.x = -PI * 0.5
		island.position = Vector3(side * 9.1, 0.145, 0)
	# Layered mountains, with separate snow caps and visible folds.
	for i in range(8):
		var x := -9.7 + i * 2.78
		var height := 1.45 + sin(i * 2.4) * 0.43
		var page := _page_for_x(x)
		var mountain := _paper.cutout(page, PackedVector2Array([Vector2(-1.35, 0), Vector2(-0.20, height), Vector2(0.16, height * 0.88), Vector2(1.30, 0)]), Color("a6b4b1") if i < 4 else Color("c7b590"), Vector3(x, 0.15, -5.97))
		_scenery_folds.append(mountain)
		_paper.polygon(mountain, PackedVector2Array([Vector2(-0.20, height), Vector2(0.14, height * 0.87), Vector2(0.63, height * 0.48), Vector2(0.13, height * 0.62), Vector2(-0.10, height * 0.51), Vector2(-0.57, height * 0.62)]), PAPER).position.z = 0.07
		var fold := _paper.polygon(mountain, PackedVector2Array([Vector2(-0.20, height), Vector2(0.10, 0), Vector2(1.30, 0)]), Color("8c9d9c") if i < 4 else Color("bca782"))
		fold.position.z = 0.04
	for i in range(14):
		var side := -1.0 if i < 7 else 1.0
		var z := -4.8 + (i % 7) * 1.57
		var x := side * (10.15 + sin(i * 3.1) * 0.23)
		var tree := _paper.tree(_page_for_x(x), Vector3(x, 0.16, z), 1.25 + 0.32 * sin(i * 1.7), Color("6e9690") if side < 0 else Color("bd985b"), side < 0)
		tree.rotation.y = sin(i) * 0.14
		_scenery_folds.append(tree)
	for i in range(13):
		var x := -8.8 + i * 1.46
		_scenery_folds.append(_paper.tree(_page_for_x(x), Vector3(x, 0.16, -5.34), 0.65 + (i % 3) * 0.19, Color("789c88"), i < 7))
	# Paper sun, moon, and hanging clouds crown the backdrop.
	var sun_stand := Node3D.new()
	_right_page.add_child(sun_stand)
	sun_stand.position = Vector3(8.6, 0.15, -6.0)
	_scenery_folds.append(sun_stand)
	_paper.strip(sun_stand, Vector3.ZERO, Vector3(0, 3.0, -0.03), 0.023, Color("a99a7c"))
	_paper.disc(sun_stand, Vector3(0, 2.95, 0), 0.57, GOLD, 24)
	for i in range(12):
		var angle := TAU * i / 12.0
		_paper.strip(sun_stand, Vector3(cos(angle) * 0.72, 2.95 + sin(angle) * 0.72, 0), Vector3(cos(angle) * 0.88, 2.95 + sin(angle) * 0.88, 0), 0.035, GOLD)
	for i in range(4):
		var x := -8.0 + i * 5.1
		var cloud_stand := Node3D.new()
		_page_for_x(x).add_child(cloud_stand)
		cloud_stand.position = Vector3(x, 0.15, -5.96)
		_scenery_folds.append(cloud_stand)
		var cloud := _paper.cloud(cloud_stand, Vector3(0, 2.5 + (i % 2) * 0.5, 0), 0.71 + (i % 2) * 0.10)
		cloud.set_meta("rest_y", cloud.position.y)
		_floating.append(cloud)
		_paper.strip(cloud_stand, Vector3(0, 0.05, -0.06), Vector3(0, cloud.position.y + 0.13, -0.06), 0.018, Color("a99a7c"))
	for i in range(7):
		var x := -6.7 + i * 2.1
		_paper.star(_page_for_x(x), Vector3(x, 2.35 + sin(i * 2.0) * 0.28, -6.02), 0.12 + (i % 2) * 0.05, GOLD)
	# Printed dashed path across the gutter, like a storybook journey.
	for i in range(44):
		var x := -7.25 + i * 0.34
		_paper.box(_page_for_x(x), Vector3(x, 0.165, sin(x * 0.9) * 0.09), Vector3(0.15, 0.012, 0.035), GOLD)

func _build_field() -> void:
	for rank in range(4):
		var color := CORAL if rank < 2 else TEAL
		for lane in range(5):
			var x: float = LANE_X[lane]
			var z: float = RANK_Z[rank]
			var page := _page_for_x(x)
			var root := Node3D.new()
			root.name = "Slot_%d_%d" % [rank, lane]
			page.add_child(root)
			root.position = Vector3(x, 0.18, z)
			_paper.box(root, Vector3(0, -0.005, 0), Vector3(2.37, 0.035, 1.98), Color("d8ccb0"))
			var tile := _paper.box(root, Vector3(0, 0.023, 0), Vector3(2.30, 0.035, 1.91), PAPER.lightened(0.025))
			# A fine, double printed frame instead of the original stone slabs.
			for edge_z in [-0.87, 0.87]:
				_paper.box(root, Vector3(0, 0.045, edge_z), Vector3(2.13, 0.008, 0.018), color.lightened(0.18))
			for edge_x in [-1.065, 1.065]:
				_paper.box(root, Vector3(edge_x, 0.045, 0), Vector3(0.018, 0.008, 1.74), color.lightened(0.18))
			var mark := _paper.disc(root, Vector3(0, 0.048, 0), 0.23, color.lightened(0.63), 16)
			mark.rotation.x = -PI * 0.5
			var numeral := _paper.label(root, ["I", "II", "III", "IV", "V"][lane], Vector3(0, 0.065, 0.57), 22, color)
			numeral.rotation.x = -PI * 0.5
			_slots.append({"root": root, "tile": tile, "rank": rank, "lane": lane, "piece": -1})
	for rank in range(4):
		var text := "RESERVE" if rank in [0, 3] else "FRONTLINE"
		var caption := _paper.label(_left_page, text, Vector3(-7.25, 0.17, RANK_Z[rank]), 21, CORAL if rank < 2 else TEAL)
		caption.rotation.x = -PI * 0.5
		caption.rotation.z = PI * 0.5
	_selection_ring = _paper.box(_book, Vector3(0, 0.20, 0), Vector3(2.48, 0.025, 2.10), GOLD)
	_selection_ring.visible = false

func _build_god(page: Node3D, at: Vector3, kind: String, color: Color) -> void:
	var shrine := Node3D.new()
	page.add_child(shrine)
	shrine.position = at
	_scenery_folds.append(shrine)
	_inspect_targets.append({"root": shrine, "kind": kind, "height": 1.3, "radius": 65.0})
	_paper.box(shrine, Vector3(0, 0.04, 0), Vector3(1.85, 0.10, 2.1), PAPER)
	var arch := PackedVector2Array([Vector2(-0.94, 0), Vector2(-0.94, 2.05), Vector2(-0.64, 2.47), Vector2(0, 2.72), Vector2(0.64, 2.47), Vector2(0.94, 2.05), Vector2(0.94, 0), Vector2(0.70, 0), Vector2(0.70, 1.92), Vector2(0.48, 2.20), Vector2(0, 2.39), Vector2(-0.48, 2.20), Vector2(-0.70, 1.92), Vector2(-0.70, 0)])
	_paper.cutout(shrine, arch, color, Vector3(0, 0.06, -0.46))
	var figure := _paper.figure(shrine, kind, color)
	figure.position = Vector3(0, 0.10, 0.05)
	figure.scale = Vector3.ONE * 1.12
	_paper.label(shrine, "THOR" if kind == "thor" else "MUMMU", Vector3(0, 0.24, 0.90), 34, INK)
	var medallion := _paper.disc(shrine, Vector3(-0.70, 2.48, -0.35), 0.27, GOLD)
	_paper.label(medallion, "20", Vector3(0, 0, 0.045), 27, PAPER)
	var mana := _paper.disc(shrine, Vector3(0.74, 0.78, 0.45), 0.29, color)
	_paper.label(mana, "8", Vector3(0, 0, 0.04), 32, PAPER)
	# Three power bookmarks spring out of each god's side of the page.
	for i in range(3):
		var power := Node3D.new()
		page.add_child(power)
		power.position = Vector3(at.x, 0.20, at.z + (-1.0 if kind == "thor" else 1.0) * (1.55 + i * 0.76))
		_scenery_folds.append(power)
		var power_kind: String = ["valkyrie", "mead", "bloodlust"][i] if kind == "thor" else ["wisdom", "dreams", "laws"][i]
		_inspect_targets.append({"root": power, "kind": power_kind, "height": 0.25, "radius": 23.0})
		var ribbon := _paper.cutout(power, PackedVector2Array([Vector2(-0.72, 0), Vector2(-0.72, 0.49), Vector2(0.72, 0.49), Vector2(0.72, 0), Vector2(0.46, 0.12), Vector2(0.20, 0)]), color.lightened(0.15))
		ribbon.rotation.x = -0.32
		_paper.star(power, Vector3(-0.48, 0.28, 0.10), 0.09, GOLD)
		_paper.label(power, ["VALKYRIE", "MEAD", "BLOODLUST"][i] if kind == "thor" else ["WISDOM", "DREAMS", "LAWS"][i], Vector3(0.09, 0.27, 0.11), 17, PAPER)

func _build_side_piles() -> void:
	for side in [-1.0, 1.0]:
		var page := _page_for_x(side)
		var z := -3.6 if side < 0 else 3.6
		for i in range(6):
			_paper.box(page, Vector3(side * 8.60 + sin(i) * 0.025, 0.20 + i * 0.06, z), Vector3(1.50, 0.045, 1.95), PAPER if i % 2 == 0 else Color("b7a98b"))
		var cover := _paper.box(page, Vector3(side * 8.6, 0.58, z), Vector3(1.48, 0.045, 1.92), TEAL if side < 0 else CORAL)
		var emblem := _paper.star(cover, Vector3(0, 0.04, 0), 0.41, GOLD)
		emblem.rotation.x = -PI * 0.5
		var caption := _paper.label(page, "DECK · 35", Vector3(side * 8.60, 0.17, z + 1.35), 22, INK)
		caption.rotation.x = -PI * 0.5
		var grave_z := z + (-2.05 if side < 0 else 2.05)
		var tombstone := _paper.cutout(page, PackedVector2Array([Vector2(-0.5, 0), Vector2(-0.5, 0.68), Vector2(-0.36, 0.88), Vector2(0, 1.02), Vector2(0.36, 0.88), Vector2(0.50, 0.68), Vector2(0.50, 0)]), Color("b4b8a5"), Vector3(side * 8.6, 0.17, grave_z))
		_scenery_folds.append(tombstone)
		_paper.label(tombstone, "GRAVE", Vector3(0, 0.48, 0.08), 20, INK)
		var abyss := _paper.disc(page, Vector3(side * 7.05, 0.17, grave_z), 0.48, INK)
		abyss.rotation.x = -PI * 0.5
		var abyss_center := _paper.disc(abyss, Vector3(0, 0, 0.03), 0.30, Color("768c87"))
		_paper.star(abyss_center, Vector3(0, 0, 0.04), 0.16, GOLD)
		var abyss_label := _paper.label(page, "ABYSS", Vector3(side * 7.05, 0.17, grave_z + 0.66), 18, INK)
		abyss_label.rotation.x = -PI * 0.5

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "BookCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 150.0
	add_child(_camera)
	_camera.make_current()
	_fit_camera()

func _fit_camera() -> void:
	if _camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
	_camera.size = _zoom * maxf(1.0, 1.65 / aspect)
	_last_pointer = Vector2.INF
	var distance := 32.0
	_camera.position = Vector3(sin(_orbit.x) * cos(_orbit.y), sin(_orbit.y), cos(_orbit.x) * cos(_orbit.y)) * distance
	_camera.look_at(Vector3(0, 0.2, 0.25))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StorybookInterface"
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_ui_label(titles, "O T H E R   G O D S", 14, INK)
	_ui_label(titles, "The little book of legends", 34, INK, true)
	_ui_label(titles, "AN INTERACTIVE POP-UP ART STUDY", 12, Color("726e58"))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	header.add_child(actions)
	_fold_button = _button(actions, "Fold book", _toggle_fold)
	_button(actions, "Reset field", _reset_field)
	_button(actions, "Back to menu", _back_to_menu)
	var middle := HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(spacer)
	var sidebar := VBoxContainer.new()
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sidebar.custom_minimum_size.x = 247
	middle.add_child(sidebar)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(247, 230)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.97, 0.93, 0.83, 0.94), GOLD, 18))
	sidebar.add_child(panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 9)
	panel.add_child(details)
	_ui_label(details, "F R O M   T H E   P A G E", 11, Color("8c7959"))
	_detail_title = _ui_label(details, "Once upon a battlefield…", 23, INK, true)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_meta = _ui_label(details, "NORSE  /  ANCIENT", 11, TEAL)
	_detail_body = RichTextLabel.new()
	_detail_body.bbcode_enabled = true
	_detail_body.fit_content = true
	_detail_body.scroll_active = false
	_detail_body.custom_minimum_size = Vector2(208, 100)
	_detail_body.add_theme_font_size_override("normal_font_size", 14)
	_detail_body.add_theme_color_override("default_color", INK)
	details.add_child(_detail_body)
	_detail_body.text = "Hover a paper figure to meet it.\n\nChoose a card below, then an empty teal slot to make it pop up."
	_ui_label(sidebar, "Right-drag to turn the book\nScroll to look closer · Esc to deselect", 12, INK)
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 18)
	column.add_child(footer)
	var footer_notes := VBoxContainer.new()
	footer_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_notes.custom_minimum_size.x = 230
	footer_notes.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(footer_notes)
	_ui_label(footer_notes, "A field folded from imagination.", 17, INK, true)
	_status = _ui_label(footer_notes, "Select a card to add to the story.", 13, INK)
	_status.custom_minimum_size.x = 230
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hand = HBoxContainer.new()
	_hand.add_theme_constant_override("separation", 10)
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(_hand)
	var note := _ui_label(footer, "ART STUDY\nSample field · no match rules", 12, INK)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_END
	_rebuild_hand()

func _ui_label(parent: Node, text: String, font_size: int, color: Color, serif: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if serif:
		label.add_theme_font_override("font", _paper.book_font)
	parent.add_child(label)
	return label

func _panel_style(color: Color, border: Color, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.shadow_color = Color(0.18, 0.19, 0.13, 0.13)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 4)
	return style

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_stylebox_override("normal", _panel_style(PAPER, Color("ac9a76")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("fff7e4"), INK))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("ded7bc"), INK))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_font_size_override("font_size", 14)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _rebuild_hand() -> void:
	for child in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for kind in _hand_kinds:
		var card: Resource = _cards.get(kind)
		if card == null:
			continue
		var button := _button(_hand, "", _select_hand.bind(kind))
		button.custom_minimum_size = Vector2(142, 122)
		button.add_theme_stylebox_override("normal", _panel_style(Color("fff4d9"), TEAL if _selected_hand == kind else GOLD, 9))
		var contents := VBoxContainer.new()
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 10
		contents.offset_right = -10
		contents.offset_top = 8
		contents.offset_bottom = -8
		_ui_label(contents, "LV %d   ·   NORSE" % card.get("level"), 10, TEAL)
		var name_label := _ui_label(contents, str(card.get("card_name")), 17, INK, true)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ornament := _ui_label(contents, "✦   ─────   ✦", 15, GOLD)
		ornament.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_ui_label(contents, "%d STR     %d RES" % [card.get("strength"), card.get("resilience")], 11, INK)
		button.mouse_entered.connect(_show_card.bind(kind))

func _reset_field() -> void:
	if _folding or _folded:
		return
	_selected_hand = ""
	_selected_piece = -1
	_hovered = -1
	for slot in _slots:
		slot["piece"] = -1
	for piece in _pieces:
		var root: Node3D = piece["root"]
		root.get_parent().remove_child(root)
		root.queue_free()
	_pieces.clear()
	_hand_kinds.assign(["warrior", "byggvir", "mage", "wolf"])
	for entry in [["lion", 1, 0], ["priest", 0, 1], ["lion", 1, 3], ["mage", 0, 4], ["warrior", 2, 1], ["byggvir", 3, 2], ["wolf", 2, 3], ["mage", 3, 0]]:
		_spawn_piece(str(entry[0]), int(entry[1]) * 5 + int(entry[2]), false)
	if _hand != null:
		_rebuild_hand()
	if _status != null:
		_status.text = "Select a card to add to the story."
	if _selection_ring != null:
		_selection_ring.visible = false

func _spawn_piece(kind: String, slot_index: int, animate: bool = true) -> void:
	var slot := _slots[slot_index]
	var root: Node3D = slot["root"]
	var color := CORAL if int(slot["rank"]) < 2 else TEAL
	if kind == "lion":
		color = GOLD
	if kind == "wolf":
		color = Color("8b9e9c")
	var figure: Node3D = _paper.figure(root, "mage" if kind == "priest" else kind, color)
	figure.position = Vector3(0, 0.075, -0.12)
	figure.scale = Vector3.ONE * 0.80
	var card: Resource = _cards.get(kind)
	if card != null:
		var name_label: Label3D = _paper.label(figure, str(card.get("card_name")), Vector3(0, 0.055, 0.83), 24, INK)
		name_label.rotation.x = -0.60
		var stats: Label3D = _paper.label(figure, "%d / %d" % [card.get("strength"), card.get("resilience")], Vector3(0, 0.24, 0.60), 24, color.darkened(0.28))
		stats.rotation.x = -0.20
	var piece_index := _pieces.size()
	slot["piece"] = piece_index
	_pieces.append({"root": figure, "kind": kind, "slot": slot_index})
	if animate:
		figure.rotation.x = -PI * 0.49
		var tween := create_tween()
		tween.tween_property(figure, "rotation:x", 0.0, 0.60).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _select_hand(kind: String) -> void:
	if _folded or _folding:
		return
	_selected_piece = -1
	_selected_hand = "" if _selected_hand == kind else kind
	_status.text = "Choose an empty teal slot." if _selected_hand != "" else "Select a card to add to the story."
	_show_card(kind)
	_rebuild_hand()

func _show_card(kind: String) -> void:
	var card: Resource = _cards.get(kind)
	if card == null:
		return
	_detail_title.text = str(card.get("card_name"))
	_detail_meta.text = "%s   ·   LEVEL %d" % [str(card.get("culture")).to_upper(), int(card.get("level"))]
	if bool(card.get("is_god")):
		_detail_meta.text = "%s   ·   GOD" % str(card.get("culture")).to_upper()
	elif bool(card.get("is_power")):
		_detail_meta.text = "%s   ·   POWER" % str(card.get("culture")).to_upper()
	_detail_body.text = str(card.get("ability_text"))

func _process(delta: float) -> void:
	_time += delta
	for i in range(_floating.size()):
		var item := _floating[i]
		if item.has_meta("rest_y"):
			item.position.y = float(item.get_meta("rest_y")) + sin(_time * 0.75 + i) * 0.035
	if not _folded and not _folding:
		_update_hover()

func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	# Projection is inexpensive, but no need to do it for a stationary pointer.
	if mouse == _last_pointer:
		return
	_last_pointer = mouse
	_pending_slot = -1
	var next_hover := -1
	if get_viewport().gui_get_hovered_control() != null:
		_clear_hover()
		return
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	var intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if intersection != null:
		var point: Vector3 = intersection
		for i in range(_slots.size()):
			var root: Node3D = _slots[i]["root"]
			var local := root.to_local(point)
			if absf(local.x) < 1.22 and absf(local.z) < 1.05:
				_pending_slot = i
				break
	# Tall silhouettes can be picked above their ground slot as well.
	var nearest := 80.0
	for i in range(_pieces.size()):
		var figure: Node3D = _pieces[i]["root"]
		var center := figure.global_position + Vector3(0, 0.72, 0)
		var screen := _camera.unproject_position(center)
		var distance := mouse.distance_to(screen)
		if distance < nearest and distance < 52.0:
			nearest = distance
			next_hover = i
	if next_hover < 0 and _pending_slot >= 0:
		next_hover = int(_slots[_pending_slot]["piece"])
	if next_hover >= 0:
		_pending_slot = int(_pieces[next_hover]["slot"])
	if next_hover < 0:
		var inspect_kind := ""
		var inspect_distance := INF
		for target in _inspect_targets:
			var root: Node3D = target["root"]
			var center := root.global_position + Vector3.UP * float(target["height"])
			var distance := mouse.distance_to(_camera.unproject_position(center))
			if distance < float(target["radius"]) and distance < inspect_distance:
				inspect_distance = distance
				inspect_kind = str(target["kind"])
		if inspect_kind != "":
			_show_card(inspect_kind)
	if _hovered != next_hover:
		_clear_hover()
		_hovered = next_hover
		if _hovered >= 0:
			var root: Node3D = _pieces[_hovered]["root"]
			root.position.y = 0.15
			_show_card(str(_pieces[_hovered]["kind"]))
	_selection_ring.visible = _pending_slot >= 0 and (_selected_hand != "" or _selected_piece >= 0 or _hovered >= 0)
	if _selection_ring.visible:
		var slot_root: Node3D = _slots[_pending_slot]["root"]
		_selection_ring.global_position = slot_root.global_position + Vector3(0, -0.02, 0)

func _clear_hover() -> void:
	if _hovered >= 0 and _hovered < _pieces.size():
		var root: Node3D = _pieces[_hovered]["root"]
		root.position.y = 0.075
	_hovered = -1
	if _selection_ring != null:
		_selection_ring.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_selected_hand = ""
		_selected_piece = -1
		_status.text = "Select a card to add to the story."
		_rebuild_hand()
		_selection_ring.visible = false
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_orbit.x = clampf(_orbit.x - event.relative.x * 0.003, -0.38, 0.38)
		_orbit.y = clampf(_orbit.y + event.relative.y * 0.003, 0.58, 1.15)
		_fit_camera()
		_last_pointer = Vector2.INF
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + (-0.65 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.65), 13.5, 22.5)
			_fit_camera()
			_last_pointer = Vector2.INF
		if event.button_index == MOUSE_BUTTON_LEFT and not _folded and not _folding:
			_activate_slot()

func _activate_slot() -> void:
	if _pending_slot < 0:
		return
	var slot := _slots[_pending_slot]
	if _selected_hand != "" and int(slot["rank"]) >= 2 and int(slot["piece"]) < 0:
		_spawn_piece(_selected_hand, _pending_slot)
		_status.text = "%s springs from the page." % str(_cards[_selected_hand].get("card_name"))
		_hand_kinds.erase(_selected_hand)
		_selected_hand = ""
		_rebuild_hand()
	elif _selected_piece >= 0 and int(slot["piece"]) < 0 and int(slot["rank"]) >= 2:
		var piece := _pieces[_selected_piece]
		var old_slot := int(piece["slot"])
		var root: Node3D = piece["root"]
		root.reparent(slot["root"], true)
		_slots[old_slot]["piece"] = -1
		slot["piece"] = _selected_piece
		piece["slot"] = _pending_slot
		var tween := create_tween()
		tween.tween_property(root, "position", Vector3(0, 0.075, -0.12), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_selected_piece = -1
		_status.text = "A little legend finds a new place."
	elif int(slot["piece"]) >= 0:
		var piece_index := int(slot["piece"])
		_show_card(str(_pieces[piece_index]["kind"]))
		if int(slot["rank"]) >= 2:
			_selected_piece = piece_index
			_selected_hand = ""
			_status.text = "Choose an empty teal slot to move this figure."
			_rebuild_hand()
	_last_pointer = Vector2.INF

func _toggle_fold() -> void:
	if not _folding:
		_animate_book(not _folded)

func _animate_book(close: bool) -> void:
	_folding = true
	_clear_hover()
	_selected_piece = -1
	_selected_hand = ""
	if _fold_tween != null and _fold_tween.is_running():
		_fold_tween.kill()
	# The page-mounted terrain, slots, gods and figures all fold together.
	_fold_tween = create_tween().set_parallel(true)
	_fold_tween.tween_property(_left_page, "rotation:z", -1.32 if close else 0.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fold_tween.tween_property(_right_page, "rotation:z", 1.32 if close else 0.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for scenery in _scenery_folds:
		_fold_tween.tween_property(scenery, "rotation:x", -PI * 0.47 if close else 0.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for piece in _pieces:
		var root: Node3D = piece["root"]
		_fold_tween.tween_property(root, "rotation:x", -PI * 0.47 if close else 0.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fold_tween.chain().tween_callback(func() -> void:
		_folded = close
		_folding = false
		_fold_button.text = "Open book" if close else "Fold book"
		_status.text = "The story is tucked away." if close else "Select a card to add to the story."
		_last_pointer = Vector2.INF
		_rebuild_hand()
	)

func _back_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
