local assert = require('src/cpu/assert')
local state

assert.bind()

local _destroy_on_error = {}
local builder = {}

-------------------------------------------------------------------------------------------------------
local function inverse_wire_color(color)
  return (color ~= defines.wire_type.red) and defines.wire_type.red or defines.wire_type.green
end

local function get_debug_offset(entity, d_next_node)
  local x = 0
  local y = 0
  if MC_DEBUG then
    local state = get_fcpu_state(entity)
    if state then
      if d_next_node == true then
        state.d_i = 0
        state.d_j = (state.d_j or 0) + 1
      elseif state.d_j == nil or d_next_node == false then
        state.d_i = d_next_node or 1
        state.d_j = 0
      elseif type(d_next_node) == 'number' then
        local i = math.floor(d_next_node)
        state.d_i = i or 1
        state.d_j = 0
        y = -(d_next_node - i) * 2
      else
        state.d_i = (((state.d_i / 2) or 0) + 1) * 2
      end
      x = state.d_i
      y = state.d_j * 2 + y
    end
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
    force = entity.force,
    create_build_effect_smoke = false
  })

  table.insert(_destroy_on_error, node_fcpu)

  node_fcpu.destructible = false
  node_fcpu.operable = true
  Entity.set_data(node_fcpu, {fcpu = entity})
  return node_fcpu, node_fcpu.get_or_create_control_behavior()
end

function builder.destroy_nodes(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = get_fcpu_state(entity)
    if state and state.program_ics then
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

function builder.verify(state)
  state.program_ics = state.program_ics or {}

  if not (state.program_ics.output and state.program_ics.output.valid) then
    local output_fcpu = builder.create_node(state.entity, 'output', false)
    state.program_ics.output = output_fcpu

    state.entity.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_entity = output_fcpu,
      wire = defines.wire_type.green,
    }
    state.entity.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_entity = output_fcpu,
      wire = defines.wire_type.red,
    }
  end

  for i = 1, MC_MEMORY_CHANNELS  do
    local ics_name = 'mem'..i
    state.program_ics[ics_name] = state.program_ics[ics_name] or {}

    if not (state.program_ics[ics_name].out and state.program_ics[ics_name].out.valid) then
      local ent_mem, ctrl_mem = builder.create_node(state.entity, 'decider', i * 2)

      state.program_ics[ics_name].out = ent_mem

      ctrl_mem.parameters = {
        parameters = {
          first_signal = {type='virtual', name='signal-fcpu-error'},
          second_signal = nil,
          constant = 0,
          comparator = "=",
          output_signal = {type='virtual', name='signal-everything'},
          copy_count_from_input = true
        }
      }
    end

    if not (state.program_ics[ics_name].value and state.program_ics[ics_name].value.valid) then
      local ent_val1, ctrl_val1 = builder.create_node(state.entity, 'output', i * 2 + 1)

      state.program_ics[ics_name].value = ent_val1
      ctrl_val1.enabled = false

      ent_val1.connect_neighbour{
        source_circuit_id = defines.circuit_connector_id.constant_combinator,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        target_entity = state.program_ics[ics_name].out,
        wire = defines.wire_type.green,
      }
      ent_val1.connect_neighbour{
        source_circuit_id = defines.circuit_connector_id.constant_combinator,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        target_entity = state.program_ics[ics_name].out,
        wire = defines.wire_type.red,
      }
    end

    if not (state.program_ics[ics_name].value2 and state.program_ics[ics_name].value2.valid) then
      local ent_val2, ctrl_val2 = builder.create_node(state.entity, 'output', i * 2 + 1.5)

      state.program_ics[ics_name].value2 = ent_val2
      ctrl_val2.enabled = false

      ent_val2.connect_neighbour{
        source_circuit_id = defines.circuit_connector_id.constant_combinator,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        target_entity = state.program_ics[ics_name].out,
        wire = defines.wire_type.green,
      }
      ent_val2.connect_neighbour{
        source_circuit_id = defines.circuit_connector_id.constant_combinator,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        target_entity = state.program_ics[ics_name].out,
        wire = defines.wire_type.red,
      }
    end
  end
end

-------------------------------------------------------------------------------------------------------

function builder.create_merger_cell(entity, input_a, input_b)
  local wire1 = input_a.wire or inverse_wire_color(input_b.wire) or defines.wire_type.red
  local wire2 = inverse_wire_color(wire1)

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

  proxy.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = input_a.port,
    target_entity = input_a.entity,
    wire = wire1,
  }
  proxy.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = input_b.port,
    target_entity = input_b.entity,
    wire = wire2,
  }

  return proxy
end

function builder.create_filter_cell(entity, input_src, input_msk)
  --[[ blueprint!
  0eNrtmE2PmzAQhv+Ljy1ZYb6D2kOlnnvtoVohByYbq2AjY7JFEf+9NrSEZUmC02ibw14imdiPh3nnHQMHtMlrKAVlEsUHRFPOKhT/OKCKPjGS62uyKQHFiEookIUYKfSICCp3BUiarlJebCgjkgvUWoiyDH6hGLfWRUYGKc1AzAOc9tFCwCSVFPqIukGTsLrYgFA7DBwdsyRMjkEWKnml1nKmt9cB2faDb6EGxatg/eCrjTIqIO1neJaGSMHzZAM7sqeKoJZtaS5BnMjHngpZqytDGP2MlYBM30bKa51SfCEjpyhPAoCNOCs8yowJSMs74jjYC73IDbxw4LlGvAbynD+PIxuQ0YD0jJDPO1UXczEGA9A3TV4zG+HxpgMjYNqQsRjYcQdQaAT6Pl8avqGkJP05D4rax+46Y31pVxqH9Y8uy5GLaNZXPRVpTWU3xGptqwOZGM0xNZr7brR3o92R0da2bV/rtZIyY6v1JTUxm7/MbO6FE3bGbniwW7jIbEdwov7O6BD8lopKJotTAyTd6dRUoDHJ3+YwKVRegiB9POijYvBalrXxLu0/dTULOSd1mUx3RprocbRMNs9cNvvuZMMv1frwFmrhSb5dM/XcqXrz8vjnnjnPnmDLtPlDvY0wR0VsPShKIro4Y/TpakU0qGySroslW8GLhDKFQfGW5BW0Jo1s6pDgpGIzcofL7BSY28m5NzuNz8Kxrb58+3pzYy09cU4Ls7DPhVcbyf+fRnpxIr2w1OfbW0qKGgw6oP+qhVnzekZmrTFa1hojQ0Wd+1D0DVqjoY7BUh3d808coZnM4Xna+oTs6yEZBWS0LlaQq3sUqs2WPIfzzyu4e6tb3IdmC1Elp/sYFI++P1lor14Cuz2dSBt2HQYhtgM/aNvfWERHHQ==
  ]]
  local wireS = input_src.wire or defines.wire_type.red
  local wireM = input_msk.wire or defines.wire_type.red

  local a1, control_a1 = builder.create_node(entity, 'arithmetic')
  local a2, control_a2 = builder.create_node(entity, 'arithmetic')
  local a3, control_a3 = builder.create_node(entity, 'arithmetic')
  local d1, control_d1 = builder.create_node(entity, 'decider')
  local d2, control_d2 = builder.create_node(entity, 'decider')
  local d3, control_d3 = builder.create_node(entity, 'decider')

  control_a1.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      first_constant  = nil,
      second_constant = -1,
      operation  = '*',
      output_signal = {type='virtual', name='signal-each'}
    }
  }
  control_a2.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      first_constant  = nil,
      second_constant = -2147483648,
      operation  = '+',
      output_signal = {type='virtual', name='signal-each'}
    }
  }
  control_a3.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      first_constant  = nil,
      second_constant = 2147483647,
      operation  = 'AND',
      output_signal = {type='virtual', name='signal-each'}
    }
  }

  control_d1.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      constant = 0,
      comparator = "<",
      output_signal = {type='virtual', name='signal-each'},
      copy_count_from_input = false
    }
  }
  control_d2.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      constant = 0,
      comparator = "<",
      output_signal = {type='virtual', name='signal-each'},
      copy_count_from_input = true
    }
  }
  control_d3.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = nil,
      constant = -2147483648,
      comparator = "=",
      output_signal = {type='virtual', name='signal-each'},
      copy_count_from_input = true
    }
  }

  a1.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = input_src.port,
    target_entity = input_src.entity,
    wire = wireM,
  }
  a2.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = a1,
    wire = wireM,
  }
  a2.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = a1,
    wire = defines.wire_type.green,
  }

  a3.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d1,
    wire = wireS,
  }
  d1.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = input_msk.port,
    target_entity = input_msk.entity,
    wire = wireS,
  }
  d1.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d3,
    wire = defines.wire_type.red,
  }

  a2.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d2,
    wire = defines.wire_type.green,
  }
  a3.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d2,
    wire = defines.wire_type.red,
  }

  --[[ Tie outputs for each color ]]
  d2.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d3,
    wire = defines.wire_type.green,
  }
  d2.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = d3,
    wire = defines.wire_type.green,
  }
  d2.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = d3,
    wire = defines.wire_type.red,
  }

  return d3
end

function builder.create_memory_cell(entity, input_a, input_b)
  local wire1 = input_a.wire or defines.wire_type.red
  local wire2 = inverse_wire_color(wire1)

  local d_key, control_key = builder.create_node(entity, 'decider')
  local c_clr, control_clr = builder.create_node(entity, 'constant')
  local d_out, control_out = builder.create_node(entity, 'decider')

  control_clr.enabled = false
  control_clr.set_signal(1, {
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
    target_circuit_id = input_a.port,
    target_entity = input_a.entity,
    wire = wire1,
  }
  d_key.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d_out,
    wire = wire1,
  }
  c_clr.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.constant_combinator,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = d_key,
    wire = wire1,
  }
  d_out.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d_out,
    wire = wire2,
  }

  local ics = {
    color_out = wire1,
    kin = d_key,
    clr = c_clr,
    kout = d_out,
    out = d_out,
  }

  if input_b ~= nil then
    local isTable = (type(input_b) == 'table')
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

    proxy.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_input,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      target_entity = ics.out,
      wire = inverse_wire_color(isTable and input_b.wire),
    }

    if isTable and input_b.entity then
      proxy.connect_neighbour{
        source_circuit_id = defines.circuit_connector_id.combinator_input,
        target_circuit_id = input_b.port,
        target_entity = input_b.entity,
        wire = input_b.wire or defines.wire_type.red,
      }
    end

    ics[#ics + 1] = ics.out
    ics.out = proxy
  end

  return ics
end


function builder.create_arithmetic_cell(entity, input_a, input_b, operation)
  local constant
  if input_b then
    if type(input_b) == 'number' then
      constant = input_b
    else
      assert.todo()
    end
  end

  local ics = builder.create_memory_cell(entity, input_a)
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
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    target_entity = ics.out,
    wire = ics.color_out,
  }
  if input_b ~= nil and constant == nil then
    control_dst.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_input,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      target_entity = input_b,
      wire = inverse_wire_color(ics.color_out),
    }
  end

  ics[#ics + 1] = ics.out
  ics.out = dst
  return ics
end


function builder.create_decider_cell(entity, input_a, input_b, operation)
  local ics = builder.create_memory_cell(entity, input_a)
  local dst, control_dst = builder.create_node(entity, 'decider')

  control_dst.parameters = {
    parameters = {
      first_signal = {type='virtual', name='signal-each'},
      second_signal = input_b.signal,
      constant = input_b.count,
      comparator = operation,
      output_signal = {type='virtual', name='signal-each'},
      copy_count_from_input = true
    }
  }

  dst.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = ics.out,
    target_circuit_id = defines.circuit_connector_id.combinator_output,
    wire = ics.color_out,
  }

  ics[#ics + 1] = ics.out
  ics.out = dst
  return ics
end

-------------------------------------------------------------------------------------------------------

function builder.get_node(state_, name)
  -- same as io.get_node
  return state_.program_ics[name] or state_.program_ics[state_.ics_stack[name]]
end

-------------------------------------------------------------------------------------------------------

local function connect_input_from(state, arg)
  assert.is_memory_readable(arg)
  if arg.type == 'memory' then
    local ics_name = arg.location .. arg.index
    local mem_ics = state.program_ics[ics_name]
    return {
      entity = mem_ics.out,
      wire = defines.wire_type.red,
      port = defines.circuit_connector_id.combinator_output
    }
  elseif arg.type == 'wire' then
    return {
      entity = state.entity,
      wire = defines.wire_type[arg.color],
      port = defines.circuit_connector_id.combinator_input
    }
  else
    assert.todo()
  end
end

local function connect_output_to(state, ics, arg)
  assert.is_memory_writable(arg)
  if arg.type == 'memory' then
    local ics_name = arg.location .. arg.index
    local mem_ics = state.program_ics[ics_name]
    ics.out.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.combinator_input,
      target_entity = mem_ics.out,
      wire = ics.color_out,
    }
    return ics_name
  elseif arg.type == 'wire' then
    ics.out.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_entity = state.program_ics.output,
      wire = defines.wire_type.red,
    }
    ics.out.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_entity = state.program_ics.output,
      wire = defines.wire_type.green,
    }
    return 'output'
  else
    assert.todo()
  end
end

-------------------------------------------------------------------------------------------------------

local function vector_scalar_op(operation)
  return function(state, _)
    local src = (assert.two_or_three(_) == 3 and _[2]) or _[1]

    local input_a = connect_input_from(state, src)

    local ics = builder.create_arithmetic_cell(state.entity, input_a, nil, operation)

    local ics_name = connect_output_to(state, ics, _[1])

    local deffer = {
      {action='disable', ic=ics.clr, delay = 0},
      {action='tune', ic=ics.kin, value=0, delay = 0},
      {action='tune', ic=ics.kout, value=1, delay = 0},
      {action='tune', ic=ics.kin, value=1, delay = 1},
      {action='tune', ic=ics.kout, value=0, delay = 1},
      {action='noop', delay = 3},
    }

    return ics_name, ics, deffer
  end
end

local function vector_decide_op(operation)
  return function(state, _)
    local input_a = connect_input_from(state, _[1])
    local input_b = connect_input_from(state, _[3])

    local ics = builder.create_decider_cell(state.entity, input_a, input_b, operation)

    local ics_name = connect_output_to(state, ics, _[1])

    local deffer = {
      {action='disable', ic=ics.clr, delay = 0},
      {action='tune', ic=ics.kin, value=0, delay = 0},
      {action='tune', ic=ics.kout, value=1, delay = 0},
      {action='tune', ic=ics.kin, value=1, delay = 1},
      {action='tune', ic=ics.kout, value=0, delay = 1},
      {action='noop', delay = 3},
    }

    return ics_name, ics, deffer
  end
end

-------------------------------------------------------------------------------------------------------

local ops = {
  xmov = function(state, _)
    assert.two(_)

    local wire_to = (_[1].type == 'wire')

    local input_a = connect_input_from(state, _[2])

    local ics = builder.create_memory_cell(state.entity, input_a, wire_to)

    local ics_name = connect_output_to(state, ics, _[1])

    local deffer = {
      {action='disable', ic=ics.clr, delay = 0},
      {action='tune', ic=ics.kin, value=0, delay = 0},
      {action='tune', ic=ics.kout, value=1, delay = 0},
      {action='tune', ic=ics.kin, value=1, delay = 1},
      {action='tune', ic=ics.kout, value=0, delay = 1},
      {action='noop', delay = wire_to and 4 or 3},
    }

    return ics_name, ics, deffer
  end,

  xuni = function(state, _)
    assert.three(_)

    local input_a = connect_input_from(state, _[2])
    local input_b = connect_input_from(state, _[3])

    local merger = builder.create_merger_cell(state.entity, input_a, input_b)
    local ics = builder.create_memory_cell(state.entity, {
      entity = merger,
      wire = input_a.wire,
      port = defines.circuit_connector_id.combinator_output
    })
    ics[#ics + 1] = merger

    local ics_name = connect_output_to(state, ics, _[1])

    local deffer = {
      {action='disable', ic=ics.clr, delay = 0},
      {action='tune', ic=ics.kin, value=0, delay = 0},
      {action='tune', ic=ics.kout, value=1, delay = 1},
      {action='tune', ic=ics.kin, value=1, delay = 2},
      {action='tune', ic=ics.kout, value=0, delay = 2},
      {action='noop', delay = 4},
    }

    return ics_name, ics, deffer
  end,

  xflt = function(state, _)
    assert.three(_)

    local input_a = connect_input_from(state, _[2])
    local input_b = connect_input_from(state, _[3])

    local merger = builder.create_filter_cell(state.entity, input_a, input_b)
    local ics = builder.create_memory_cell(state.entity, {
      entity = merger,
      wire = input_a.wire,
      port = defines.circuit_connector_id.combinator_output
    })
    ics[#ics + 1] = merger

    local ics_name = connect_output_to(state, ics, _[1])

    local deffer = {
      {action='disable', ic=ics.clr, delay = 0},
      {action='tune', ic=ics.kin, value=0, delay = 0},
      {action='tune', ic=ics.kout, value=2, delay = 2},
      {action='tune', ic=ics.kin, value=2, delay = 3},
      {action='tune', ic=ics.kout, value=0, delay = 3},
      {action='noop', delay = 5},
    }

    return ics_name, ics, deffer
  end,

  xadd = vector_scalar_op('+'),
  xsub = vector_scalar_op('-'),
  xmul = vector_scalar_op('*'),
  xdiv = vector_scalar_op('/'),
  xmod = vector_scalar_op('%'),
  xpow = vector_scalar_op('^'),

  xand = vector_scalar_op('AND'),
  xor  = vector_scalar_op('OR'),
  xxor = vector_scalar_op('XOR'),
  xsl  = vector_scalar_op('<<'),
  xsr  = vector_scalar_op('>>'),

--[[
  xlt = vector_decide_op('<'),
  xle = vector_decide_op('≤'),
  xne = vector_decide_op('≠'),
  xeq = vector_decide_op('='),
  xge = vector_decide_op('≥'),
  xgt = vector_decide_op('>'),
]]
}

function builder.construct(ast, state_)
  state = state_

  if ops and ops[ast.name] then
    _destroy_on_error = {}
    get_debug_offset(state.entity, true)
    local status, name, ics, deffer = pcall(ops[ast.name], state, ast.expr)
    if not status then
      builder.destroy_ics(_destroy_on_error)
      error(name)
    else
      return name, ics, deffer
    end
  end
end


function builder.bind()
end
return builder
