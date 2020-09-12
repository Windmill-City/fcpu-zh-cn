local assert = require('src/cpu/assert')
local state

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
  local c = math.floor((state.i - 1) * 0.125)
  local r = (c + 1) * 1.5
  local a = (state.i - 1) * math.pi * 0.25 * (c == 2 and 0.5 or 1)
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
  if type(entity) == 'table' then
    if getmetatable(entity) ~= 'private' then
      for _, e in pairs(entity) do
        builder.destroy_ics(e)
      end
    elseif entity.valid and (entity.name == "decider-fcpu" or entity.name == "arithmetic-fcpu" or entity.name == "constant-fcpu") then
      debug_print('destroyed fcpu '.. entity.name ..' node')
      Entity.set_data(entity, nil)
      entity.destroy()
    end
  end
end

-------------------------------------------------------------------------------------------------------

function builder.validate_ics(ics)
  if type(ics) == 'table' then
    local cnt = 0
    for _, e in pairs(ics) do
      if type(e) == 'table' then
        cnt = cnt + 1
        if not e.valid then
          return false
        end
      end
    end
    return 0 < cnt
  end
end

-------------------------------------------------------------------------------------------------------

function builder.create_memory_cell(entity, input_ent, input_wire)
  local wire1 = (input_wire == defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green
  local wire2 = (input_wire ~= defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green

  local fix = builder.create_node(entity, 'constant')
  local ctl = builder.create_node(entity, 'constant')
  local key = builder.create_node(entity, 'decider')
  local dst = builder.create_node(entity, 'decider')

  local control_fix = fix.get_or_create_control_behavior()
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

  dst.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    wire = wire1,
    target_entity = fix,
    target_circuit_id = defines.circuit_connector_id.constant_combinator
  })
  control_fix.enabled = false
  control_fix.set_signal(1, {
    signal = {type='virtual', name='signal-fcpu-error'},
    count = -1
  })

  return {
    color_out = wire1,
    ctrl = ctl,
    fix = fix,
    key,
    out = dst
  }
end


function builder.create_math_cell(entity, input_ent_a, input_ent_b, operation, input_wire)
  local constant
  if input_ent_b then
    if type(input_ent_b) == 'number' then
      constant = input_ent_b
    else
      assert.todo()
    end
  end

  local wire_a = (input_wire == defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green
  local wire_b = (input_wire ~= defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green

  local dst = builder.create_node(entity, 'arithmetic')
  local control_dst = dst.get_or_create_control_behavior()

  input_ent_a.connect_neighbour({
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    wire = wire_a,
    target_entity = dst,
    target_circuit_id = defines.circuit_connector_id.combinator_input
  })
  if input_ent_b ~= nil and constant == nil then
    input_ent_b.connect_neighbour({
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      wire = wire_b,
      target_entity = dst,
      target_circuit_id = defines.circuit_connector_id.combinator_input
    })
  end
  control_dst.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      first_constant  = nil,
      second_constant = constant,
      operation  = operation,
      output_signal = {type='virtual', name='signal-each'}
    }
  }

  return {
    color_out = wire_a,
    out = dst
  }
end

-------------------------------------------------------------------------------------------------------

function builder.get_node(state_, name)
  return state_.program_ics[state_.ics_stack[name]]
end

function builder.set_ics(name, index)
  -- same as io.set_ics
  state.ics_stack = state.ics_stack or {}
  state.ics_stack[name] = index
end

-------------------------------------------------------------------------------------------------------

local function vector_op(operation)
  return function(state, _)
    assert.one(_)
    assert.is_memory(_[1])

    local dst_name = _[1].location .. _[1].index

    local ics = builder.get_node(state, dst_name)
    if ics then
      local dst = builder.create_math_cell(state.entity, ics.out, nil, operation, ics.color_out)

      return dst_name, dst
    end
  end
end

local function vector_scalar_op(operation)
  return function(state, _)
    assert.two(_)
    assert.is_memory(_[1])
    assert.type(_[2], {'value', 'register', 'input'})

    local dst_name = _[1].location .. _[1].index

    local ics = builder.get_node(state, dst_name)
    if ics then
      local dst = builder.create_math_cell(state.entity, ics.out, nil, operation, ics.color_out)

      return dst_name, dst
    end
  end
end

-------------------------------------------------------------------------------------------------------

local ops = {
  xmov = function(state, _)
    assert.two(_)
    assert.type(_[1], {'memory', 'output'})
    assert.type(_[2], {'input', 'memory'})

    local color, src
    if _[2].type == 'wire' then
      color = _[2].color == 'red' and defines.wire_type.red or defines.wire_type.green
      src = state.entity
    elseif _[2].type == 'memory' then
      color = defines.wire_type.red
      src = builder.get_node(state, _[2].location .. _[2].index)
      src = src.out
    else
      assert.todo()
    end

    local dst = builder.create_memory_cell(state.entity, src, color)

    local dst_name
    if _[1].type == 'wire' then
      dst.out.connect_neighbour({
        source_circuit_id = defines.circuit_connector_id.combinator_output,
        wire = defines.wire_type.red,
        target_entity = state.entity,
        target_circuit_id = defines.circuit_connector_id.combinator_output
      })
    elseif _[1].type == 'memory' then
      dst_name = _[1].location .. _[1].index
    else
      assert.todo()
    end

    return dst_name, dst
  end,

  xadd = vector_scalar_op('+'),
  xsub = vector_scalar_op('-'),
  xmul = vector_scalar_op('*'),
  xdiv = vector_scalar_op('/'),
  xmod = vector_scalar_op('%'),
  xpow = vector_scalar_op('^'),
  xinc = vector_op('+'),
  xdec = vector_op('-'),

  xand = vector_scalar_op('AND'),
  xor  = vector_scalar_op('OR'),
  xxor = vector_scalar_op('XOR'),
  xsl  = vector_scalar_op('<<'),
  xsr  = vector_scalar_op('>>'),
}

function builder.construct(ast, state_)
  state = state_

  if ops and ops[ast.name] then
    return ops[ast.name](state, ast.expr)
  end
end


function builder.bind()
end
return builder
