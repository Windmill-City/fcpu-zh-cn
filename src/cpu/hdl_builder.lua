local state


local _destroy_on_error = {}
local builder = {}

local Enable = 0
local Disable = 1

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
  Entity.set_data(node_fcpu, {fcpu = entity})-- TODO: remove, as it leaks on surface destroy
  return node_fcpu, node_fcpu.get_or_create_control_behavior()
end

local function builder_destroy_nodes_r(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = get_fcpu_state(entity)
    if state and state.program_ics then
      builder.destroy_ics(state.program_ics)
      state.program_ics = {}
    end
  elseif entity.name == "entity-ghost" and entity.ghost_name == "fcpu" then
    local node_fcpus = entity.surface.find_entities_filtered{name = {"decider-fcpu", "arithmetic-fcpu", "constant-fcpu"}, position = { x = entity.position.x, y = entity.position.y }, radius = 10, force = entity.force}
    for _, v in ipairs(node_fcpus) do
      local state_node = Entity.get_data(v)
      if state_node.fcpu == entity then
        builder_destroy_nodes_r(v)
      end
    end
  end
end

function builder.destroy_nodes(state)
  local entity = state.entity
  if entity and entity.valid then
    builder_destroy_nodes_r(entity)
  else
    -- TODO: remove `Entity.[gs]et_data`, as it leaks on surface destroy
    builder.destroy_ics(state.program_ics)
    state.program_ics = {}
  end
end

function builder.destroy_ics(entity)
  if type(entity) == 'table' then
    if getmetatable(entity) ~= 'private' then
      for _, e in pairs(entity) do
        builder.destroy_ics(e)
      end
    elseif not entity.valid then
    elseif (entity.name == "decider-fcpu" or entity.name == "arithmetic-fcpu" or entity.name == "constant-fcpu" or entity.name == "output-fcpu" or entity.name == "lognet-fcpu") then
      debug_print('destroyed fcpu '.. entity.name ..' ic')
      Entity.set_data(entity, nil) -- TODO: remove, as it leaks on surface destroy
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

local function verify_channel(state, ics_name, debug_i)
  state.program_ics[ics_name] = state.program_ics[ics_name] or {}
  local ics = state.program_ics[ics_name]
  local updated

  if not (ics.out and ics.out.valid) then
    local ent_mem, ctrl_mem = builder.create_node(state.entity, 'decider', debug_i * 2)

    ics.out = ent_mem

    ctrl_mem.parameters = {
      first_signal = {type='virtual', name='signal-fcpu-error'},
      second_signal = nil,
      constant = 0,
      comparator = "=",
      output_signal = {type='virtual', name='signal-everything'},
      copy_count_from_input = true
    }

    updated = true
  end

  if not (ics.value and ics.value.valid) then
    local ent_val, ctrl_val = builder.create_node(state.entity, 'output', debug_i * 2 + 1)

    ics.value = ent_val
    ctrl_val.enabled = false

    updated = true
  end

  if updated then
    ics.value.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      target_entity = ics.out,
      wire = defines.wire_type.green,
    }
    ics.value.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      target_entity = ics.out,
      wire = defines.wire_type.red,
    }
  end

  return updated
end

local function verify_lognet(state, debug_i)
  local ics_name = 'lognet'
  state.program_ics[ics_name] = state.program_ics[ics_name] or {}
  local ics = state.program_ics[ics_name]
  local updated

  if not (ics.out and ics.out.valid) then
    local ent_lognet, ctrl_lognet = builder.create_node(state.entity, 'lognet', debug_i * 2)

    ics.out = ent_lognet
    ics.out_connector = defines.circuit_connector_id.roboport

    updated = true
  end

  if not (ics.pole and ics.pole.valid) then
    local ent_pole, ctrl_pole = builder.create_node(state.entity, 'output', debug_i * 2 + 1)

    ics.pole = ent_pole
    ctrl_pole.enabled = false

    updated = true
  end

  if updated then
    ics.out.connect_neighbour{
      source_circuit_id = ics.out_connector,
      target_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_entity = ics.pole,
      wire = defines.wire_type.green,
    }
    ics.out.connect_neighbour{
      source_circuit_id = ics.out_connector,
      target_circuit_id = defines.circuit_connector_id.constant_combinator,
      target_entity = ics.pole,
      wire = defines.wire_type.red,
    }
  end

  return updated
end

function builder.verify(state)
  state.program_ics = state.program_ics or {}

  if verify_channel(state, 'output', 1) then
    state.entity.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      target_entity = state.program_ics.output.out,
      wire = defines.wire_type.green,
    }
    state.entity.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.combinator_output,
      target_entity = state.program_ics.output.out,
      wire = defines.wire_type.red,
    }
  end

  for i = 1, MC_MEMORY_CHANNELS  do
    local ics_name = 'mem'..i
    verify_channel(state, ics_name, 1 + i)
  end

  verify_lognet(state, 1 + MC_MEMORY_CHANNELS + 2)
end

-------------------------------------------------------------------------------------------------------

function builder.create_merger_cell(entity, input_a, input_b)
  local wire1 = input_a.wire or inverse_wire_color(input_b.wire) or defines.wire_type.red
  local wire2 = inverse_wire_color(wire1)

  local proxy, control_proxy = builder.create_node(entity, 'decider')

  control_proxy.parameters = {
    first_signal = {type='virtual', name='signal-fcpu-error'},
    second_signal = nil,
    constant = 0,
    comparator = "=",
    output_signal = {type='virtual', name='signal-everything'},
    copy_count_from_input = true
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
  -- NEW: Whitelist:
  --[[ blueprint!
  0eNrtmE2PmzAQhv9K5GMLq5jwkaB2pUo999pDVSFCJhtrwSBjskUR/71jkrAkgRTTVTaHvUSxGb8ezzP2GHZkGReQCcYl8XeERSnPif9rR3L2xMNY9ckyA+ITJiEhBuFholoriNgKhBmlyZLxUKaCVAZhfAV/iE8ro0Ngy4QssKfR2FuYP1sjreq3QYBLJhns/agbZcCLZAkCpa95YJAszXFoytW0KGdarvvgGKTEvzad4jy4PinSOFjCJtwyHIOGB6UAn63q0bnqXTORy2DwKiCMNmQ/QS5DFc2paiRZKGrffPIFx6SFzIpRqlmJ/hVcBmuRJgHjKEN8KQqo9pNyiBrXqfoRsGoHkGHLQksmooLJulljaj22Tx/XLJ4EAD/X8S4M0QdLTdppbp2bn047w+FVq++I2tJF7bwbatOitmfPZ649P4P+9d2h03PofVRdPar00ryL4qxZXQIrViQmxOi0YJGZpTH8iyN9cHpW+j8+2Y1PoWByk4BEdwafI9N5T3K9ir1NfuWgZIKeNEszwCSrfSSfR2eZRiI5F4l0zI8hWWdc0+oD5YwA5d0DKHrK59Mt+NjXQz6/ysseBsQdAcS+AyCzMyCPj29OZEilPGey0KuctIeKN4KKcwdUmuPMO6Xz7cf32+Bxe4+0IeWlD8e88ey4VI0zyzlWvAscaxZLED23876gqK1e6xUq4HTkFX0fjVcdk7Zu7DpC6mWjpdNOgIPeTEuvhDhOX9qetUvkQdLWknzZ4JtOl49uI+joBq/s9PB10a6WYFSGbRjUmjVCniaNMHruTo99tRh/M+jaFwvtfWF/7IuPfXH7fZExrr0thtaXSr1/1d9S/NanF4PE4RLQt0M2T+poxyyXE2uCBfgZLbaY5PXusOYqUgvP9ejUddyq+gv+ovmO
  ]]
  -- NEW: Blacklist:
  --[[ blueprint!
  0eNrNmN9umzAUxl+l8uUGFTZ/g7RJm3a9F5gqRMBprIJBxrRDEe8+G1pwEpLglC69iWJifz4+P38HOzuwzmpcMkI5CHeAJAWtQPhnByrySONMPuNNiUEICMc5MACNc9lKcUJSzMykyNeExrxgoDUAoSn+C0LYGhMCz4TxWjwZNPoe5k9lJGofDIApJ5zgPo6u0US0zteYCelhdI5TUucmznDCGUnMssiw0C6LSgwuqJxYCJrIs+5dAzTiqwPhvSvmEmukYhDplroDUH48MoypOiFJRTSiL2FJTXjfbB/aVi7tICZ0LitTEcExIquPh7Mii9Z4Gz8TMUZ0fFWKxG8pGULdEFbxaHZmcZxsQT9BxWNJ2JKNvIxZF1sIvosxRc3L+irVshHx1ZRHG1bkEaFCBoSc1bg9kWWG08Mc2/s5hkp+Zds9QmBMszruKGJAJ9EezmPPQ23rorZuhtpE0PGdwPac4AD6t5tDR4fQT1H19ajONKwzrC5mhG9zzEX9uAASDSCt4ATIUWwZlhWWMpGCVFS/osSCYxca+HI1SA1W7nmDBiOSy4O17DtFzr2CHPwE5KDl274DA+TsE/z6Pwg6R247Qwydx+3MBaqrs/+zN287eFdsB+sTbIehNPv72+HH71+Lb4g5dRVeqKsz3enr43BXn6Guqq/Km/DwzrtldYGPfYxzik8wRPq2do23nvt2dj7isyEZx+zEteFUkmTp6fTqzhC2ZVlX3h/6jIxaULlN6OjIi5AiYzqu7Y1atpZWg7OseJkMytESetmKe5ei40A0Srm6eWomI/K0ZJImns62ryWTFnxSJdALZouTJxWa6uRXxZXmLoj3FMfIYH/Uuf6lO2XJla4l1YL5oZaEC9nRXMiP6jtzGU9ObZb3uXMQ9Jbx6FSE73Mrshfxq6kK3dqyJaHajp17KmrlAbf76ytU/ikzQBavsYjt1Wh3XdXISMXv0J04pzyJHs/Cf51xUSAXuPI9H1qe67XtP3iZiN4=
  ]]

  -- CURRENT: Whitelist
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
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    first_constant  = nil,
    second_constant = -1,
    operation  = '*',
    output_signal = {type='virtual', name='signal-each'}
  }
  control_a2.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    first_constant  = nil,
    second_constant = -2147483648,
    operation  = '+',
    output_signal = {type='virtual', name='signal-each'}
  }
  control_a3.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    first_constant  = nil,
    second_constant = 2147483647,
    operation  = 'AND',
    output_signal = {type='virtual', name='signal-each'}
  }

  control_d1.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    constant = 0,
    comparator = "<",
    output_signal = {type='virtual', name='signal-each'},
    copy_count_from_input = false
  }
  control_d2.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    constant = 0,
    comparator = "<",
    output_signal = {type='virtual', name='signal-each'},
    copy_count_from_input = true
  }
  control_d3.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    constant = -2147483648,
    comparator = "=",
    output_signal = {type='virtual', name='signal-each'},
    copy_count_from_input = true
  }

  a1.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = input_msk.port,
    target_entity = input_msk.entity,
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
    target_circuit_id = input_src.port,
    target_entity = input_src.entity,
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

  return {a1,a2,a3,d1,d2,gate=d3}
end

-------------------------------------------------------------------------------------------------------
local function builder_generate_clr(index, delay, ics)
  local actions = {
    {action='tune', ic=ics.kout, value=Disable, delay = delay},
    {action='tune', ic=ics.kout, value=Enable, delay = delay + 1},
  -- hold kout for 1 tick until new kout has read kin
    {action='tune', ic=ics.kaux, value=Enable, delay = delay},
    {action='tune', ic=ics.kaux, value=Disable, delay = delay + 1},
  -- wait for clear
    --{action='sync', index=index, delay=delay + 2},
  }
  return actions
end

local function builder_generate_run(index, delay, ics)
  local actions = {
  -- new ic: capture input in kin for 1 tick
    {action='tune', ic=ics.kin, value=Enable, delay = delay},
    {action='tune', ic=ics.kin, value=Disable, delay = delay + 1},
  -- new ic: disable/reenable kout (sets out to zero ready for new input)
    {action='tune', ic=ics.kout, value=Disable, delay = delay},
    {action='tune', ic=ics.kout, value=Enable, delay = delay + 1},
  -- wait for output
    {action='sync', index=index, delay=delay + 3}, -- kin, kout, out
  }
  return actions
end

local function builder_generate_retain(index, delay, ics)
  local actions = {}
  if ics ~= ics_prev then
    -- old ic: disable kout
    actions[#actions+1] = {action='tune', ic=ics.kout, value=Disable, delay = delay}
  end
  -- hold kout for 1 tick until new kout has read kin
  actions[#actions+1] = {action='tune', ic=ics.kaux, value=Enable, delay = delay}
  actions[#actions+1] = {action='tune', ic=ics.kaux, value=Disable, delay = delay + 1}
  return actions
end

local function generate_deffer(ics, index, delay)
  return {
    clr = builder_generate_clr(index, delay, ics),
    run = builder_generate_run(index, delay, ics),
  }
end

function builder.create_memory_cell(entity, input_a)
  local wire1 = input_a.wire or defines.wire_type.red
  local wire2 = inverse_wire_color(wire1)

  -- Thanks for this improvement to `yaongi jigsaw`
  --
  -- [X*]--->[kin]-+->[kout]-+---------+->[out]
  --               ^         |         ^
  --               |---------+->[kaux]-|
  --
  -- - kin guards against loops and changing input, only has a value for a single tick
  -- - kout loops, maintaining the output
  -- - kaux holds kout for the tick necessary for kout to read kin
  local d_key, control_key = builder.create_node(entity, 'decider')
  local d_out, control_out = builder.create_node(entity, 'decider')
  local d_aux, control_aux = builder.create_node(entity, 'decider')

  for _,c in ipairs({control_key, control_out, control_aux}) do
    c.parameters = {
      first_signal = {type='virtual', name='signal-fcpu-error'},
      second_signal = nil,
      constant = 1,
      comparator = "=", -- < ≤ ≠ = ≥ >
      output_signal = {type='virtual', name='signal-everything'},
      copy_count_from_input = true
    }
  end

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
    wire = wire2,
  }
  d_out.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d_out,
    wire = wire1,
  }
  d_out.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d_aux,
    wire = wire2,
  }
  d_aux.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_output,
    target_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = d_aux,
    wire = wire2,
  }

  local ics = {
    color_out = wire2,
    kin = d_key,
    kout = d_out,
    kaux = d_aux,
  }

  return ics
end


function builder.create_arithmetic_cell(entity, input_a, input_b, operation)
  local constant
  if input_b then
    if type(input_b) == 'number' then
      constant = input_b
    else
      Assert.todo()
    end
  end

  local x, control_x = builder.create_node(entity, 'arithmetic')

  control_x.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    first_constant  = nil,
    second_constant = constant,
    operation  = operation,
    output_signal = {type='virtual', name='signal-each'}
  }

  x.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_circuit_id = input_a.port,
    target_entity = input_a.entity,
    wire = input_a.wire,
  }
  if input_b ~= nil and constant == nil then
    control_x.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_input,
      target_circuit_id = input_a.port,
      target_entity = input_a.entity,
      wire = inverse_wire_color(input_a.wire),
    }
  end

  return x
end


function builder.create_decider_cell(entity, input, signal, operation)
  local x, control_x = builder.create_node(entity, 'decider')

  control_x.parameters = {
    first_signal = {type='virtual', name='signal-each'},
    second_signal = nil,
    constant = 0,
    comparator = operation,
    output_signal = {type='virtual', name='signal-each'},
    copy_count_from_input = true
  }

  x.connect_neighbour{
    source_circuit_id = defines.circuit_connector_id.combinator_input,
    target_entity = input.entity,
    target_circuit_id = input.port or defines.circuit_connector_id.combinator_output,
    wire = input.wire,
  }

  return x
end

-------------------------------------------------------------------------------------------------------

local function connect_input_from(state, address)
  Assert.is_channel_readable(address)
  if address.type == 'memory' or address.type == 'channel' then
    local ics_name = address.channel
    local ics = state.program_ics[ics_name]
    return {
      entity = ics.out,
      wire = defines.wire_type.red,
      port = ics.out_connector or defines.circuit_connector_id.combinator_output
    }
  elseif address.type == 'wire' then
    return {
      entity = state.entity,
      wire = defines.wire_type[address.color],
      port = defines.circuit_connector_id.combinator_input
    }
  else
    Assert.todo()
  end
end

local function connect_output_to(state, ics, address)
  Assert.is_channel_writable(address)
  if address.type == 'memory' then
    local ics_name = address.channel
    local mem_ics = state.program_ics[ics_name]
    ics.kout.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.combinator_input,
      target_entity = mem_ics.out,
      wire = ics.color_out,
    }
    return ics_name
  elseif address.type == 'wire' then
--[[ moved from `create_memory_cell`
    if input_b ~= nil then
      local isTable = (type(input_b) == 'table')
      local proxy, control_proxy = builder.create_node(entity, 'decider')

      control_proxy.parameters = {
        first_signal = {type='virtual', name='signal-fcpu-error'},
        second_signal = nil,
        constant = 0,
        comparator = "=",
        output_signal = {type='virtual', name='signal-everything'},
        copy_count_from_input = true
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
]]
    ics.kout.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.combinator_input,
      target_entity = state.program_ics.output.out,
      wire = ics.color_out,
    }
    ics.kout.connect_neighbour{
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.combinator_input,
      target_entity = state.program_ics.output.out,
      wire = ics.color_out,
    }
    return 'output'
  else
    Assert.todo()
  end
end

-------------------------------------------------------------------------------------------------------

local function vector_scalar_op(operation)
  return function(state, _)
    local three = Assert.two_or_three(_) == 3

    local input = connect_input_from(state, (three and _[2]) or _[1])
    local value = nil

    local x = builder.create_arithmetic_cell(state.entity, input, value, operation)
    local ics = builder.create_memory_cell(state.entity, {
      entity = x,
      wire = inverse_wire_color(input.wire),
      port = defines.circuit_connector_id.combinator_output
    })
    ics.x = x

    local ics_name = connect_output_to(state, ics, _[1])

    local deffer = generate_deffer(ics, state.index, 1)
    --[[local deffer = {
      run = {
        {action='tune', ic=ics.kin, value=0, delay = 0},
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kin, value=1, delay = 1},
        {action='tune', ic=ics.kout, value=0, delay = 1},
        {action='sync', index=state.index, delay = 3 + 1},
      },
      clr = {
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kout, value=0, delay = 1},
      },
    }]]

    return ics_name, ics, deffer
  end
end

local function vector_decide_op(operation)
  return function(state, _)
    local three = Assert.two_or_three(_) == 3

    local input = connect_input_from(state, (three and _[2]) or _[1])
    local value = nil

    local x = builder.create_decider_cell(state.entity, input, value, operation)
    local ics = builder.create_memory_cell(state.entity, {
      entity = x,
      wire = inverse_wire_color(input.wire),
      port = defines.circuit_connector_id.combinator_output
    })
    ics.x = x

    local ics_name = connect_output_to(state, ics, _[1])

    --[[local deffer = {
      run = {
        {action='tune', ic=ics.kin, value=0, delay = 0},
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kin, value=1, delay = 1},
        {action='tune', ic=ics.kout, value=0, delay = 1},
        {action='sync', index=state.index, delay = 3 + 1},
      },
      clr = {
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kout, value=0, delay = 1},
      },
    }]]
    local deffer = generate_deffer(ics, state.index, 1)

    return ics_name, ics, deffer
  end
end

-------------------------------------------------------------------------------------------------------

local ops = {
  xmov = function(state, _)
    Assert.two(_)

    local wire_to = (_[1].type == 'wire')

    local input_a = connect_input_from(state, _[2])

    local ics = builder.create_memory_cell(state.entity, input_a)

    local ics_name = connect_output_to(state, ics, _[1])

    --[[local deffer = {
      run = {
        {action='tune', ic=ics.kin, value=0, delay = 0},
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kin, value=1, delay = 1},
        {action='tune', ic=ics.kout, value=0, delay = 1},
        {action='sync', index=state.index, delay = 3},
      },
      clr = {
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kout, value=0, delay = 1},
      },
    }]]
    local deffer = generate_deffer(ics, state.index, 0)

    return ics_name, ics, deffer
  end,

  xuni = function(state, _)
    Assert.three(_)

    local mainWireIsFirst = (_[2].type == 'wire')
    local input_a = connect_input_from(state, _[mainWireIsFirst and 2 or 3])
    local input_b = connect_input_from(state, _[mainWireIsFirst and 3 or 2])

    local merger = builder.create_merger_cell(state.entity, input_a, input_b)
    local ics = builder.create_memory_cell(state.entity, {
      entity = merger,
      wire = input_a.wire,
      port = defines.circuit_connector_id.combinator_output
    })
    ics[#ics + 1] = merger

    local ics_name = connect_output_to(state, ics, _[1])

    --[[local deffer = {
      run = {
        {action='tune', ic=ics.kin, value=0, delay = 1},
        {action='tune', ic=ics.kout, value=1, delay = 1},
        {action='tune', ic=ics.kin, value=1, delay = 2},
        {action='tune', ic=ics.kout, value=0, delay = 2},
        {action='sync', index=state.index, delay = 3 + 1},
      },
      clr = {
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kout, value=0, delay = 1},
      },
    }]]
    local deffer = generate_deffer(ics, state.index, 1)

    return ics_name, ics, deffer
  end,

  xflt = function(state, _)
    local three = Assert.two_or_three(_) == 3

    local input_a = connect_input_from(state, _[three and 2 or 1])
    local input_b = connect_input_from(state, _[three and 3 or 2])

    local merger = builder.create_filter_cell(state.entity, input_a, input_b)
    local ics = builder.create_memory_cell(state.entity, {
      entity = merger.gate,
      wire = input_a.wire,
      port = defines.circuit_connector_id.combinator_output
    })
    for _,ic in pairs(merger) do
      ics[#ics + 1] = ic
    end

    local ics_name = connect_output_to(state, ics, _[1])

    --[[local deffer = {
      run = {
        {action='tune', ic=ics.kin, value=0, delay = 0},
        {action='tune', ic=ics.kout, value=2, delay = 2},
        {action='tune', ic=ics.kin, value=2, delay = 3},
        {action='tune', ic=ics.kout, value=0, delay = 3},
        {action='sync', index=state.index, delay = 3 + 2},
      },
      clr = {
        {action='tune', ic=ics.kout, value=1, delay = 0},
        {action='tune', ic=ics.kout, value=0, delay = 1},
      },
    }]]
    local deffer = generate_deffer(ics, state.index, 2)

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

  xclt = vector_decide_op('<'),
  xcle = vector_decide_op('≤'),
  xcne = vector_decide_op('≠'),
  xceq = vector_decide_op('='),
  xcge = vector_decide_op('≥'),
  xcgt = vector_decide_op('>'),
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


function builder.setup()
end
return builder
