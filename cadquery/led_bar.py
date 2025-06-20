import cadquery as cq

board_width = 60.0
board_height = 40.0
board_thickness = 1.6
led_opening_width = 26.0
led_opening_height = 6.0

wall_thickness = 1.5
standoff_diameter = 2.0
standoff_height = board_thickness + 6  # Slightly taller than board

# Enclosure internal dimensions
inner_width = board_width + 1  # Clearance around board
inner_height = board_height + 1
inner_depth = board_thickness + 6

# Total outer dimensions
outer_width = inner_width + wall_thickness * 2
outer_height = inner_height + wall_thickness * 2
outer_depth = inner_depth + wall_thickness

# Size of the rectangular cutout (5-hole width)
header_hole_width = 14  # 4 * 2.54 mm spacing
header_hole_height = 3  # one row tall
header_hole_depth = standoff_height + 2  # make it deeper than standoffs

# Position: center of the top row of the perfboard
hole_x = -1  # centered left to right
hole_y = (inner_height / 2) - 4  # top edge of the perfboard inside

# === Create base with cutout ===
base = (
    cq.Workplane("XY")
    .box(outer_width, outer_height, outer_depth)
    .faces(">Z").workplane()
    .rect(inner_width, inner_height)
    .cutBlind(-inner_depth)
)

# === Create standoffs in one pass ===
standoff_offset_x = (inner_width / 2) - 2.5
standoff_offset_y = (inner_height / 2) - 2.5

standoff_locations = [
    ( standoff_offset_x,  standoff_offset_y),
    (-standoff_offset_x,  standoff_offset_y),
    ( standoff_offset_x, -standoff_offset_y),
    (-standoff_offset_x, -standoff_offset_y),
]

# Add the mounting pegs
base = (
    base.faces(">Z")
    .workplane()
    .transformed(offset=(0, 0, -inner_depth))  # move into the cavity
    .pushPoints(standoff_locations)
    .circle(standoff_diameter / 2)
    .extrude(standoff_height)
)

# Cut a hole in the base for the header pins
base = (
    base.faces(">Z")
    .workplane()
    .transformed(offset=(0, 0, -inner_depth))  # workplane at floor of cavity
    .center(hole_x, hole_y)
    .rect(header_hole_width, header_hole_height)
    .cutBlind(-header_hole_depth)  # cut downward from cavity floor
)

show_object(base)
