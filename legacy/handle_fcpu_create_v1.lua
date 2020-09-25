require('__fcpu__/legacy/3rdparty/blueprintdata')

-------------------------------------------------------------------------------------------------------

local function fcpu_create_imposter(entity)
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

-------------------------------------------------------------------------------------------------------

local function decode_fcpu(imposter_fcpu, target)
  local data = read_from_combinator(imposter_fcpu)
  if data and type(data) == 'table' and data.t ~= nil and data.r ~= nil and data.i ~= nil then
    debug_print('decoded result have ', string.len(data.t), ' char length')
    local imposter_state = Entity.get_data(imposter_fcpu) or {}
    imposter_state.target = target
    imposter_state.target_program = data.t
    imposter_state.disabled = data.d
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

  local state = get_fcpu_state(new_fcpu) or { ['entity'] = new_fcpu }
  state.imposter_fcpu = nil
  state.disabled = imposter_state.disabled

  register_fcpu(new_fcpu, state)
  Controller.verify(state)

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
  set_fcpu_state(new_fcpu, state)

  Entity.set_data(imposter_fcpu, nil)
  imposter_fcpu.destroy()
end

-------------------------------------------------------------------------------------------------------

return function(ent)
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
      local fcpu_state = get_fcpu_state(fcpu_target)
      if fcpu_state or fcpu_target.tags then
        Entity.set_data(ent, nil)
        ent.destroy()
      else
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
      local imposter_state = Entity.get_data(imposter_fcpu)
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
            return
          else -- we destroyed an unrelated ghost
            debug_print("-- destroy_imposter_fcpu - unrelated")
            imposter_fcpu.destroy()
          end
          --break
        end
      end
    end

    local fcpu_state = get_fcpu_state(ent)
    Controller.verify(fcpu_state)

    --[[if not (fcpu_state.imposter_fcpu and fcpu_state.imposter_fcpu.valid) then
      local imposter_fcpu = fcpu_create_imposter(ent)
      if fcpu_state == nil then
        assert.todo()
        register_fcpu(ent, fcpu_state)
      end
      fcpu_state = fcpu_state or {}
      fcpu_state.imposter_fcpu = imposter_fcpu
      set_fcpu_state(ent, fcpu_state)
    end]]
  else
    debug_print("skip handling "..ent.name)
  end
end
