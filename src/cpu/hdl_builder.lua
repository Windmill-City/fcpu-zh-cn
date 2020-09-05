local assert = require('src/cpu/assert')
local io

assert.bind()

local builder = {}

-------------------------------------------------------------------------------------------------------

function builder.set_output(entity, output_fcpu)
  local state = Entity.get_data(entity) or {}
  state.output_fcpu = output_fcpu
  Entity.set_data(entity, state)
end

function builder.create_output(entity)
  local surf = entity.surface
  local output_fcpu = surf.create_entity({
    name = "output-fcpu",
    position = { x = entity.position.x, y = entity.position.y },
    direction = entity.direction,
    force = entity.force
  })
  output_fcpu.destructible = false
  output_fcpu.operable = true
  Entity.set_data(output_fcpu, {fcpu = entity})
  return output_fcpu
end

function builder.destroy_output(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    builder.destroy_output(state.output_fcpu)
  elseif entity.name == "output-fcpu" then
    local output_fcpu = Entity.get_data(entity)
    if output_fcpu and output_fcpu.fcpu and output_fcpu.fcpu.valid then
      builder.set_output(output_fcpu.fcpu, nil)
    end
    debug_print("destroyed fcpu output")
    Entity.set_data(entity, nil)
    entity.destroy()
  elseif entity.name == "entity-ghost" and entity.ghost_name == "fcpu" then
    local output_fcpus = entity.surface.find_entities_filtered{name = "output-fcpu", position = { x = entity.position.x, y = entity.position.y }, force = entity.force, limit = 1}
    if #output_fcpus > 0 then
      builder.destroy_output(output_fcpus[1])
    end
  end
end

-------------------------------------------------------------------------------------------------------

function builder.create_node(entity, type)
  -- TODO: remove {
  local state = Entity.get_data(entity)
  state.i = (state.i or 0) % 30 + 1
  Entity.set_data(entity, state)
  local a = state.i * math.pi * 0.25
  local r = math.floor(state.i * 0.125) + 1.5
  local x = math.cos(a) * r
  local y = math.sin(a) * r
  -- }]]
  local surf = entity.surface
  local node_fcpu = surf.create_entity({
    name = type .."-fcpu",
    position = { x = entity.position.x + x, y = entity.position.y + y },
    direction = entity.direction,
    force = entity.force
  })
  node_fcpu.destructible = false
  node_fcpu.operable = true
  Entity.set_data(node_fcpu, {fcpu = entity})
  return node_fcpu
end

function builder.destroy_nodes(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    if state.program_ics then
      for _, v in ipairs(state.program_ics) do
        builder.destroy_ics(v)
      end
      state.program_ics = nil
    end
  elseif entity.name == "entity-ghost" and entity.ghost_name == "fcpu" then
    local node_fcpus = entity.surface.find_entities_filtered{name = {"decider-fcpu", "arithmetic-fcpu", "constant-fcpu"}, position = { x = entity.position.x, y = entity.position.y }, radius = 10, force = entity.force}
    for _, v in ipairs(node_fcpus) do
      local state_node = Entity.get_data(v)
      if state_node.fcpu == entity then
        builder.destroy_nodes(v)
      end
    end
  end
end

function builder.destroy_ics(entity)
  if type(entity) == 'table' and getmetatable(entity) ~= 'private' then
    for _, e in pairs(entity) do
      builder.destroy_ics(e)
    end
  elseif entity and (entity.name == "decider-fcpu" or entity.name == "arithmetic-fcpu" or entity.name == "constant-fcpu") then
    debug_print('destroyed fcpu '.. entity.name ..' node')
    Entity.set_data(entity, nil)
    entity.destroy()
  end
end

-------------------------------------------------------------------------------------------------------

function builder.validate_node(ics)
  if type(ics) == 'table' then
    for _, e in pairs(ics) do
      if e and not e.valid then
        return false
      end
    end
    return 0 < #ics
  end
end

-------------------------------------------------------------------------------------------------------

function builder.create_memory_cell(entity, input_ent, input_wire)
  local wire1 = (input_wire == defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green
  local wire2 = (input_wire ~= defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green

  local ctl = builder.create_node(entity, 'constant')
  local key = builder.create_node(entity, 'decider')
  local dst = builder.create_node(entity, 'decider')

  local control_ctl = ctl.get_or_create_control_behavior()
  local control_key = key.get_or_create_control_behavior()
  local control_dst = dst.get_or_create_control_behavior()

  ctl.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.constant_combinator,
    wire = wire2,
    target_entity = key,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })
  ctl.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.constant_combinator,
    wire = wire1,
    target_entity = dst,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })
  control_ctl.enabled = false
  control_ctl.set_signal(1, {
    signal = {type='virtual', name='signal-fcpu-error'},
    count = 1
  })

  key.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    wire = wire1,
    target_entity = input_ent,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })
  control_key.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-fcpu-error'},
      second_signal = nil,
      constant = 1,
      comparator = "=",
      output_signal = {type='virtual', name='signal-everything'},
      copy_count_from_input = true
    }
  }

  dst.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    wire = wire2,
    target_entity = dst,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })
  dst.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    wire = wire1,
    target_entity = key,
    target_circuit_id = defines.circuit_connector_id.combinator_output
  })
  control_dst.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-fcpu-error'},
      second_signal = nil,
      constant = 1,
      comparator = "≤", -- ≥",
      output_signal = {type='virtual', name='signal-everything'},
      copy_count_from_input = true
    }
  }

  return {
    ctrl = ctl,
    key,
    out = dst
  }
end

-------------------------------------------------------------------------------------------------------

local ops = {
  xmov = function(state, _)
    assert.two(_)
    assert.is_memory(_[1], _[2])

    local dst_name = _[1].location .. _[1].addr

    local color, src
    if _[2].type == 'wire' then
      color = _[2].color == 'red' and defines.wire_type.red or defines.wire_type.green
      src = state.entity
    else
      color = defines.wire_type.red
      src = io.get_node(dst_name)
    end
    local dst = builder.create_memory_cell(state.entity, src, color)
    io.set_node(dst_name, dst)

    return dst
  end,
}

function builder.construct(opname, expr, state)
  if ops and ops[opname] then
    return ops[opname](state, expr)
  end
end

function builder.bind(io_)
  io = io_
end
return builder
