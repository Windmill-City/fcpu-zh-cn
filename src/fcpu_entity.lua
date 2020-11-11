local HdlBuilder = require('src/cpu/hdl_builder')

-------------------------------------------------------------------------------------------------------

local handle_fcpu_create_v1 = require('legacy/handle_fcpu_create_v1')

local function handle_fcpu_create_v2(ent, tags)
  if ent.name == "imposter-fcpu" or ent.name == "entity-ghost" and ent.ghost_name == "imposter-fcpu" then
    ent.destroy()
    return
  end

  if ent.name == "fcpu" then
    local state = get_fcpu_state(ent)
    state.entity = ent
    state.disabled = tags.d

    Controller.verify(state)
    Controller.update_program_text(state, tags.t)
    Controller.compile(state)
    Controller.set_program_counter(state, 1)
    if tags.r then
      Controller.run(state)
    end
  end
end

function handle_fcpu_create(ent, tags)
  if ent.name == "fcpu" then
    local state = get_fcpu_state(ent)
    if state and state.may_be_revived then
      state.may_be_revived = false
      state.entity = ent
    else
      state = Controller.init(ent)
      register_fcpu(ent, state)
    end
  end

  if tags or ent.tags then
    handle_fcpu_create_v2(ent, tags or ent.tags)
  else
    handle_fcpu_create_v1(ent)
  end
end

function handle_fcpu_died(entity)
  local state = get_fcpu_state(entity)
  if state then
    state.may_be_revived = true
  end
end

function handle_fcpu_destroy(entity, soft)
  local state = get_fcpu_state(entity)
  if state and soft and state.may_be_revived then
    return
  end
  HdlBuilder.destroy_nodes(entity)
  destroy_fcpu(entity, state)
end

-------------------------------------------------------------------------------------------------------

function fcpu_update_program(fcpu, program_text)
  local state = get_fcpu_state(fcpu)
  local modified = Controller.update_program_text(state, program_text)

  if modified then
    Controller.verify(state)
  end
end
