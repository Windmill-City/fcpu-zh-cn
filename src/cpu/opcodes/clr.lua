local function clr_cl(io)
  local ics_clear = function(channel)
    local action = { type = 'deffer', deffer = {} }
    local ClearIC = function(ast)
      if ast.deffer and ast.deffer.clr then
        for _, v in ipairs(ast.deffer.clr) do
          action.deffer[#action.deffer + 1] = v
        end
      end
    end
    io.ics_each_ast(ClearIC, channel)
    return action
  end

  return function(_)
    local actions = {}
    if _ and  0 < #_ then
      for i, address in ipairs(_) do
        if address then
          Assert.type(address, {'register', 'memory', 'output'})
          if address.type == 'register' then
            if address.addr then
              io.register_set(address, NULL_SIGNAL)
            else
              for i = 1, MC_REGS_EXT do
                io.register_set({type='register', addr=i, pointer=false}, NULL_SIGNAL)
              end
            end
          elseif address.color == 'out' then
            if address.addr == nil then
              actions[#actions + 1] = io.output_clear()
            else
              io.wire_set(address, nil)
            end
          elseif address.type == 'memory' then
            if address == nil or address.bank == nil then
              io.memory_clear_all()
            else
              io.memory_clear(address)
            end
            actions[#actions + 1] = ics_clear(address.bank and address.channel)
          end
        end
      end
    else
      for i = 1, MC_REGS_EXT do
        io.register_set({type='register', addr=i, pointer=false}, NULL_SIGNAL)
      end
      io.control_set(table.deep_copy(NULL_SIGNAL))
      io.memory_clear_all()
      actions[#actions + 1] = io.output_clear()
      actions[#actions + 1] = ics_clear()
      actions[#actions + 1] = io.stack_clear()
    end
    -- TODO: implement return {type='actions', ...}
    if 0 < #actions then
      local d = {type='deffer', deffer={}}
      local s = 0
      for _, a in ipairs(actions) do
        if a and a.deffer then
          for _, v in ipairs(a.deffer) do
            if s < v.delay then
              s = v.delay
            end
            table.insert(d.deffer, v)
          end
        end
      end
      table.insert(d.deffer, {action='sync', delay=s + 1, index=State.current.index})
      return d
    end
  end
end

return clr_cl