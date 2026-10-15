class_name ComponentIcon
extends Control

var kind := "doric_column"
var color := Color("dac59d")

func _draw() -> void:
	var unit := minf(size.x, size.y) / 64
	draw_set_transform(Vector2((size.x-64*unit)/2, (size.y-64*unit)/2), 0, Vector2.ONE*unit)
	var light := color
	var shade := Color(color, 0.48)
	match kind:
		BuildCatalogue.TOOL_KIND:
			draw_rect(Rect2(18,9,37,37),shade,false,2)
			draw_rect(Rect2(8,19,37,37),light,false,2)
			for point in [Vector2(8,19),Vector2(45,19),Vector2(8,56),Vector2(45,56)]:
				draw_rect(Rect2(point-Vector2(3,3),Vector2(6,6)),light)
		"foundation":
			draw_rect(Rect2(6,29,52,15),shade)
			draw_rect(Rect2(6,26,52,4),light)
			draw_line(Vector2(6,45),Vector2(58,45),light,2)
		"foundation_long", "foundation_large":
			var paving := Rect2(5,21 if kind == "foundation_long" else 9,54,24 if kind == "foundation_long" else 46)
			draw_rect(paving,shade)
			draw_rect(paving,light,false,3)
			if kind == "foundation_long":
				for x in [18,32,46]: draw_line(Vector2(x,24),Vector2(x,42),light,1)
				draw_line(Vector2(8,33),Vector2(56,33),light,1)
			else:
				draw_polyline(PackedVector2Array([Vector2(32,17),Vector2(49,32),Vector2(32,47),Vector2(15,32),Vector2(32,17)]),light,2)
				for point in [Vector2(5,9),Vector2(59,9),Vector2(5,55),Vector2(59,55)]: draw_line(point,Vector2(32,32),light,1)
		"foundation_raised", "foundation_podium":
			var top := 14 if kind == "foundation_podium" else 26
			draw_rect(Rect2(14,top+6,36,48-top),shade)
			draw_rect(Rect2(8,top,48,5),light)
			draw_line(Vector2(11,top+6),Vector2(53,top+6),light,1)
			draw_rect(Rect2(8,54,48,5),light)
			draw_polyline(PackedVector2Array([Vector2(8,54),Vector2(14,49),Vector2(50,49),Vector2(56,54)]),light,1.5)
			if kind == "foundation_podium":
				draw_line(Vector2(14,35),Vector2(50,35),light,1)
				draw_line(Vector2(32,20),Vector2(32,35),light,1)
				for x in [23,41]: draw_line(Vector2(x,35),Vector2(x,49),light,1)
			else:
				draw_line(Vector2(32,33),Vector2(32,49),light,1)
		"step_support":
			draw_rect(Rect2(6,26,52,23),shade)
			draw_rect(Rect2(6,26,52,23),light,false,2)
			draw_line(Vector2(32,27),Vector2(32,48),light,1)
		"steps":
			for i in range(3):
				draw_rect(Rect2(6+i*4, 40-i*7, 52-i*8, 6), light)
		"doric_column", "ionic_column", "corinthian_column", "base", "shaft", "doric_capital", "ionic_capital", "corinthian_capital":
			if kind != "base":
				draw_rect(Rect2(23, 17, 18, 35), shade)
				for x in [24, 29, 34, 39]:
					draw_line(Vector2(x,20),Vector2(x,51),light,1.6)
			if kind != "shaft":
				draw_rect(Rect2(16, 53, 32, 5),light)
				draw_rect(Rect2(19, 49, 26, 3),light)
				draw_rect(Rect2(15, 11, 34, 5),light)
				draw_colored_polygon(PackedVector2Array([Vector2(18,16),Vector2(46,16),Vector2(40,21),Vector2(24,21)]),light)
			if "ionic" in kind:
				for x in [19,45]:
					draw_arc(Vector2(x,19),5,0,TAU*0.85,20,light,2)
			if "corinthian" in kind:
				for x in [22,29,36,43]:
					draw_polyline(PackedVector2Array([Vector2(x-3,23),Vector2(x-4,18),Vector2(x,14),Vector2(x+4,18),Vector2(x+3,23)]),light,1.5)
					draw_line(Vector2(x,23),Vector2(x,16),light,1)
				for x in [18,46]: draw_arc(Vector2(x,17),4,0,TAU*0.9,16,light,1.5)
		"entablature", "cornice":
			draw_rect(Rect2(5,21,54,6),light)
			draw_rect(Rect2(8,29,48,13),shade)
			draw_rect(Rect2(8,44,48,4),light)
			for x in range(10,55,6):
				draw_rect(Rect2(x,28,3,5),light)
		"pediment", "roof":
			draw_colored_polygon(PackedVector2Array([Vector2(5,43),Vector2(32,15),Vector2(59,43)]),shade)
			draw_polyline(PackedVector2Array([Vector2(5,43),Vector2(32,15),Vector2(59,43)]),light,3)
			draw_rect(Rect2(5,44,54,4),light)
			if kind == "roof":
				for i in range(4):
					draw_line(Vector2(16+i*5,33-i*4),Vector2(42+i*4,46-i*4),light,1)
		"wall_window_pediment", "wall_window_segmental", "wall_window_ellipse":
			draw_rect(Rect2(7,7,50,51),shade)
			for y in [16,27,38,49]: draw_line(Vector2(8,y),Vector2(56,y),light,0.7)
			draw_rect(Rect2(22,25,20,25),Color("18332f"))
			draw_line(Vector2(19,50),Vector2(45,50),light,3)
			for x in [20,44]: draw_line(Vector2(x,26),Vector2(x,48),light,2)
			if kind == "wall_window_pediment":
				draw_polyline(PackedVector2Array([Vector2(17,23),Vector2(32,12),Vector2(47,23),Vector2(17,23)]),light,2)
			elif kind == "wall_window_segmental":
				var crown := PackedVector2Array()
				for i in range(17): crown.append(Vector2(32-15+30*i/16.0,23-7*(sqrt(1.8*1.8-pow(-1+2*i/16.0,2))-sqrt(1.8*1.8-1))/(1.8-sqrt(1.8*1.8-1))))
				draw_colored_polygon(crown,shade)
				draw_polyline(crown,light,2)
				draw_line(Vector2(17,24),Vector2(47,24),light,2)
			else:
				var rim := PackedVector2Array()
				for i in range(17): rim.append(Vector2(32+12*cos(PI*i/16),26-10*sin(PI*i/16)))
				draw_colored_polygon(rim,Color("18332f"))
				draw_polyline(rim,light,2)
		"flat_roof":
			draw_colored_polygon(PackedVector2Array([Vector2(7,30),Vector2(34,16),Vector2(58,29),Vector2(31,44)]),light)
			draw_colored_polygon(PackedVector2Array([Vector2(7,30),Vector2(31,44),Vector2(58,29),Vector2(58,35),Vector2(31,50),Vector2(7,36)]),shade)
			draw_line(Vector2(20,23),Vector2(45,36),shade,1)
			draw_line(Vector2(19,37),Vector2(46,23),shade,1)
		"dome", "dome_large":
			var points := PackedVector2Array()
			for i in range(25):
				var angle := PI*i/24.0
				points.append(Vector2(32+24*cos(angle),41-24*sin(angle)))
			draw_colored_polygon(points,shade)
			draw_polyline(points,light,3)
			draw_rect(Rect2(8,41,48,6),shade)
			draw_rect(Rect2(5,47,54,5),light)
			if kind == "dome_large": draw_circle(Vector2(51,12),3,light)
		"roof_left", "roof_right", "roof_left_half", "roof_right_half", "stone_roof_left", "stone_roof_right", "stone_roof_left_half", "stone_roof_right_half":
			var flip := BuildCatalogue.roof_profile(kind) in ["right","right_half"]
			var low := Vector2(56 if flip else 8,45)
			var high := Vector2(8 if flip else 56,16)
			draw_colored_polygon(PackedVector2Array([low,high,high+Vector2(0,7),low+Vector2(0,7)]),shade)
			draw_line(low,high,light,4)
			draw_line(low+Vector2(0,7),high+Vector2(0,7),light,2)
			var joints := 4 if kind in BuildCatalogue.STONE_ROOF_KINDS else 7
			for i in range(1,joints):
				var point := low.lerp(high,float(i)/joints)
				draw_line(point,point+Vector2(0,7),light,1)
			if kind.ends_with("half"): draw_circle(Vector2(49,53),3,light)
		"pediment_left", "pediment_right":
			var flip := kind == "pediment_right"
			var low := Vector2(57 if flip else 7,48)
			var high := Vector2(7 if flip else 57,16)
			draw_colored_polygon(PackedVector2Array([low,high,Vector2(high.x,48)]),shade)
			draw_line(low,high,light,4)
			draw_line(low+Vector2(0,6),high+Vector2(0,6),light,1)
			for t in [0.2,0.4,0.6,0.8]:
				var p := low.lerp(high,t)+Vector2(0,4)
				draw_line(p,p+Vector2(0,4),light,2)
		"pediment_crown":
			draw_colored_polygon(PackedVector2Array([Vector2(5,45),Vector2(32,26),Vector2(59,45)]),shade)
			draw_polyline(PackedVector2Array([Vector2(5,45),Vector2(32,26),Vector2(59,45)]),light,4)
			draw_line(Vector2(32,13),Vector2(32,19),light,2)
		"pediment_backing":
			draw_rect(Rect2(6,17,52,34),shade)
			draw_rect(Rect2(6,17,52,34),light,false,2)
			for x in [19,32,45]:
				draw_circle(Vector2(x,30),2.8,light)
				draw_line(Vector2(x,35),Vector2(x,43),light,3)
		"pediment_base":
			for i in range(3): draw_rect(Rect2(5+i*2,30-i*5,54-i*4,4),light)
		"draped_statue":
			draw_circle(Vector2(32,15),5,light)
			draw_colored_polygon(PackedVector2Array([Vector2(24,23),Vector2(39,23),Vector2(36,35),Vector2(43,53),Vector2(21,53),Vector2(27,34)]),light)
			for x in [28,32,36]: draw_line(Vector2(32,32),Vector2(x,50),shade,1)
			draw_line(Vector2(46,11),Vector2(46,54),light,2)
			draw_line(Vector2(38,25),Vector2(46,32),light,3)
			draw_circle(Vector2(21,36),7,light)
			draw_circle(Vector2(21,36),4,shade)
			draw_rect(Rect2(16,55,35,3),light)
		"reclining_figure":
			draw_circle(Vector2(47,25),5,light)
			draw_line(Vector2(44,33),Vector2(29,42),light,9)
			draw_line(Vector2(29,42),Vector2(10,45),light,6)
			draw_polyline(PackedVector2Array([Vector2(12,45),Vector2(24,35),Vector2(32,41)]),light,4)
			draw_polyline(PackedVector2Array([Vector2(44,33),Vector2(54,42),Vector2(54,48)]),light,3)
			draw_rect(Rect2(5,50,54,3),light)
		"horse_relief":
			draw_style_box(_horse_body(light),Rect2(14,25,30,15))
			draw_colored_polygon(PackedVector2Array([Vector2(34,29),Vector2(40,12),Vector2(48,12),Vector2(52,23),Vector2(44,24),Vector2(42,34)]),light)
			draw_line(Vector2(43,14),Vector2(42,8),light,3)
			draw_polyline(PackedVector2Array([Vector2(18,35),Vector2(23,45),Vector2(17,54)]),light,3)
			draw_polyline(PackedVector2Array([Vector2(36,36),Vector2(44,46),Vector2(53,41)]),light,3)
			draw_line(Vector2(34,38),Vector2(36,54),light,3)
			draw_polyline(PackedVector2Array([Vector2(15,28),Vector2(8,33),Vector2(7,40)]),light,3)
		"wall":
			draw_rect(Rect2(8,12,48,43),shade)
			for y in range(12,56,10):
				draw_line(Vector2(8,y),Vector2(56,y),light,1.6)
				for x in range(8+((y/10)%2)*8,56,16):
					draw_line(Vector2(x,y),Vector2(x,mini(y+10,55)),light,1.4)
		"arch":
			draw_arc(Vector2(32,33),22,PI,TAU,32,light,7)
			draw_rect(Rect2(7,33,8,23),light)
			draw_rect(Rect2(49,33,8,23),light)
			for i in range(1,8):
				var a := PI + i * PI/8
				draw_line(Vector2(32,33)+Vector2(cos(a),sin(a))*19,Vector2(32,33)+Vector2(cos(a),sin(a))*26,Color("253333"),1)
		"balustrade":
			for x in range(12,56,10):
				draw_rect(Rect2(x,22,4,26),light)
				draw_circle(Vector2(x+2,34),4,light)
			draw_rect(Rect2(6,17,52,5),light)
			draw_rect(Rect2(6,48,52,5),light)
		"urn":
			draw_rect(Rect2(22,51,20,5),light)
			draw_rect(Rect2(28,36,8,16),light)
			draw_colored_polygon(PackedVector2Array([Vector2(17,20),Vector2(47,20),Vector2(42,36),Vector2(32,41),Vector2(22,36)]),light)
			draw_rect(Rect2(15,16,34,4),light)
			for x in [16,48]:
				draw_arc(Vector2(x,27),7,-PI/2,PI/2,20,light,2)
		"rectangular_pedestal":
			draw_rect(Rect2(7,43,50,7),light)
			draw_rect(Rect2(12,22,40,21),shade)
			draw_rect(Rect2(7,16,50,6),light)
			draw_line(Vector2(12,26),Vector2(52,26),light,1)
		"lion_statue":
			draw_rect(Rect2(5,48,54,4),light)
			draw_colored_polygon(PackedVector2Array([Vector2(8,36),Vector2(12,29),Vector2(30,27),Vector2(40,34),Vector2(36,44),Vector2(14,45)]),light)
			draw_circle(Vector2(43,25),12,shade)
			draw_circle(Vector2(46,24),8,light)
			draw_circle(Vector2(42,15),3,light)
			draw_rect(Rect2(48,26,9,6),light)
			draw_line(Vector2(34,39),Vector2(51,45),light,6)
			draw_line(Vector2(13,39),Vector2(8,28),shade,3)
		"pedestal":
			draw_rect(Rect2(18,14,28,5),light)
			draw_rect(Rect2(22,20,20,30),shade)
			draw_rect(Rect2(18,51,28,5),light)
		"finial":
			for i in range(9):
				var a := -1.2+i*0.3
				draw_line(Vector2(32,49),Vector2(32,49)+Vector2(sin(a),-cos(a))*33,light,3)
			draw_rect(Rect2(24,50,16,5),light)

func _horse_body(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(8)
	return style
