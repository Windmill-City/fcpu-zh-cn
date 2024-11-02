local HdlBuilder = require('src/cpu/hdl_builder')

-------------------------------------------------------------------------------------------------------

local function handle_fcpu_create_v2(ent, tags)
  if ent.name == "fcpu" then
    local state = get_fcpu_state(ent)
    state.entity = ent
    state.disabled = tags.d
    state.custom_name = tags.n

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
    --error('OBSOLETE: handle_fcpu_create_v1')
    if ent.name == "fcpu" then
      debug_print("handling "..ent.name)
      local fcpu_state = get_fcpu_state(ent)
      Controller.verify(fcpu_state)
    end
  end
end

function handle_fcpu_died(entity)
  local state = get_fcpu_state(entity)
  if state then
    state.may_be_revived = true
  end
end

function handle_fcpu_destroy(state, soft)
  if state and soft and state.may_be_revived then
    return
  end
  HdlBuilder.destroy_nodes(state)
  destroy_fcpu(state)
end

-------------------------------------------------------------------------------------------------------

function fcpu_update_program(fcpu, program_text)
  local state = get_fcpu_state(fcpu)
  if state then
    local modified = Controller.update_program_text(state, program_text)

    if modified then
      Controller.verify(state)
    end
  end
end

function is_entity(obj, check_metatable)
  local t = type(obj)
  if not ((t == 'userdata' and MC_FACTORIO2) or (t == 'table' and not MC_FACTORIO2)) then
    return false
  end
  return check_metatable ~= true or getmetatable(obj) == 'private'
end