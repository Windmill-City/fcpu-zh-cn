local assert = require('src/cpu/assert')

assert.bind()

local Builder = {}

-------------------------------------------------------------------------------------------------------

function Builder.set_output(entity, output_fcpu)
  local state = Entity.get_data(entity) or {}
  state.output_fcpu = output_fcpu
  Entity.set_data(entity, state)
end

function Builder.create_output(entity)
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

function Builder.destroy_output(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    Builder.destroy_output(state.output_fcpu)
  elseif entity.name == "output-fcpu" then
    local output_fcpu = Entity.get_data(entity)
    if output_fcpu and output_fcpu.fcpu and output_fcpu.fcpu.valid then
      Builder.set_output(output_fcpu.fcpu, nil)
    end
    debug_print("destroyed fcpu output")
    Entity.set_data(entity, nil)
    entity.destroy()
  elseif entity.name == "entity-ghost" and entity.ghost_name == "fcpu" then
    local output_fcpus = entity.surface.find_entities_filtered{name = "output-fcpu", position = { x = entity.position.x, y = entity.position.y }, force = entity.force, limit = 1}
    if #output_fcpus > 0 then
      Builder.destroy_output(output_fcpus[1])
    end
  end
end

-------------------------------------------------------------------------------------------------------

function Builder.create_node(entity, type)
  local surf = entity.surface
  local node_fcpu = surf.create_entity({
    name = type .."-fcpu",
    position = { x = entity.position.x + 1.5, y = entity.position.y },
    direction = entity.direction,
    force = entity.force
  })
  node_fcpu.destructible = false
  node_fcpu.operable = true
  Entity.set_data(node_fcpu, {fcpu = entity})
  return node_fcpu
end

function Builder.destroy_node(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    if state.program_ics then
      for _, v in ipairs(state.program_ics) do
        Builder.destroy_node(v)
      end
      state.program_ics = {}
    end
  elseif entity.name == "decider-fcpu" or entity.name == "arithmetic-fcpu" then
    debug_print('destroyed fcpu '.. entity.name ..' node')
    Entity.set_data(entity, nil)
    entity.destroy()
  elseif entity.name == "entity-ghost" and entity.ghost_name == "fcpu" then
    local node_fcpus = entity.surface.find_entities_filtered{name = {"decider-fcpu", "arithmetic-fcpu"}, position = { x = entity.position.x + 1.5, y = entity.position.y }, force = entity.force}
    for _, v in ipairs(node_fcpus) do
      Builder.destroy_node(v)
    end
  end
end

function Builder.get_node(state, name)
  if state and state.ics_stack and state.ics_stack[name] then
    return state.ics_stack[name]
  end
end

function Builder.set_node(state, name, ent)
  if state and state.ics_stack then
    assert.check(state.ics_stack[name] == nil)
    state.ics_stack[name] = ent
  end
end

-------------------------------------------------------------------------------------------------------

function Builder.create_memory_cell(entity, input_ent, input_wire)
  local dst = Builder.create_node(entity, 'decider')

  local control = dst.get_or_create_control_behavior()
  control.parameters = {
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
    wire = defines.wire_type.green,
    target_entity = dst,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })
  dst.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    wire = input_wire,
    target_entity = input_ent,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })

  return dst
end

-------------------------------------------------------------------------------------------------------

local ops = {
  xmov = function(state, _)
    assert.two(_)
    assert.is_memory(_[1], _[2])

    local dst_name = _[1].location .. _[1].addr

    local dst = Builder.get_node(state, dst_name)
    if not dst then
      dst = Builder.create_memory_cell(state.entity, state.entity, defines.wire_type.red)
      Builder.set_node(state, dst_name, dst)
    end

    return dst
  end,
}

function Builder.construct(opname, expr, state)
  if ops and ops[opname] then
      return ops[opname](state, expr)
  end
end

return Builder
