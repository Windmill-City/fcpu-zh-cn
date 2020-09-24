local assert = require('src/cpu/assert')
local state

assert.bind()

local builder = {}

-------------------------------------------------------------------------------------------------------
local function inverse_wire_color(color)
  return (color ~= defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green
end

local function get_debug_offset(entity, d_next_node)
  local x = 0
  local y = 0
  if MC_DEBUG then
    local state = Entity.get_data(entity)
    if MC_DEBUG == true then
      if d_next_node == true then
        state.d_i = 1
        state.d_j = (state.d_j or 0) + 1
      elseif state.d_j == nil or d_next_node == false or type(d_next_node) == 'number' then
        state.d_i = d_next_node or 1
        state.d_j = 0
      else
        state.d_i = (state.d_i or 0) + 1
      end
      x = state.d_i * 2
      y = state.d_j * 2
    else
      state.d_i = (state.d_i or 0) % 30 + 1
      local c = math.floor((state.d_i - 1) * 0.125)
      local r = (c + 1) * 1.5
      local a = (state.d_i - 1) * math.pi * 0.25 * (c == 2 and 0.5 or 1)
      x = math.cos(a) * r
      y = math.sin(a) * r
    end
    Entity.set_data(entity, state)
  end
  return x, y
end

function builder.create_node(entity, type, debug_next_node)
  local x, y = get_debug_offset(entity, debug_next_node)
  local surf = entity.surface
  local node_fcpu = surf.create_entity({
    name = type .."-fcpu",
    position = { x = entity.position.x + x, y = entity.position.y + y },
    direction = defines.direction.south,
    force = entity.force
  })
  node_fcpu.destructible = false
  node_fcpu.operable = true
  Entity.set_data(node_fcpu, {fcpu = entity})
  return node_fcpu, node_fcpu.get_or_create_control_behavior()
end

function builder.destroy_nodes(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    if state.program_ics then
      for _, v in pairs(state.program_ics) do
        builder.destroy_ics(v)
      end
      state.program_ics = {}
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
    elseif entity.valid and (entity.name == "decider-fcpu" or entity.name == "arithmetic-fcpu" or entity.name == "constant-fcpu" or entity.name == "output-fcpu") then
      debug_print('destroyed fcpu '.. entity.name ..' ic')
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

function builder.create_memory_cell(entity, input_ent, input_color, input_port, proxy_output)
  local wire1 = input_color
  local wire2 = inverse_wire_color(input_color)

  local d_key, control_key = builder.create_node(entity, 'decider', true)
  local c_in, control_in = builder.create_node(entity, 'constant')
  local c_fix, control_fix = builder.create_node(entity, 'constant')
  local d_out, control_out = builder.create_node(entity, 'decider')

  control_in.enabled = false
  control_in.set_signal(1, {
    signal = {type='virtual', name='signal-fcpu-error'},
    count = 1
  })

  control_fix.enabled = false
  control_fix.set_signal(1, {
    signal = {type='virtual', name='signal-fcpu-error'},
    count = -1
  })

  control_key.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-fcpu-error'},
      second_signal = nil,
      constant = 1,
      comparator = "=", -- < ≤ ≠ = ≥ >
      output_signal = {type='virtual', name='signal-everything'},
      copy_count_from_input = true
    }
  }

  control_out.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-fcpu-error'},
      second_signal = nil,
      constant = 0,
      comparator = "=", -- < ≤ ≠ = ≥ >
      output_signal = {type='virtual', name='signal-everything'},
      copy_count_from_input = true
    }
  }


  d_key.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = input_ent,
    target_circuit_id = input_port,
    wire = wire1,
  }
  d_key.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = d_out,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    wire = wire1,
  }
  c_in.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.constant_combinator,
    target_entity = d_key,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    wire = wire2,
  }
  c_fix.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.constant_combinator,
    target_entity = d_key,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    wire = wire1,
  }
  d_out.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = d_out,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    wire = wire2,
  }

  local ics = {
    color_out = wire1,
    d_key,
    ctrl = c_in,
    fix = c_fix,
    out = d_out,
  }

  if proxy_output then
    local proxy, control_proxy = builder.create_node(entity, 'decider')

    control_proxy.parameters = {
      parameters = {
        first_signal = {type='virtual', name='signal-fcpu-error'},
        second_signal = nil,
        constant = 0,
        comparator = "=",
        output_signal = {type='virtual', name='signal-everything'},
        copy_count_from_input = true
      }
    }

    ics.out.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      wire = wire1,
      target_entity = proxy,
      target_circuit_id = defines.circuit_connector_id.combinator_input,
    }

    ics[#ics + 1] = ics.out
    ics.out = proxy
  end

  return ics
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

  local ics = builder.create_memory_cell(entity, input_ent_a, input_wire, defines.circuit_connector_id.combinator_output)
  local dst, control_dst = builder.create_node(entity, 'arithmetic')

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

  dst.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = ics.out,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    wire = ics.color_out,
  }
  if input_ent_b ~= nil and constant == nil then
    control_dst.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_input,
      target_entity = input_ent_b,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      wire = inverse_wire_color(ics.color_out),
    }
  end

  ics[#ics + 1] = ics.out
  ics.out = dst
  return ics
end

-------------------------------------------------------------------------------------------------------

function builder.get_node(state_, name)
  -- same as io.get_node
  return state_.program_ics[name] or state_.program_ics[state_.ics_stack[name]]
end

function builder.set_ics(name, index)
  -- same as io.set_ics
  state.ics_stack[name] = index
end

-------------------------------------------------------------------------------------------------------

local function vector_scalar_op(operation, check)
  return function(state, _)
    assert.is_memory(_[1])

    local src, color
    if _[1].type == 'memory' then
      --local mem_ics = builder.get_node(state, _[1].location .. _[1].index)
      local mem_ics = state.program_ics[_[1].location .. _[1].index]
      src = mem_ics.out
      color = defines.wire_type.red
    else
      assert.todo()
    end

    local ics = builder.create_math_cell(state.entity, src, nil, operation, color or defines.wire_type.red)

    local ics_name
    if _[1].type == 'memory' then
      ics_name = _[1].location .. _[1].index
      local mem_ics = state.program_ics[ics_name]
      mem_ics.out.connect_neighbour({
        source_circuit_id = defines.circuit_connector_id.combinator_input,
        wire = ics.color_out,
        target_entity = ics.out,
        target_circuit_id = defines.circuit_connector_id.combinator_output
      })
    else
      assert.todo()
    end

    local deffer = {
      {action='enable', ic=ics.ctrl, delay = 0},
      {action='enable', ic=ics.fix, delay = 0},
      {action='disable', ic=ics.ctrl, delay = 1},
      {action='disable', ic=ics.fix, delay = 2},
      {action='noop', delay = 4},
    }

    return ics_name, ics, deffer
  end
end

-------------------------------------------------------------------------------------------------------

local ops = {
  xmov = function(state, _)
    assert.two(_)
    assert.type(_[1], {'memory', 'output'})
    assert.type(_[2], {'input', 'memory'})

    local wire_to = (_[1].type == 'wire')
    local wire_in = (_[2].type == 'wire')

    local src, color, port
    if wire_in then
      src = state.entity
      color = _[2].color == 'red' and defines.wire_type.red or defines.wire_type.green
      port = defines.circuit_connector_id.combinator_input
    elseif _[2].type == 'memory' then
      --local ics = builder.get_node(state, _[2].location .. _[2].index)
      local mem_ics = state.program_ics[_[2].location .. _[2].index]
      src = mem_ics.out
      color = defines.wire_type.red
      port = defines.circuit_connector_id.combinator_output
    else
      assert.todo()
    end

    local ics = builder.create_memory_cell(state.entity, src, color, port, wire_to)

    local ics_name
    if wire_to then
      ics.out.connect_neighbour({
        source_circuit_id = defines.circuit_connector_id.combinator_output,
        wire = defines.wire_type.red,
        target_entity = state.program_ics.output,
        target_circuit_id = defines.circuit_connector_id.constant_combinator
      })
      ics.out.connect_neighbour({
        source_circuit_id = defines.circuit_connector_id.combinator_output,
        wire = defines.wire_type.green,
        target_entity = state.program_ics.output,
        target_circuit_id = defines.circuit_connector_id.constant_combinator
      })
      ics_name = 'output'
    elseif _[1].type == 'memory' then
      ics_name = _[1].location .. _[1].index
      local mem_ics = state.program_ics[ics_name]
      mem_ics.out.connect_neighbour({
        source_circuit_id = defines.circuit_connector_id.combinator_input,
        wire = ics.color_out,
        target_entity = ics.out,
        target_circuit_id = defines.circuit_connector_id.combinator_output
      })
    else
      assert.todo()
    end

    local deffer = {
      {action='enable', ic=ics.ctrl, delay = 0},
      {action='enable', ic=ics.fix, delay = 0},
      {action='disable', ic=ics.ctrl, delay = 1},
      {action='disable', ic=ics.fix, delay = 2},
      {action='noop', delay = wire_to and 5 or 4},
    }

    return ics_name, ics, deffer
  end,

  xadd = vector_scalar_op('+'),
  xsub = vector_scalar_op('-'),
  xmul = vector_scalar_op('*'),
  xdiv = vector_scalar_op('/'),
  xmod = vector_scalar_op('%'),
  xpow = vector_scalar_op('^'),
  xinc = vector_scalar_op('+'),
  xdec = vector_scalar_op('-'),

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
