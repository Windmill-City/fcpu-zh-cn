local function foreach_fcpu_v1(proc)
  for _, fcpu in pairs(global.fcpus) do
    if fcpu.valid then
      local state = Entity.get_data(fcpu)
      if state then
        proc(fcpu, state)
      end
    end
  end
end

local function foreach_fcpu(proc)
  for k, state in pairs(global.fcpus) do
    if state and state.entity and state.entity.valid then
      proc(state.entity, state)
    else
      global.fcpus[k] = nil
      global.running[k] = nil

      for i,v in pairs(global.unmap) do
        if v == k then
          global.unmap[i] = nil
        end
      end
    end
  end
end

local function foreach_player(proc)
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data then
      proc(player, player_data)
    end
  end
end

local function replace_word(str, pattern, target)
  return string.sub(string.gsub(' '..str..' ', '([^%w])'..pattern..'([^%w])', '%1'..target..'%2'), 2, -2)
end

return {
  ["0.0.1"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      state.instruction_pointer = state.program_counter
      state.program_counter = nil
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.1.13"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      state.entity = fcpu
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.2.0"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      local signal
      local control = fcpu.get_or_create_control_behavior()
      if control then
        signal = {
          count = control.parameters.first_constant,
          signal_id = control.parameters.output_signal
        }
        control.parameters = {
          first_signal = nil,
          second_signal = nil,
          first_constant = nil,
          second_constant = nil,
          operation = "+",
          output_signal = nil
        }
      end
      state.program_ics = {}
      Controller.verify(state)
      Controller.compile(state)
      state.breakpoints = {} -- backport 0.3.10
      Controller.update_ip(state)
      state.cache = {} -- backport 0.3.17
      Controller.update_state(state)
      Entity.set_data(fcpu, state)

      if signal then
        control = (state.program_ics.output and state.program_ics.output.value or state.program_ics.output).get_control_behavior()
        local params = control.parameters
        params[1].signal = signal.signal_id
        params[1].count = signal.count or 0
        params[1].index = 1
        control.parameters = params
      end
    end)
  end,

  ["0.2.9"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      state.gui_fcpu = nil
      state.gui_exit_button = nil
      state.gui_halt_button = nil
      state.gui_step_button = nil
      state.gui_run_button = nil
      state.gui_enable_switch = nil
      state.gui_inspector = nil
      state.gui_line_numbers = nil
      state.gui_program_input = nil
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.3.0"] = function()
    local fcpus = {}
    for _,v in pairs(global.fcpus) do
      local state = Entity.get_data(v)
      state.destroy_regnum = script.register_on_entity_destroyed(v)
      state.index = #fcpus + 1
      fcpus[state.index] = state
      Entity.set_data(state.entity, state.index)
    end
    global.fcpus = fcpus

    foreach_fcpu(function(fcpu, state)
      state.program_begin = 1
      state.program_ics = state.program_ics or {}
      state.ics_stack = {}
      state.deffered = {}
      state.program_ics.output = state.program_ics.output or { value = state.output_fcpu }
      state.output_fcpu = nil

      if state.imposter_fcpu then
        if state.imposter_fcpu.valid then
          Entity.set_data(state.imposter_fcpu, nil)
          state.imposter_fcpu.destroy()
        end
        state.imposter_fcpu = nil
      end
    end)
    foreach_player(function(player, player_data)
      if player_data.gui_fcpu and player_data.gui_fcpu.valid then
        player_data.gui_error_message = player_data.gui_fcpu['error_message']
        player_data.gui_editor_toolbar = player_data.gui_fcpu['editor-toolbar']
      end
    end)
    for _, surface in pairs(game.surfaces) do
      for _, imposter_fcpu in pairs(surface.find_entities_filtered{ name="imposter-fcpu" }) do
        if imposter_fcpu then
          if imposter_fcpu.valid then
            Entity.set_data(imposter_fcpu, nil)
            imposter_fcpu.destroy()
          end
        end
      end
    end
  end,

  ["0.3.6"] = function()
    foreach_fcpu(function(fcpu, state)
      for i = 1,4 do
        local mem = state.program_ics and state.program_ics['mem'..i]
        if mem and mem.value then
          if mem.value.valid then
            mem.value.destroy()
          end
          mem.value = nil
        end
      end
    end)
  end,

  ["0.3.7"] = function()
    foreach_fcpu(function(fcpu, state)
      state.program_text = replace_word(state.program_text, 'emit', 'mov out1')

      state.program_text = replace_word(state.program_text, 'fim', 'fid')
      state.program_text = string.gsub(state.program_text, '(fid%s+)([^%s]+)(%s+)([^%s]+)', '%1%4%3%2')

      if state.program_ast then
        for k,v in pairs(state.program_ast) do
          if v.type == 'op' then
            if v.name == 'emit' then
              v.name = 'mov'
              v.expr[2] = v.expr[1]
              v.expr[1] = { type='wire', color='out', addr=1, pointer=false }
            elseif v.name == 'fim' then
              v.name = 'fid';
              v.expr[1], v.expr[2] = v.expr[2], v.expr[1]
            end
          end
        end
      end
    end)
  end,

  ["0.3.8"] = function()
    local valids = {}
    for _, surface in pairs(game.surfaces) do
      for _, fcpu in pairs(surface.find_entities_filtered{ name="fcpu" }) do
        if fcpu and fcpu.valid then
          local index = Entity.get_data(fcpu, nil)
          if index then
            valids[index] = fcpu
          else
            fcpu.destroy()
          end
        end
      end
    end
    local invalids = {}
    for k,v in pairs(global.fcpus) do
      if not v then
        invalids[#invalids + 1] = k
      elseif v.index ~= k then
        invalids[#invalids + 1] = k
        Entity.set_data(v.entity, v.index)
      else
        local fcpu = valids[k]
        if fcpu == nil then
          invalids[#invalids + 1] = k
        else
          Controller.verify(v)
        end
      end
    end
    for _,v in ipairs(invalids) do
      global.fcpus[v] = nil
      global.running[v] = nil
    end
  end,

  ["0.3.10"] = function()
    foreach_fcpu(function(fcpu, state)
      state.breakpoints = state.breakpoints or {}
      state.gui_cache = state.gui_cache or {}
    end)
  end,

  ["0.3.12"] = function()
    foreach_player(function(player, player_data)
      player_data.gui_cache = player_data.gui_cache or {}
    end)
  end,

  ["0.3.15"] = function()
    foreach_fcpu(function(fcpu, state)
      state.gui_cache = state.gui_cache or {}
      state.cache = state.cache or {}

      state.modified = true
      Controller.compile(state)
      Controller.set_program_counter(state, 1)
    end)
  end,

  ["0.3.17"] = function()
    foreach_fcpu(function(fcpu, state)
      state.cache = state.cache or {}
      state.cache.wires = state.cache.wires or {}
      state.cache.control = state.cache.control or {}
      state.cache.control.indication = fcpu.get_control_behavior()
    end)
  end,

  ["0.3.20"] = function()
    global.migrated = nil
    -- Validation {
    global._entity_data = global._entity_data or {}
    for k, v in pairs(global._entity_data) do
      if type(v) == 'table' and (not v.fcpu or not v.fcpu.valid) then
        global._entity_data[k] = nil
      end
    end
    local fcpu2ents = {}
    for k, v in pairs(global._entity_data) do
      if type(v) == 'number' then
        if global.fcpus[v] and global.fcpus[v].entity and global.fcpus[v].entity.valid and global.fcpus[v].entity.unit_number == k then
          -- valid
          fcpu2ents[v] = fcpu2ents[v] or {}
          table.insert(fcpu2ents[v], k)
        else
          global._entity_data[k] = nil
        end
      end
    end
    for _, v in pairs(fcpu2ents) do
      if 1 < #v then
        error('There are more than one entity referencing one fCPU unit.')
      end
    end
    -- }
    foreach_fcpu(function(fcpu, state)
      state.program_text = string.gsub(state.program_text, 'xinc(%s+[^%s]+)', 'xadd%1 1')
      state.program_text = string.gsub(state.program_text, 'xdec(%s+[^%s]+)', 'xsub%1 1')

      if state.program_ast then
        for k,v in pairs(state.program_ast) do
          if v.type == 'ic' then
            if v.name == 'xinc' then
              v.name = 'xadd'
              v.expr[2] = { type='value', count=1 }
            elseif v.name == 'xdec' then
              v.name = 'xsub'
              v.expr[2] = { type='value', count=1 }
            end
          end
        end
      end
    end)
  end,

  ["0.3.23"] = function()
    -- same as in 0.3.17
    foreach_fcpu(function(fcpu, state)
      state.cache = state.cache or {}
      state.cache.wires = state.cache.wires or {}
      state.cache.control = state.cache.control or {}
      state.cache.control.indication = fcpu.get_control_behavior()
    end)
  end,

  ["0.4.0"] = function()
    -- Validation {
    for _, surface in pairs(game.surfaces) do
      for _, fcpu in pairs(surface.find_entities_filtered{ name="fcpu" }) do
        if fcpu and fcpu.valid then
          local index = Entity.get_data(fcpu, nil)
          if index == nil then
            fcpu.destroy()
          end
        end
      end
    end
    -- }
    global.gui_update_on_tick = 0
    global.running = {}
    global.deffered = Heap.new()
    foreach_fcpu(function(fcpu, state)
      if next(state.deffered) ~= nil then
        local sync_at
        for _,v in pairs(state.deffered) do
          local at_tick = game.tick + v.delay
          v.at = game.tick
          Heap.put(global.deffered, at_tick, v)
          if not sync_at or sync_at < at_tick then
            sync_at = at_tick
          end
        end
        if sync_at then
          state.need_sync = true
          Heap.put(global.deffered, sync_at + 1, {action='sync', index=state.index, at=game.tick, delay=sync_at + 1 - game.tick})
        end
        state.deffered = nil
      end
      if state.program_state == PSTATE_SLEEPING then
        global.running[state.index] = nil
        state.sleep_at = game.tick
        Heap.put(global.deffered, game.tick + state.sleep_time, {action='wake', at=game.tick, delay=state.sleep_time, index=state.index})
      elseif state.program_state == PSTATE_RUNNING or not state.disabled then
        state.sleep_time = 0
        global.running[state.index] = state.index
      end
    end)
  end,

  ["0.4.2"] = function()
    -- Validation {
    local valid_ics = {}
    foreach_fcpu(function(fcpu, state)
      for _,v in pairs(state.program_ics) do
        if type(v) == 'table' and not v.unit_number then
          for _,vv in pairs(v) do
            if type(vv) == 'table' and vv.unit_number then
              valid_ics[vv.unit_number] = vv
            end
          end
        elseif v.valid then
          valid_ics[v.unit_number] = v
        end
      end
    end)
    local incorrect_ics = {}
    for _, surface in pairs(game.surfaces) do
      for _, ic in pairs(surface.find_entities_filtered{ name="arithmetic-fcpu" }) do
        if not valid_ics[ic.unit_number] then
          incorrect_ics[#incorrect_ics + 1] = ic
        end
      end
      for _, ic in pairs(surface.find_entities_filtered{ name="constant-fcpu" }) do
        if not valid_ics[ic.unit_number] then
          incorrect_ics[#incorrect_ics + 1] = ic
        end
      end
      for _, ic in pairs(surface.find_entities_filtered{ name="decider-fcpu" }) do
        if not valid_ics[ic.unit_number] then
          incorrect_ics[#incorrect_ics + 1] = ic
        end
      end
      for _, ic in pairs(surface.find_entities_filtered{ name="output-fcpu" }) do
        if not valid_ics[ic.unit_number] then
          incorrect_ics[#incorrect_ics + 1] = ic
        end
      end
    end
    local altered_fcpus = {}
    for _, ic in ipairs(incorrect_ics) do
      local data = Entity.get_data(ic)
      if data and data.fcpu and data.fcpu.valid then
        altered_fcpus[data.fcpu.unit_number] = data.fcpu
      end
      Entity.set_data(ic, nil)
      ic.destroy()
    end
    for _,fcpu in pairs(altered_fcpus) do
      local state = global.fcpus[Entity.get_data(fcpu)]
      if state then
        Controller.verify(state)
        state.modified = true
        Controller.compile(state)
      end
    end
    -- }

    for k, v in pairs(global._entity_data) do
      if type(v) == 'table' and (not v.fcpu or not v.fcpu.valid) then
        global._entity_data[k] = nil
      end
    end
  end,

  ["0.4.7"] = function()
    foreach_fcpu(function(fcpu, state)
      for _,line in pairs(state.program_ast or {}) do
        for _,arg in pairs(line.expr or {}) do
          if arg.type == 'register' and arg.location == 'readonly' then
            if 100 <= arg.addr then
              arg.addr = arg.addr - 100 + MC_REGS_RO_MSLOT
            elseif 9 <= arg.addr then
              arg.addr = arg.addr - 9 + MC_REGS_RO_FIRST
            end
          end
        end
      end
    end)
  end,

  ["0.4.10"] = function()
    foreach_fcpu(function(fcpu, state)
      for _1, line in pairs(state.program_ast or {}) do
        if line.deffer then
          local sync_delay
          for _2, op in pairs(line.deffer) do
            if op.action == 'noop' then
              if not sync_delay or (sync_delay < op.delay) then
                sync_delay = op.delay
              end
              line.deffer[_2] = nil
            end
          end
          if sync_delay then
            table.insert(line.deffer, {action='sync', index=state.index, delay = sync_delay + 1})
          end
          assert(state.program_ics[_1] ~= nil)
          if not line.deffer.run then
            line.deffer = {
              run = line.deffer,
              clr = {
                {action='tune', ic=state.program_ics[_1].kout, value=1, delay = 0},
                {action='tune', ic=state.program_ics[_1].kout, value=0, delay = 1},
              }
            }
          end
        end
      end

      state.program_ics.output = {
        value = state.program_ics.output
      }
      Controller.verify(state)
    end)
  end,

  ["0.4.15"] = function()
    global.unmap = {}
    global.destroy = {}
    foreach_fcpu(function(fcpu, state)
      state.unit_number = fcpu.unit_number

      global.destroy[state.destroy_regnum] = state.index
      global.unmap[state.unit_number] = state.index
      Entity.set_data(state.entity, nil)

      if state.program_ics.output then
        local type = type(state.program_ics.output)
        local mt = getmetatable(state.program_ics.output)
        if type == 'table' and mt == 'private' then
          state.program_ics.output = {
            value = state.program_ics.output
          }
          Controller.verify(state)
        end
      end
    end)
  end,

  ["0.4.17"] = function()
    foreach_fcpu(function(fcpu, state)
      state.memmap = {
        mem1 = {i2s = {}, s2i = {}},
        mem2 = {i2s = {}, s2i = {}},
        mem3 = {i2s = {}, s2i = {}},
        mem4 = {i2s = {}, s2i = {}},
      }
      for _,line in pairs(state.program_ast or {}) do
        for _,address in pairs(line.expr or {}) do
          if address.type == 'memory' then
            address.bank = address.index
            address.index = nil
            address.channel = address.location .. (address.bank or '')
            address.location = nil
          end
        end
      end
    end)
  end,

  ["0.4.18"] = function()
    foreach_player(function(player, player_data)
      GuiWidgetClose(player.index)
    end)
    foreach_fcpu(function(fcpu, state)
      state.power_probe_tick = game.tick
      state.power_level = state.out_of_power and 0 or 1
      state.out_of_power = nil
    end)
  end,
}
