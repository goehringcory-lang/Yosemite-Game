"""Ground ramps for the native 32px painter, dark to light.

They extend the Valley Days palette (tools/art32/palette.py) with the
in-between steps ground needs to read as one calm surface: each ramp keeps a
palette ramp's hue family and shifts cool in the shadows and warm in the light,
as the palette does. A ground pixel is always one of these colors.
"""

RAMPS: dict[str, list[str]] = {
    # Valley meadow turf in June: sedge and grass, warm in the light.
    "grass": ["1c3a26", "26492b", "325a30", "3f6b33", "4d7c36", "5e8d3b", "729e43", "88ae4f", "a2c160", "bdd477"],
    # Wet meadow: bluer, denser sedge.
    "sedge": ["173528", "1f4430", "2a5436", "36643b", "437440", "538548", "659552", "7aa55f"],
    # Ponderosa and incense cedar needle duff.
    "duff": ["2b211b", "3c2e23", "4f3c2c", "624b35", "755a3f", "88694a", "9b7a56", "ad8c65"],
    # Oak leaf litter in the foothills: tan and russet.
    "litter": ["3a2a1c", "523b25", "6a4d2e", "82603a", "9a7447", "b08857", "c29c6a"],
    # Foothill grass cured to straw by June.
    "straw": ["5a4630", "72583a", "8b6c43", "a3824f", "b9985e", "cbad70", "dbc186", "e8d4a0"],
    # Chaparral soil: decomposed granite stained red-brown.
    "soil": ["3e2a20", "553a29", "6c4b33", "835e40", "9a724f", "b08862", "c39e78"],
    # Red fir duff at 7,000 feet: dark, with cones.
    "firduff": ["1f1a16", "2b231c", "392e24", "483a2c", "584835", "6a5840", "7d6a50", "927f63"],
    # Granite, cool grey to warm white.
    "granite": ["34343b", "46464d", "5a5a60", "6e6d6f", "838180", "999590", "aea99f", "c3bdb0", "d7d1c2", "e9e4d6"],
    # Asphalt: blue-black to sun-faded grey.
    "asphalt": ["1d1e23", "25272c", "2e3035", "373a3f", "42454a", "4e5155", "5c5e61", "6b6c6d"],
    # Concrete walks and plazas, warm with granite aggregate.
    "concrete": ["57544f", "68655e", "7a766e", "8c887e", "9e998d", "b0aa9c", "c1bbac", "d1cbbc"],
    # Decomposed granite trails.
    "trail": ["5c4632", "725a40", "88704f", "9e8660", "b29b71", "c4ae84", "d4c098", "e0cfaa"],
    # River sand and gravel bars.
    "sand": ["6b5c4a", "7d6c55", "958267", "ac9a7c", "c1b090", "d3c4a6", "e3d7bd", "efe6d0"],
    # Trampled campground dirt.
    "camp": ["4a3828", "5d4732", "70573d", "846a4a", "987d59", "aa906a", "baa27d"],
    # Water, deep pool to sunlit shallows.
    # The Merced runs clear over granite: emerald pools, teal runs.
    "water": ["14394a", "184654", "1d535d", "236166", "2b706f", "377f78", "478e81", "5a9c8a", "70aa93", "88b89d", "a3c8aa"],
    # Lake water: greener and stiller.
    "lake": ["16363e", "1b434a", "215155", "285f5f", "316d68", "3d7b70", "4c8a78", "5e9881", "73a68b"],
    # Footbridge decking: weathered planks.
    "wood": ["2a1b14", "47301f", "5f4129", "785434", "8f6a44", "a68156", "b99868"],
    # Garden soil under the flower beds.
    "bed": ["2e2016", "3a2a1c", "4a3524", "5a402a", "6a4d33", "7c5c3e"],
}

# Single colors painted over the ramps.
COLORS: dict[str, str] = {
    "foam": "e3f1ec",
    "foam_hi": "f7fcfa",
    "foam_lo": "b9d6d0",
    "yellow": "d8a63b",
    "yellow_dk": "ad7a22",
    "white": "e4ddcc",
    "white_dk": "bdb8ae",
    "seed": "cbb46f",
    "seed_dk": "9c8550",
    "lupine": "6f5aa6",
    "lupine_hi": "9a86cf",
    "yarrow": "f5eee0",
    "poppy": "f7a64a",
    "shooting": "d47a9b",
    "buttercup": "f1cf6a",
    "clover": "e8f0d6",
    "cone": "6b4829",
    "cone_hi": "92693d",
    "cone_dk": "3b2a1d",
    "twig": "4a3420",
    "twig_hi": "7a5a3a",
    "leaf_oak": "ad7a22",
    "leaf_oak2": "7e531c",
    "leaf_dk": "4f3a22",
    "lichen": "b8c08a",
    "lichen_o": "d9772a",
    "lichen_dk": "7f8a66",
    "peb_a": "c3bdb0",
    "peb_b": "93918f",
    "peb_c": "6a5e50",
    "peb_d": "e4ddcc",
    "peb_sh": "4a4038",
    "oil": "1a1b1f",
    "curb_hi": "c9c3b4",
    "curb": "9d988c",
    "curb_dk": "5f5b55",
    "mud": "3a2c20",
    "manz_leaf": "6b7a3e",
    "manz_leaf2": "4c5a2c",
    "bark_chip": "8a5a3a",
}
