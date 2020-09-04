local HdlBuilder = require('src/cpu/hdl_builder')

-------------------------------------------------------------------------------------------------------

local function fcpu_set_imposter(entity, imposter_fcpu)
  local state = Entity.get_data(entity) or {}
  state.imposter_fcpu = imposter_fcpu
  Entity.set_data(entity, state)
end

function fcpu_create_imposter(entity)
  local surf = entity.surface
  local imposter_fcpu = surf.create_entity({
    name = "imposter-fcpu",
    position = entity.position,
    direction = entity.direction,
    force = entity.force
  })
  imposter_fcpu.destructible = false
  imposter_fcpu.operable = false
  Entity.set_data(imposter_fcpu, {fcpu = entity})
  return imposter_fcpu
end

function fcpu_destroy_imposter(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    fcpu_destroy_imposter(state.imposter_fcpu)
  elseif entity.name == "imposter-fcpu" then
    local imposter_state = Entity.get_data(entity)
    if imposter_state and imposter_state.fcpu and imposter_state.fcpu.valid then
      fcpu_set_imposter(imposter_state.fcpu, nil)
    end
    debug_print("destroyed fcpu imposter")
    entity.destroy()
  elseif entity.name == "entity-ghost" and entity.ghost_name == "fcpu" then
    local imposter_fcpus = entity.surface.find_entities_filtered{name = "imposter-fcpu", position = entity.position, force = entity.force, limit = 1}
    if #imposter_fcpus > 0 then
      fcpu_destroy_imposter(imposter_fcpus[1])
    end
  end
end

-------------------------------------------------------------------------------------------------------

require('__fcpu__/3rdparty/blueprintdata')

function fcpu_verify_utility(entity)
  local state = Entity.get_data(entity)

  if not (state.imposter_fcpu and state.imposter_fcpu.valid) then
    local imposter_fcpu = fcpu_create_imposter(entity)
    fcpu_set_imposter(entity, imposter_fcpu)
  end

  if not (state.output_fcpu and state.output_fcpu.valid) then
    local output_fcpu = HdlBuilder.create_output(entity)
    HdlBuilder.set_output(entity, output_fcpu)

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

  return state
end

local function encode_fcpu(entity)
  local state = fcpu_verify_utility(entity)
  write_to_combinator(state.imposter_fcpu, {
    t=state.program_text,
    i=state.instruction_pointer,
    r=Controller.is_running(state)
  })
end

local function decode_fcpu(imposter_fcpu, target)
  local data = read_from_combinator(imposter_fcpu)
  if data and type(data) == 'table' and data.t ~= nil and data.r ~= nil and data.i ~= nil then
    debug_print('decoded result have ', string.len(data.t), ' char length')
    local imposter_state = Entity.get_data(imposter_fcpu) or {}
    imposter_state.target = target
    imposter_state.target_program = data.t
    imposter_state.run = data.r
    imposter_state.ip = 1
    Entity.set_data(imposter_fcpu, imposter_state)
    return imposter_state
  else
    game.print("fCPU failed to decode a program, as it was made with incompatible version of the mod. Please install the newest version of fCPU and try again.")
  end
end

local function update_fcpu_target(imposter_fcpu, new_fcpu)
  local imposter_state = Entity.get_data(imposter_fcpu)
  Entity.set_data(imposter_fcpu, { fcpu = new_fcpu })

  local state = Entity.get_data(new_fcpu) or { ['entity'] = new_fcpu }
  state.imposter_fcpu = imposter_fcpu

  if imposter_state.target_program then
    Controller.update_program_text(state, imposter_state.target_program)
    Controller.compile(state)
    Controller.set_program_counter(state, imposter_state.ip)
    if imposter_state.run then
      Controller.run(state)
    end
  else
    debug_print('--- can not update program')
  end

  Entity.set_data(new_fcpu, state)
end

function handle_fcpu_create(ent)
  if ent.name == "fcpu" then
    Entity.set_data(ent, Controller.init(ent))
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

  if ent.name == "entity-ghost" and ent.ghost_name == "imposter-fcpu" then
    local revived, rev_ent = ent.revive()
    if revived then
      debug_print("revive imposter from ghost")
      ent = rev_ent
    end
  end

  if ent.name == "imposter-fcpu" then
    debug_print("handling "..ent.name)
    ent.destructible = false;
    ent.operable = false;

    -- only place an imposter-fcpu on a ghost, if that ghost doesn't already have a fCPU
    local fcpu_target

    -- in case the target has not been revived yet
    local fcpu_targets = ent.surface.find_entities_filtered{name = "entity-ghost", position = ent.position, force = ent.force, limit = 1}
    if #fcpu_targets > 0 then
      local target = fcpu_targets[1]
      if target.valid and (target.ghost_name == "fcpu") and get_fcpu_state(target) == nil then
        fcpu_target = target
        debug_print("- found fcpu_target among nearby ghosts")
      end
    end

    -- in case the target has already been revived
    if not fcpu_target then
      fcpu_targets = ent.surface.find_entities_filtered{position = ent.position, force = ent.force}
      for _, target in pairs(fcpu_targets) do
        if target.prototype.has_flag("player-creation") then
          if target.valid and (target.name == "fcpu") and get_fcpu_state(target) == nil then
            fcpu_target = target
            debug_print("- found fcpu_target, which already revived")
          end
          break
        end
      end
    end

    if fcpu_target then
      debug_print('- decode '..fcpu_target.name)
      local imposter_state = decode_fcpu(ent, fcpu_target)
      if imposter_state then
        -- align to avoid incremental position error
        ent.teleport(fcpu_target.position)
      else
        -- we could keep around the imposter-fcpu in case they install a newer version that makes it readable
        -- but then we'd have to keep track of the imposter-fcpus on the map, instead of just decoding on creation
        ent.destroy()
      end
    else
      ent.destroy()
    end
  elseif ent.name == "fcpu" then
    debug_print("handling "..ent.name)
    local x = ent.position.x
    local y = ent.position.y
    local imposter_fcpus = ent.surface.find_entities_filtered{name="imposter-fcpu",area={{x-1,y-1}, {x+1,y+1}}}
    for _,imposter_fcpu in pairs(imposter_fcpus) do
      local imposter_state = get_imposter_fcpu_state(imposter_fcpu)
      local target = imposter_state.target or imposter_state.fcpu
      if target then
        if 0 < fcpu_debug_enabled then
          if imposter_state.target then
            debug_print("- got target")
          elseif imposter_state.fcpu then
            if imposter_state.fcpu.valid then
              debug_print("- got valid fcpu: "..serpent.block(imposter_state.fcpu.unit_number))
            else
              debug_print("- got invalid fcpu")
            end
          end
        end
        if not target.valid then -- if we deleted a ghost with this placement
          if math.abs(imposter_fcpu.position.x-x)<0.01 and math.abs(imposter_fcpu.position.y-y)<0.01 then -- if we replaced a correct ghost, reassign
            debug_print("-- update imposter fcpu state")
            update_fcpu_target(imposter_fcpu, ent)
            break
          else -- we destroyed an unrelated ghost
            debug_print("-- destroy_imposter_fcpu - unrelated")
          --  fcpu_destroy_imposter(imposter_fcpu)
          end
          --break
        end
      end
    end
    fcpu_verify_utility(ent)
  else
    debug_print("skip handling "..ent.name)
  end
end

function handle_fcpu_destroy(entity, leave_imposter)
  HdlBuilder.destroy_output(entity)
  HdlBuilder.destroy_node(entity)

  if entity.name == "fcpu" then
    -- move data from fcpu to its imposter so we can revive it later
    local imposter_fcpus = entity.surface.find_entities_filtered{name = "imposter-fcpu", position = entity.position, force = entity.force, limit = 1}
    if #imposter_fcpus > 0 then
      local imposter_fcpu = imposter_fcpus[1]
      if imposter_fcpu.valid then
        local imposter_state = get_imposter_fcpu_state(imposter_fcpu)
        if imposter_state ~= nil then
          local state = get_fcpu_state(entity)
          if state ~= nil then
            -- rendering.draw_line{from={entity.position.x+0.1, entity.position.y}, to=imposter_fcpu, width=5, color={b = 1, a = 0.8}, surface=entity.surface }
            debug_print("moved to imposter ", imposter_fcpu.unit_number)
            imposter_state.target_program = state.program_text
            imposter_state.ip = state.instruction_pointer
            imposter_state.run = Controller.is_running(state)
            Entity.set_data(imposter_fcpu, imposter_state)

            if leave_imposter then
              return
            end
          end
        end
      end
    end
  end

  fcpu_destroy_imposter(entity)
end

-------------------------------------------------------------------------------------------------------

function fcpu_update_program(fcpu, program_text)
  local state = Entity.get_data(fcpu)
  local modified = Controller.update_program_text(state, program_text)
  Entity.set_data(fcpu, state)

  if modified then
    encode_fcpu(fcpu)
  end
end

function fcpu_update_blueprint(fcpu)
  local state = get_fcpu_state(fcpu)
  if state then
    encode_fcpu(state.entity)
  end
end
