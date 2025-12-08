local empty_picture = {
  filename = "__core__/graphics/empty.png",
  x = 0,
  y = 0,
  width = 1,
  height = 1,
  frame_count = 1,
  shift = {0, 0},
}


local function tune_for_compaktcircuit(packed_entity)
  local wire_conn = { wire = { red = { 0, 0 }, green = { 0, 0 } }, shadow = { red = { 0, 0 }, green = { 0, 0 } } }
  packed_entity.flags = { 'placeable-off-grid' , "hide-alt-info", "not-on-map", "not-upgradable", "not-deconstructable", "not-blueprintable" }
  packed_entity.collision_mask = { layers={} }
  packed_entity.collision_box = {{-0.0001,-0.0001},{0.0001,0.0001}}
  packed_entity.selection_box = {{-0.01,-0.01},{0.01,0.01}}
  packed_entity.minable = nil
  packed_entity.selectable_in_game = false
  packed_entity.circuit_wire_max_distance = 64
  packed_entity.sprites = empty_picture
  packed_entity.activity_led_sprites = empty_picture
  packed_entity.activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
  packed_entity.circuit_wire_connection_points = { wire_conn, wire_conn, wire_conn, wire_conn }
  packed_entity.draw_circuit_wires = false
  packed_entity.created_smoke = nil
  packed_entity.localised_name = { 'entity-name.'.. packed_entity.name }
  packed_entity.localised_description = { 'entity-description.'.. packed_entity.name }
end

local fcpu = data.raw['arithmetic-combinator']['fcpu']

if MC_DEBUG then
  fcpu.collision_box = {{-0.65, -0.65}, {0.65, 1.65}}
  fcpu.selection_box = {{-1, -1}, {1, 2}}
end

local packed_entity = table.deepcopy(fcpu)
tune_for_compaktcircuit(packed_entity)
packed_entity.name = 'fcpu-packed'
packed_entity.circuit_wire_max_distance = 10000

data:extend { packed_entity }
