extends Node
## اختبار الانفجار بثلاث أنظمة (Debris/Fire/Smoke) - قيم درس LegionGames الحرفية
## youtu.be/RtJJVjjM_-Q: بلا shaders وبلا textures، 3 أنظمة GPU particles فقط.

const EPS := 0.001


func _ready() -> void:
	print("explosion_vfx_check START")
	var fails := 0

	# 1) مشهد المعاينة يُثبَت ويُطلق explode() تلقائياً بلا أخطاء
	var demo: Node3D = load("res://scenes/vfx/ExplosionDemo.tscn").instantiate()
	add_child(demo)
	await get_tree().process_frame
	await get_tree().process_frame
	if demo.get_node_or_null("ExplosionVFX") != null:
		print("PASS demo_spawned")
	else:
		print("FAIL demo_spawned")
		fails += 1
	demo.queue_free()

	# 2) فحص القيم على نسخة مستقلة (قبل الانفجار)
	var vfx: Node3D = load("res://scenes/vfx/ExplosionVFX.tscn").instantiate()
	add_child(vfx)
	await get_tree().process_frame

	for kind in ["Debris", "Fire", "Smoke"]:
		if vfx.get_node_or_null(kind) == null:
			print("FAIL missing ", kind)
			fails += 1
	if vfx.get_node_or_null("Audio") is AudioStreamPlayer3D:
		print("PASS audio_node")
	else:
		print("FAIL audio_node")
		fails += 1

	# 3) Debris: amount=24 life=0.5 spread=180 vel=12..14 align_y scale=0.5..1.5
	var d := vfx.get_node("Debris") as GPUParticles3D
	if d.amount == 24 and absf(d.lifetime - 0.5) < EPS and d.one_shot \
			and absf(d.explosiveness - 1.0) < EPS and d.fixed_fps == 60 and not d.emitting:
		print("PASS debris_time")
	else:
		print("FAIL debris_time amount=", d.amount, " life=", d.lifetime)
		fails += 1
	var dp := d.process_material as ParticleProcessMaterial
	if absf(dp.spread - 180.0) < EPS and absf(dp.initial_velocity_min - 12.0) < EPS \
			and absf(dp.initial_velocity_max - 14.0) < EPS and dp.particle_flag_align_y \
			and absf(dp.scale_min - 0.5) < EPS and absf(dp.scale_max - 1.5) < EPS:
		print("PASS debris_pp")
	else:
		print("FAIL debris_pp")
		fails += 1
	if dp.scale_curve is CurveTexture and _curve_pts(dp.scale_curve) == 3 \
			and absf(_curve_y(dp.scale_curve, 2) - 0.0) < EPS:
		print("PASS debris_scale_curve")
	else:
		print("FAIL debris_scale_curve")
		fails += 1
	var cm := d.draw_pass_1 as CylinderMesh
	if cm != null and absf(cm.top_radius - 0.1) < EPS and absf(cm.bottom_radius - 0.0) < EPS \
			and absf(cm.height - 2.0) < EPS:
		print("PASS debris_cylinder")
	else:
		print("FAIL debris_cylinder")
		fails += 1
	var dm := cm.material as StandardMaterial3D
	if dm.emission_enabled and absf(dm.emission_energy_multiplier - 2.0) < EPS \
			and dm.albedo_color.is_equal_approx(dm.emission):
		print("PASS debris_mat")
	else:
		print("FAIL debris_mat")
		fails += 1

	# 4) Fire: amount=12 life=1.0 sphere r=1 dir=(0,-1,0) spread=90 vel=2..4 gravity=+5
	var f := vfx.get_node("Fire") as GPUParticles3D
	if f.amount == 12 and absf(f.lifetime - 1.0) < EPS and f.one_shot \
			and absf(f.explosiveness - 1.0) < EPS and f.fixed_fps == 60:
		print("PASS fire_time")
	else:
		print("FAIL fire_time amount=", f.amount, " life=", f.lifetime)
		fails += 1
	var fp := f.process_material as ParticleProcessMaterial
	if fp.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_SPHERE \
			and absf(fp.emission_sphere_radius - 1.0) < EPS \
			and fp.direction.is_equal_approx(Vector3(0, -1, 0)) \
			and absf(fp.spread - 90.0) < EPS \
			and absf(fp.initial_velocity_min - 2.0) < EPS \
			and absf(fp.initial_velocity_max - 4.0) < EPS \
			and fp.gravity.is_equal_approx(Vector3(0, 5, 0)):
		print("PASS fire_pp")
	else:
		print("FAIL fire_pp")
		fails += 1
	if absf(fp.scale_min - 0.5) < EPS and absf(fp.scale_max - 1.5) < EPS \
			and fp.scale_curve is CurveTexture and _curve_pts(fp.scale_curve) == 3 \
			and absf(_curve_y(fp.scale_curve, 0) - 0.01) < EPS:
		print("PASS fire_scale")
	else:
		print("FAIL fire_scale")
		fails += 1
	if fp.color.is_equal_approx(Color(1, 0.9, 0.2)) and fp.color_ramp != null \
			and fp.color_ramp.gradient.get_point_count() == 3:
		print("PASS fire_color_ramp")
	else:
		print("FAIL fire_color_ramp")
		fails += 1
	if fp.emission_curve is CurveTexture and _curve_pts(fp.emission_curve) == 2 \
			and absf(_curve_y(fp.emission_curve, 0) - 2.0) < EPS \
			and absf(_curve_y(fp.emission_curve, 1) - 1.0) < EPS:
		print("PASS fire_emission_curve")
	else:
		print("FAIL fire_emission_curve")
		fails += 1
	var fm := (f.draw_pass_1 as SphereMesh).material as StandardMaterial3D
	if (f.draw_pass_1 as SphereMesh).radial_segments == 8 \
			and (f.draw_pass_1 as SphereMesh).rings == 4 \
			and fm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
			and fm.vertex_color_use_as_albedo:
		print("PASS fire_sphere_mat")
	else:
		print("FAIL fire_sphere_mat")
		fails += 1

	# 5) Smoke: amount=12 life=2.0 spread=45 vel=1..2 gray + alpha_curve بلا ramp/emission
	var s := vfx.get_node("Smoke") as GPUParticles3D
	if s.amount == 12 and absf(s.lifetime - 2.0) < EPS and s.one_shot \
			and absf(s.explosiveness - 1.0) < EPS and s.fixed_fps == 60:
		print("PASS smoke_time")
	else:
		print("FAIL smoke_time amount=", s.amount, " life=", s.lifetime)
		fails += 1
	var sp := s.process_material as ParticleProcessMaterial
	if absf(sp.spread - 45.0) < EPS and absf(sp.initial_velocity_min - 1.0) < EPS \
			and absf(sp.initial_velocity_max - 2.0) < EPS \
			and sp.direction.is_equal_approx(Vector3(0, -1, 0)) \
			and sp.gravity.is_equal_approx(Vector3(0, 5, 0)) \
			and sp.color.is_equal_approx(Color(0.5, 0.5, 0.5)) \
			and sp.color_ramp == null and sp.emission_curve == null:
		print("PASS smoke_pp")
	else:
		print("FAIL smoke_pp")
		fails += 1
	if sp.alpha_curve is CurveTexture and _curve_pts(sp.alpha_curve) == 3 \
			and absf(_curve_y(sp.alpha_curve, 0) - 0.0) < EPS \
			and absf(_curve_x(sp.alpha_curve, 1) - 0.6) < EPS \
			and absf(_curve_y(sp.alpha_curve, 1) - 0.8) < EPS \
			and absf(_curve_y(sp.alpha_curve, 2) - 0.0) < EPS:
		print("PASS smoke_alpha_curve")
	else:
		print("FAIL smoke_alpha_curve")
		fails += 1
	var sm := (s.draw_pass_1 as SphereMesh).material as StandardMaterial3D
	if (s.draw_pass_1 as SphereMesh).radial_segments == 8 \
			and (s.draw_pass_1 as SphereMesh).rings == 4 \
			and sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
			and sm.vertex_color_use_as_albedo:
		print("PASS smoke_sphere_mat")
	else:
		print("FAIL smoke_sphere_mat")
		fails += 1
	if f.process_material != s.process_material:
		print("PASS smoke_material_unique")
	else:
		print("FAIL smoke_material_unique")
		fails += 1

	# 6) explode() يشغّل الأنظمة الثلاثة فوراً
	vfx.call("explode")
	var all_emitting := true
	for kind in ["Debris", "Fire", "Smoke"]:
		if not (vfx.get_node(kind) as GPUParticles3D).emitting:
			all_emitting = false
	if all_emitting:
		print("PASS explode_starts_all")
	else:
		print("FAIL explode_starts_all")
		fails += 1

	if fails == 0:
		print("explosion_vfx_check ALL_PASS")
	else:
		print("explosion_vfx_check FAILED count=", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _curve_pts(t: Texture2D) -> int:
	return (t as CurveTexture).curve.get_point_count()


func _curve_y(t: Texture2D, idx: int) -> float:
	return (t as CurveTexture).curve.get_point_position(idx).y


func _curve_x(t: Texture2D, idx: int) -> float:
	return (t as CurveTexture).curve.get_point_position(idx).x
