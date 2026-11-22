extends RefCounted

## Builds the two-tone rank outline shown on lobby match rows: the left half of
## the ring uses one player's rank league color and the right half the other's,
## so cross-rank matchups stand out while scanning the seek list.

const Catalog = preload("res://scripts/core/RankBadgeCatalog.gd")

const RING_ICON_SIZE := 16

static var _texture_cache: Dictionary = {}


## Returns a cached ring texture for the given player leagues. Each league is
## clamped to the known leagues; entries below 0 fall back to a neutral color.
## The first league fills the left half and the second the right half.
static func ring_texture(leagues: Array, size: int = RING_ICON_SIZE) -> ImageTexture:
	var normalized: Array[int] = []
	for league in leagues:
		normalized.append(int(league))
	var key := "%d|%s" % [size, str(normalized)]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * float(size - 1) * 0.5
	var outer := (size - 1) * 0.5
	var inner := outer * 0.48
	for y in size:
		for x in size:
			var distance := float(Vector2(x, y).distance_to(center))
			var coverage := clampf(outer - distance + 0.5, 0.0, 1.0) \
				* clampf(distance - inner + 0.5, 0.0, 1.0)
			if coverage <= 0.0:
				continue
			var side := 0 if x + 0.5 < size * 0.5 else 1
			var color := league_color(normalized[mini(side, normalized.size() - 1)])
			image.set_pixel(x, y, Color(color.r, color.g, color.b, coverage))
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


static func league_color(league: int) -> Color:
	if league < 0 or league >= Catalog.LEAGUE_COLORS.size():
		return Catalog.UNKNOWN_LEAGUE_COLOR
	return Catalog.LEAGUE_COLORS[league]
