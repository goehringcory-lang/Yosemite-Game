#!/usr/bin/env python3
"""Writes scenes/story/dressing/tuolumne_meadows.tscn: young lodgepoles along
the edges of Tuolumne's meadows (where the forest is slowly closing in on the
grass), and the props round the store and grill, the lodge and the trails.

StoryContent attaches every scenes/story/dressing/<region>.tscn on a region's
first visit, like the story overlays, so a rebuild of the region keeps it.

    python3 tools/hubs/tuolumne_dressing.py            # rewrite the scene
    python3 tools/hubs/tuolumne_dressing.py --place    # also re-pick the saplings

--place reads the painted ground (ground_tuolumne_meadows.png) and the trees
in the region scene, picks spots on the sand just outside the meadow's edge,
clear of water, roads, paths and everything standing, and saves them to
tools/hubs/tuolumne_saplings.json. Without it the saved spots are used, so a
repaint of the ground doesn't move the trees.
"""
from __future__ import annotations

import json
import os
import random
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REGION = os.path.join(ROOT, "scenes/regions/tuolumne_meadows.tscn")
GROUND = os.path.join(ROOT, "assets/sprites/ahwahnee/ground_tuolumne_meadows.png")
SPOTS = os.path.join(ROOT, "tools/hubs/tuolumne_saplings.json")
OUT = os.path.join(ROOT, "scenes/story/dressing/tuolumne_meadows.tscn")
TM = "res://assets/sprites/tuolumne/"
SAP = "res://assets/sprites/ahwahnee/tree_lodgepole_sapling_%d.png"
## Keep the footbridge's approaches clear (world x of the bridge).
BRIDGE_X = 2016

# name, texture, position, sprite height (px), collision size, info [title, text] or None
PROPS = [
	("EntranceSign", "entrance_sign", (1300, 1380), 64, (120, 12), [
		"Tuolumne Meadows",
		"Elevation 8,600 feet. The largest subalpine meadow in the Sierra Nevada, ringed by lodgepole pine and granite domes. Snow covers it half the year; the Tioga Road over it is closed from about November to May or June."]),
	("StorePorchBench", "porch_bench", (2714, 1690), 32, (52, 8), None),
	("StoreIceChest", "ice_chest", (2826, 1690), 40, (48, 10), [
		"Ice",
		"Block and cubed ice, for the coolers of the campground across the road. Ask inside."]),
	("StoreFirewood", "firewood_rack", (2640, 1692), 52, (68, 10), [
		"Firewood",
		"Bundles of split wood for campfires. Gather only dead and down wood yourself, and never above 9,600 feet: up there, wood rots so slowly that every stick matters."]),
	("GasPump", "gas_pump", (2580, 1684), 68, (24, 10), [
		"Gas pump",
		"An old pump like the ones at the little gas station beside the store, the last fuel before the long climb over Tioga Pass."]),
	("LodgeWoodpile", "woodpile", (4300, 1750), 44, (72, 10), [
		"Woodpile",
		"Lodgepole rounds for the wood stoves in the tent cabins. Nights at 8,600 feet go below freezing even in July."]),
	("LyellJunctionSign", "junction_sign", (4060, 2044), 72, (12, 8), [
		"Trail junction",
		"South up Lyell Canyon, the John Muir Trail and the Pacific Crest Trail share the same path for miles. Hikers walking from Mexico to Canada pass the lodge here, often stopping at the store for their resupply box."]),
]
# lantern posts along the lodge path, lit after dark: (name, position)
LAMPS = [("LodgeLampWest", (4088, 1780)), ("LodgeLampEast", (4200, 1780)), ("StoreLamp", (2900, 1690))]
# chimney smoke from the tin stovepipes: (name, position)
SMOKE = [("StoreSmoke", (2834, 1542)), ("LodgeSmoke", (4198, 1618))]


def entities() -> list[tuple[str, float, float]]:
	s = open(REGION).read()
	out = []
	for m in re.finditer(r'\[node name="([^"]+)" type="StaticBody2D" parent="Entities"[^\]]*\]\nposition = Vector2\(([^)]+)\)', s):
		x, y = (float(v) for v in m.group(2).split(","))
		out.append((m.group(1), x, y))
	return out


def place() -> list[list[int]]:
	import numpy as np
	from PIL import Image
	a = np.asarray(Image.open(GROUND).convert("RGB")).astype(float)
	H, W = a.shape[0] // 8, a.shape[1] // 8
	blk = a[:H * 8, :W * 8].reshape(H, 8, W, 8, 3)
	mean = blk.mean(axis=(1, 3))
	var = blk.std(axis=(1, 3)).mean(axis=2)
	r, g, b = mean[..., 0], mean[..., 1], mean[..., 2]
	# the meadow: green cells, smoothed so speckles in the sand don't count
	green0 = ((g - r > 12) & (g - b > 12)).astype(float)
	k = 3
	pad = np.pad(green0, k, mode="edge")
	acc = np.zeros_like(green0)
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			acc += pad[k + dy:k + dy + H, k + dx:k + dx + W]
	green = acc / (2 * k + 1) ** 2 > 0.5
	water = b - r > 15
	lum = (r + g + b) / 3
	road = (lum < 100) & (abs(r - b) < 25)
	path = (var < 10) & (r > 190)

	def dist(mask, maxd):
		d = np.full(mask.shape, 99.0)
		cur = mask.copy()
		d[mask] = 0
		for step in range(1, maxd + 1):
			n = cur.copy()
			n[1:] |= cur[:-1]
			n[:-1] |= cur[1:]
			n[:, 1:] |= cur[:, :-1]
			n[:, :-1] |= cur[:, 1:]
			d[n & ~cur] = step
			cur = n
		return d

	dg, dbad, dw = dist(green, 14), dist(water | road | path, 14), dist(water, 10)
	ents = entities()
	others = [(x, y) for n, x, y in ents if not n.startswith(("Tree", "Plant"))]
	flora = [(x, y) for n, x, y in ents if n.startswith(("Tree", "Plant"))]
	rng = random.Random(1923)
	cands = []
	for cy in range(4, H - 4):
		for cx in range(4, W - 4):
			if green[cy, cx] or water[cy, cx] or road[cy, cx] or dbad[cy, cx] < 3 or dw[cy, cx] < 8:
				continue
			if 1 <= dg[cy, cx] <= 9:
				cands.append((dg[cy, cx] + rng.random() * 3, cx * 8 + 4, cy * 8 + 4))
	cands.sort()
	placed: list[list[int]] = []

	def ok(x, y):
		if abs(x - BRIDGE_X) < 120:
			return False
		if any((px - x) ** 2 + (py - y) ** 2 < 56 ** 2 for px, py in placed):
			return False
		if any((px - x) ** 2 + (py - y) ** 2 < 110 ** 2 and -40 < y - py < 120 for px, py in others):
			return False
		return not any((px - x) ** 2 + (py - y) ** 2 < 34 ** 2 for px, py in flora)

	for _, x, y in cands:
		if ok(x, y) and rng.random() < 0.55:
			placed.append([x, y])
	return placed


def write(spots: list[list[int]]) -> None:
	ext = [
		'[ext_resource type="Texture2D" path="%s" id="sap1"]' % (SAP % 1),
		'[ext_resource type="Texture2D" path="%s" id="sap2"]' % (SAP % 2),
		'[ext_resource type="Script" path="res://scripts/objects/info_sign.gd" id="info"]',
		'[ext_resource type="Script" path="res://scripts/world/night_light.gd" id="light"]',
		'[ext_resource type="Script" path="res://scripts/world/ambient_fx.gd" id="fx"]',
		'[ext_resource type="Texture2D" path="%slamp_post.png" id="lamp_post"]' % TM,
	]
	for p in PROPS:
		ext.append('[ext_resource type="Texture2D" path="%s%s.png" id="%s"]' % (TM, p[1], p[1]))
	subs = ['[sub_resource type="RectangleShape2D" id="sap_shape"]\nsize = Vector2(10, 6)',
		'[sub_resource type="RectangleShape2D" id="lamp_shape"]\nsize = Vector2(8, 6)']
	reach = {}
	for p in PROPS:
		subs.append('[sub_resource type="RectangleShape2D" id="%s_shape"]\nsize = Vector2(%d, %d)' % (p[0], p[4][0], p[4][1]))
		if p[5]:
			subs.append('[sub_resource type="RectangleShape2D" id="%s_reach"]\nsize = Vector2(%d, %d)' % (p[0], p[4][0] + 8, 28))
			reach[p[0]] = True
	nodes = ['[node name="TuolumneMeadowsDressing" type="Node2D"]']
	for i, (x, y) in enumerate(spots):
		v = 1 + (i * 7 + x // 16) % 2
		h = 96 if v == 1 else 76
		nodes.append('[node name="TreeLodgepoleSapling%d" type="StaticBody2D" parent="."]\nposition = Vector2(%d, %d)\ncollision_mask = 0' % (i, x, y))
		nodes.append('[node name="Sprite" type="Sprite2D" parent="TreeLodgepoleSapling%d"]\ntexture = ExtResource("sap%d")\noffset = Vector2(0, %d)' % (i, v, -(h // 2 - 4)))
		nodes.append('[node name="Collision" type="CollisionShape2D" parent="TreeLodgepoleSapling%d"]\nposition = Vector2(0, -3)\nshape = SubResource("sap_shape")' % i)
	for name, tex, (x, y), h, size, info in PROPS:
		head = '[node name="%s" type="StaticBody2D" parent="."]\nposition = Vector2(%d, %d)\ncollision_mask = 0' % (name, x, y)
		if info:
			head += '\nscript = ExtResource("info")\ntitle = %s\ntext = %s' % (json.dumps(info[0]), json.dumps(info[1]))
		nodes.append(head)
		nodes.append('[node name="Sprite" type="Sprite2D" parent="%s"]\ntexture = ExtResource("%s")\noffset = Vector2(0, %d)' % (name, tex, -h // 2))
		nodes.append('[node name="Collision" type="CollisionShape2D" parent="%s"]\nposition = Vector2(0, -%d)\nshape = SubResource("%s_shape")' % (name, size[1] // 2, name))
		if info:
			nodes.append('[node name="Hitbox" type="Area2D" parent="%s"]\ncollision_layer = 4\ncollision_mask = 0\nmonitoring = false' % name)
			nodes.append('[node name="Shape" type="CollisionShape2D" parent="%s/Hitbox"]\nposition = Vector2(0, -12)\nshape = SubResource("%s_reach")' % (name, name))
	for name, (x, y) in LAMPS:
		nodes.append('[node name="%s" type="StaticBody2D" parent="."]\nposition = Vector2(%d, %d)\ncollision_mask = 0' % (name, x, y))
		nodes.append('[node name="Sprite" type="Sprite2D" parent="%s"]\ntexture = ExtResource("lamp_post")\noffset = Vector2(0, -36)' % name)
		nodes.append('[node name="Collision" type="CollisionShape2D" parent="%s"]\nposition = Vector2(-10, -3)\nshape = SubResource("lamp_shape")' % name)
		nodes.append('[node name="NightLight" type="PointLight2D" parent="%s"]\nposition = Vector2(10, -50)\nscript = ExtResource("light")\nstrength = 0.8\nradius = 72.0\nflicker = 0.3' % name)
	for name, (x, y) in SMOKE:
		nodes.append('[node name="%s" type="CPUParticles2D" parent="."]\nposition = Vector2(%d, %d)\nscript = ExtResource("fx")\narea = Vector2(2, 1)' % (name, x, y))
	text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n" + "\n\n".join(nodes) + "\n"
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	open(OUT, "w").write(text)


def main() -> None:
	if "--place" in sys.argv[1:] or not os.path.exists(SPOTS):
		spots = place()
		json.dump(spots, open(SPOTS, "w"))
	spots = json.load(open(SPOTS))
	write(spots)
	print("wrote", OUT, "with", len(spots), "saplings")


if __name__ == "__main__":
	main()
