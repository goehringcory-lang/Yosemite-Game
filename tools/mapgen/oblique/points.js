// The labeled places on the Yosemite Valley area map. "label" is the center of
// the sign on the finished picture (pixels), placed by hand so nothing overlaps.
// "stop" names the Valley shuttle stop at that spot (see scripts/objects/shuttle_stop.gd).
module.exports = {
  points: [
    // Cliffs, falls and peaks (slate ribbons)
    { id: 'half_dome', name: 'Half Dome', tier: 'landmark', osm: 'Half Dome', label: [421, 22], blurb: 'Rises about 4,800 feet above the Valley floor. Snake Dike climbs its southwest side.' },
    { id: 'yosemite_falls', name: 'Yosemite Falls', tier: 'fall', osm: 'Upper Yosemite Fall', label: [283, 12], blurb: 'Drops 2,425 feet in three parts. It roars in late spring and can dry to a trickle by late summer.' },
    { id: 'el_capitan', name: 'El Capitan', tier: 'landmark', osm: 'El Capitan', label: [123, 79], blurb: 'About 3,000 feet of granite. The Nose was first climbed in 1958, after 47 days spread over 18 months.' },
    { id: 'three_brothers', name: 'Three Brothers', tier: 'landmark', osm: 'Middle Brother', label: [194, 50], blurb: 'Three stacked summits on the north wall. The highest is Eagle Peak.' },
    { id: 'royal_arches', name: 'Royal Arches', tier: 'landmark', osm: 'Royal Arches', label: [338, 42], blurb: 'Great stone arches above the Ahwahnee. The classic route up them is 16 pitches long.' },
    { id: 'north_dome', name: 'North Dome', tier: 'landmark', osm: 'North Dome', label: [382, 9], blurb: 'A granite dome on the north rim, looking across at Half Dome.' },
    { id: 'sentinel_rock', name: 'Sentinel Rock', tier: 'landmark', osm: 'Sentinel Rock', label: [250, 134], blurb: 'A great spire on the south wall, about 3,000 feet above the floor.' },
    { id: 'glacier_point', name: 'Glacier Point', tier: 'landmark', osm: 'Glacier Point', label: [318, 137], blurb: '7,214 feet. The Valley floor is 3,200 feet below. The Apron climb leads up to it.' },
    { id: 'cathedral_rocks', name: 'Cathedral Rocks', tier: 'landmark', osm: 'Middle Cathedral Rock', label: [139, 190], blurb: 'Great buttresses on the south wall, beside Bridalveil Fall.' },
    { id: 'vernal_fall', name: 'Vernal Fall', tier: 'fall', osm: 'Vernal Fall', label: [398, 154], blurb: 'The Merced drops about 317 feet here, above Happy Isles.' },
    { id: 'nevada_fall', name: 'Nevada Fall', tier: 'fall', osm: 'Nevada Fall', label: [436, 170], blurb: 'The Merced drops about 594 feet, next to Liberty Cap.' },
    { id: 'bridalveil_fall', name: 'Bridalveil Fall', tier: 'fall', osm: 'Bridalveil Fall', label: [68, 176], blurb: 'Drops 620 feet and flows all year. On windy days its spray blows sideways.' },
    // Places (parchment signs)
    { id: 'yosemite_village', name: 'Yosemite Village', tier: 'place', osm: 'Yosemite Village', label: [300, 60], stop: 'Yosemite Village', blurb: 'The Welcome Center, store and museum. Camp 4 is a short walk west.' },
    { id: 'lower_yosemite_fall', name: 'Lower Yosemite Fall', tier: 'place', osm: 'Lower Yosemite Falls Vista Point', label: [218, 68], blurb: 'Lower Fall drops 320 feet. Above it are the middle cascades and Upper Fall.' },
    { id: 'camp_4', name: 'Camp 4', tier: 'place', osm: 'Camp 4', label: [204, 96], stop: 'Camp 4', blurb: 'Climbers have camped here since the 1950s. It joined the National Register in 2003.' },
    { id: 'cooks_meadow', name: "Cook's Meadow", tier: 'place', osm: "Cook's Meadow", label: [258, 103], blurb: 'Open meadow under Yosemite Falls, good for foraging in season.' },
    { id: 'ahwahnee', name: 'The Ahwahnee', tier: 'place', osm: 'Ahwahnee Hotel', label: [338, 80], stop: 'The Ahwahnee', blurb: 'Opened in 1927. Stone and concrete stained to look like redwood keep fire out.' },
    { id: 'curry_village', name: 'Curry Village', tier: 'place', osm: 'Curry Village', label: [290, 121], stop: 'Curry Village', blurb: 'David and Jennie Curry opened Camp Curry here in 1899 with just seven tents.' },
    { id: 'lamon_homestead', name: 'Lamon Homestead', tier: 'home', at: [-119.5672, 37.7352], label: [366, 121], stop: 'Lamon Homestead (Curry orchard)', blurb: 'Your camp, beside what is left of James Lamon’s 1860s apple orchard.' },
    { id: 'happy_isles', name: 'Happy Isles', tier: 'place', osm: 'Happy Isles Trailhead', label: [382, 140], stop: 'Happy Isles', blurb: 'The John Muir Trail starts here, about 211 miles from Mount Whitney.' },
    { id: 'mirror_lake', name: 'Mirror Lake', tier: 'place', osm: 'Mirror Lake', label: [398, 60], stop: 'Mirror Lake Trailhead', blurb: 'Tenaya Creek forms a seasonal lake below Half Dome. By late summer it is often a meadow.' },
    { id: 'el_capitan_meadow', name: 'El Capitan Meadow', tier: 'place', osm: 'El Capitan Meadow', label: [152, 176], stop: 'El Capitan Meadow', blurb: 'Open meadow at the foot of El Capitan, where climbers scan the wall.' },
    { id: 'tunnel_view', name: 'Tunnel View', tier: 'place', osm: 'Tunnel View', label: [28, 200], blurb: 'El Capitan on the left, Bridalveil Fall on the right, Half Dome beyond.' },
  ],
  // Map kiosks (see the "travel" list in tools/mapgen/hub_content.gd).
  kiosks: [
    { name: 'Yosemite Village Parking', osm: 'Day Use Parking' },
    { name: 'Curry Village Parking', osm: 'Half Dome Village Registration Parking' },
  ],
  // Route starts, from scenes/story/content/yosemite_valley.tscn. Position is the
  // ClimbStart's pixel position in the Valley hub (45 m per 16 px tile).
  climbs: [
    { route: 'glacier_point_apron', pos: [3336, 1036] },
    { route: 'royal_arches', pos: [3448, 568] },
    { route: 'snake_dike', pos: [3920, 1120] },
    { route: 'the_nose', pos: [1568, 1456] },
    { route: 'swan_slab', osm: 'Camp 4', dx: -6, dy: -3 },
  ],
};
