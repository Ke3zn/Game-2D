extends Node

const BGM_QUIET_PATH := "res://asset/music/background music/baim_quite_place_backsound.wav"
const BGM_BATTLE_PATH := "res://asset/music/background music/baim_battle_backsound.wav"
const SFX_FIRE_PATH := "res://asset/music/sfx/fire.wav"

const FIRE_HEAR_RADIUS := 185.0
const FIRE_FULL_VOL_RADIUS := 42.0
const QUIET_BGM_DB := -17.0
const BATTLE_BGM_DB := -15.0

var _bgm_quiet: AudioStreamPlayer
var _bgm_battle: AudioStreamPlayer
var _sfx_fire: AudioStreamPlayer

var _in_boss_battle: bool = false
var _quiet_target_db: float = QUIET_BGM_DB
var _battle_target_db: float = -60.0

func _ready() -> void:
	_bgm_quiet = _make_loop_player(BGM_QUIET_PATH, QUIET_BGM_DB)
	_bgm_battle = _make_loop_player(BGM_BATTLE_PATH, -60.0)
	_sfx_fire = _make_loop_player(SFX_FIRE_PATH, -60.0)

	if _bgm_quiet and _bgm_quiet.stream:
		_bgm_quiet.play()
	if _bgm_battle and _bgm_battle.stream:
		_bgm_battle.play()

func _make_loop_player(path: String, initial_db: float) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.volume_db = initial_db
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamMP3:
			stream.loop = true
		player_node.stream = stream
	add_child(player_node)
	player_node.finished.connect(func():
		if player_node.stream and is_inside_tree():
			if player_node == _sfx_fire and _sfx_fire.volume_db <= -55.0:
				return
			player_node.play()
	)
	return player_node

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return

	# Cek apakah sedang melawan BossNormal (BUKAN BossSlime)
	var fighting_normal_boss := false
	if not player.get("is_dead"):
		for b in get_tree().get_nodes_in_group("boss_normal"):
			if is_instance_valid(b) and not b.get("is_dead"):
				var det_r: float = float(b.get("detection_radius")) if b.get("detection_radius") != null else 195.0
				if player.global_position.distance_to((b as Node2D).global_position) <= det_r:
					fighting_normal_boss = true
					break

	if fighting_normal_boss != _in_boss_battle:
		_in_boss_battle = fighting_normal_boss
		_quiet_target_db = -60.0 if _in_boss_battle else QUIET_BGM_DB
		_battle_target_db = BATTLE_BGM_DB if _in_boss_battle else -60.0

	if _bgm_quiet:
		_bgm_quiet.volume_db = move_toward(_bgm_quiet.volume_db, _quiet_target_db, delta * 36.0)
	if _bgm_battle:
		_bgm_battle.volume_db = move_toward(_bgm_battle.volume_db, _battle_target_db, delta * 36.0)

	# Ambient api hanya saat player dekat hutan/pohon yang masih terbakar
	var min_fire_dist: float = INF
	for tree in get_tree().get_nodes_in_group("burning_tree"):
		if is_instance_valid(tree):
			var st = tree.get("current_stage")
			# STAGE_1..STAGE_3 (0, 1, 2) masih menyala; STAGE_4_OUT (3) & STAGE_4_FINAL (4) sudah padam
			if st != null and int(st) < 3:
				var d := player.global_position.distance_to((tree as Node2D).global_position)
				if d < min_fire_dist:
					min_fire_dist = d

	if _sfx_fire and _sfx_fire.stream:
		if min_fire_dist <= FIRE_HEAR_RADIUS:
			var t := clampf((min_fire_dist - FIRE_FULL_VOL_RADIUS) / (FIRE_HEAR_RADIUS - FIRE_FULL_VOL_RADIUS), 0.0, 1.0)
			var target_fire_db := lerpf(-4.0, -34.0, t)
			if not _sfx_fire.playing:
				_sfx_fire.volume_db = target_fire_db
				_sfx_fire.play()
			else:
				_sfx_fire.volume_db = move_toward(_sfx_fire.volume_db, target_fire_db, delta * 45.0)
		else:
			_sfx_fire.volume_db = move_toward(_sfx_fire.volume_db, -60.0, delta * 50.0)
			if _sfx_fire.playing and _sfx_fire.volume_db <= -55.0:
				_sfx_fire.stop()
