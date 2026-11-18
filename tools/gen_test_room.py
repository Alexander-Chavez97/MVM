# Regenerates scenes/test_room.tscn from the block list below.
# Run from the project root with Godot CLOSED:  python3 tools/gen_test_room.py
# blocks: name, left, top, right, bottom (px, +y is down, floor surface at y=520)
blocks = [
    ("FloorLeft",   -320, 520,  700, 600),
    ("PitFloor",     700, 580,  820, 640),
    ("FloorRight",   820, 520, 1300, 600),
    ("WallLeft",    -360,   0, -320, 600),
    ("WallRight",   1300,   0, 1340, 600),
    ("LedgeLow",     200, 440,  360, 460),
    ("LedgeHigh",    440, 330,  600, 350),
    ("TunnelRoof",   940, 300, 1140, 488),
    ("ClimbPillar", -220, 200, -160, 520),   # 100 px gap to WallLeft: wall-jump practice
]
# grapple points: name, x, y
grapple_points = [
    ("HookLedge",  300, 230),   # above the low ledge: swing up to the high ledge
    ("HookPit",    760, 330),   # over the pit: swing across, launch onto the tunnel roof
    ("HookHigh",  1220, 150),   # reachable from the tunnel roof
]
# training dummies: name, x (they stand on the floor)
dummies = [
    ("Dummy1",  160),
    ("Dummy2",  560),
    ("Dummy3", 1220),
]
# walker enemies: name, x
walkers = [
    ("Walker1", 380),   # left floor, between the dummies
    ("Walker2", 900),   # right floor; small enough to patrol through the tunnel
]
out = ['[gd_scene format=3]', '',
       '[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="1_player"]',
       '[ext_resource type="PackedScene" path="res://scenes/grapple_point.tscn" id="2_grapple"]',
       '[ext_resource type="PackedScene" path="res://scenes/dummy.tscn" id="3_dummy"]',
       '[ext_resource type="PackedScene" path="res://scenes/walker.tscn" id="4_walker"]',
       '[ext_resource type="PackedScene" path="res://scenes/hud.tscn" id="5_hud"]', '']
for n, l, t, r, b in blocks:
    out += [f'[sub_resource type="RectangleShape2D" id="Shape_{n}"]', f'size = Vector2({r-l}, {b-t})', '']
out += ['[node name="TestRoom" type="Node2D"]', '',
        '[node name="Background" type="Polygon2D" parent="."]', 'z_index = -10',
        'color = Color(0.13, 0.12, 0.16, 1)',
        'polygon = PackedVector2Array(-2000, -1500, 3000, -1500, 3000, 2000, -2000, 2000)', '']
for n, l, t, r, b in blocks:
    cx, cy, hw, hh = (l+r)/2, (t+b)/2, (r-l)/2, (b-t)/2
    out += [f'[node name="{n}" type="StaticBody2D" parent="."]', f'position = Vector2({cx:g}, {cy:g})', '',
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{n}"]', f'shape = SubResource("Shape_{n}")', '',
            f'[node name="Visual" type="Polygon2D" parent="{n}"]', 'color = Color(0.35, 0.4, 0.38, 1)',
            f'polygon = PackedVector2Array({-hw:g}, {-hh:g}, {hw:g}, {-hh:g}, {hw:g}, {hh:g}, {-hw:g}, {hh:g})', '']
for n, x, y in grapple_points:
    out += [f'[node name="{n}" parent="." instance=ExtResource("2_grapple")]', f'position = Vector2({x}, {y})', '']
for n, x in dummies:
    out += [f'[node name="{n}" parent="." instance=ExtResource("3_dummy")]', f'position = Vector2({x}, 520)', '']
for n, x in walkers:
    out += [f'[node name="{n}" parent="." instance=ExtResource("4_walker")]', f'position = Vector2({x}, 520)', '']
out += ['[node name="HUD" parent="." instance=ExtResource("5_hud")]', '']
out += ['[node name="Player" parent="." instance=ExtResource("1_player")]', 'position = Vector2(0, 520)', '']
open('scenes/test_room.tscn', 'w').write('\n'.join(out))
print("wrote scenes/test_room.tscn")
