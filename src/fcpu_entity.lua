local HdlBuilder = require('src/cpu/hdl_builder')

-------------------------------------------------------------------------------------------------------

function fcpu_verify_utility(entity)
  local state = get_fcpu_state(entity)

  if not (state.program_ics.output and state.program_ics.output.valid) then
    local output_fcpu = HdlBuilder.create_node(entity, 'output', false)
    state.program_ics.output = output_fcpu

    entity.connect_neighbour({
      wire = defines.wire_type.green,
      target_entity = output_fcpu,
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.constant_combinator
    })
    entity.connect_neighbour({
      wire = defines.wire_type.red,
      target_entity = output_fcpu,
      source_circuit_id = defines.circuit_connector_id.combinator_output,
      target_circuit_id = defines.circuit_connector_id.constant_combinator
    })
  end

  for i = 1, MC_MEMORY_CHANNELS  do
    local name = 'mem'..i
    if not (state.program_ics[name] and state.program_ics[name].out and state.program_ics[name].out.valid) then
      local ent_mem, ctrl_mem = HdlBuilder.create_node(entity, 'decider', i)

      state.program_ics[name] = { out = ent_mem }

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
  end

  return state
end

local handle_fcpu_create_v1 = require('legacy/handle_fcpu_create_v1')

local function handle_fcpu_create_v2(ent, tags)
  if ent.name == "imposter-fcpu" or ent.name == "entity-ghost" and ent.ghost_name == "imposter-fcpu" then
    ent.destroy()
    return
  end

  if ent.name == "fcpu" then
    local state = fcpu_verify_utility(ent)
    state.entity = ent
    state.disabled = tags.d

    Controller.update_program_text(state, tags.t)
    Controller.compile(state)
    Controller.set_program_counter(state, 1)
    if tags.r then
      Controller.run(state)
    end

    set_fcpu_state(ent, state)
  end
end

function handle_fcpu_create(ent, tags)
  if ent.name == "fcpu" then
    local state = Controller.init(ent)
    set_fcpu_state(ent, state)
    local didFind = false
    for _, v in ipairs(global.fcpus) do
      if v == ent then
        didFind = true
      end
    end
    if not didFind then
      table.insert(global.fcpus, ent)
    end
  end

  if tags or ent.tags then
    handle_fcpu_create_v2(ent, tags or ent.tags)
  else
    handle_fcpu_create_v1(ent)
  end
end

function handle_fcpu_destroy(entity)
  -- TODO: add undo information save
  HdlBuilder.destroy_nodes(entity)
end

-------------------------------------------------------------------------------------------------------

function fcpu_update_program(fcpu, program_text)
  local state = get_fcpu_state(fcpu)
  local modified = Controller.update_program_text(state, program_text)
  set_fcpu_state(fcpu, state)

  if modified then
    fcpu_verify_utility(fcpu)
  end
end
