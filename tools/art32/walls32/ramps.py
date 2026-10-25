"""Colour ramps for the cliff paintings, dark (deep shade) to light (full sun),
cool in the shadows and warm in the light like the rest of the 32px art.

Yosemite's walls are pale granite and granodiorite, grey-white in sun and
blue-grey in shade, streaked black where water runs off the rim (lichen and
cyanobacteria), stained tan and gold where iron weathers out, and bright
cream where a slab has fallen recently. Forest stands on every bench, ledge
and talus slope that will hold it.
"""

RAMPS: dict[str, list[str]] = {
    # The granite: blue-grey shade to warm white in the sun.
    "granite": ["2a2d38", "383c48", "494d59", "5c5f69", "717379", "88888a", "a09d9a", "b7b2aa", "ccc6ba",
                "dfd9cb", "eeeadc"],
    # Golden-tan granite: El Capitan's warm faces, iron-stained rock.
    "warm": ["342e2d", "48403c", "5e554e", "756b61", "8c8075", "a39689", "b8aa9a", "ccbea9", "ded1ba"],
    # The black streaks down the faces, where water runs off the rim.
    "streak": ["141317", "1d1b1f", "272428", "322e31", "3e393b", "4b4646", "5a5452", "6a6460"],
    # Diorite: the dark rock of El Capitan's North America Wall.
    "diorite": ["181a1c", "212426", "2b2f30", "363a3a", "424745", "4f5451", "5d625e"],
    # A fresh rockfall scar: cream granite not yet weathered.
    "fresh": ["8c8274", "a59a88", "bdb19c", "d2c6af", "e4d9c1", "f2e9d4"],
    # Wet rock beside a fall, and the moss that grows in its spray.
    "wet": ["121519", "191d22", "21272d", "2a3238", "343e44", "3f4a4f"],
    "moss": ["13221a", "1a2e20", "233b27", "2d4a2e", "385836", "44663d"],
    # Conifer forest on the benches and talus, and beyond the rim (bluer, in the haze).
    "forest": ["0b1611", "101e16", "16281b", "1d3221", "253e27", "2e4a2d", "385634", "43633b"],
    "far": ["1a2829", "213130", "2a3b38", "334540", "3d4f49", "485a52", "54655c"],
    # Forested ridges far back above the rim, pale in the afternoon haze.
    "haze": ["3a4c4d", "435556", "4d5f5e", "586966", "63736f", "6f7e78", "7b8981"],
    # The sky over the rim: deep blue overhead to a pale haze at the horizon.
    "sky": ["3a6f96", "4a80a5", "5c91b3", "70a1bf", "86b1ca", "9dc0d3", "b3cddb", "c7d9e2", "d8e4e8"],
    # Foothill grass cured gold in summer.
    "straw": ["4a3d26", "5e4d2f", "735f39", "887245", "9d8552", "b19860", "c3aa70"],
    # Black oak and brush on the talus and ledges: olive.
    "oak": ["162313", "1f2f19", "293c1f", "344926", "40572d", "4d6534", "5b733c"],
    "brush": ["1d2515", "28321b", "343f21", "414c28", "4f5a30", "5e6838", "6d7642"],
}
