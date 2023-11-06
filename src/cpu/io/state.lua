local State = {
  current = false,
  callbacks = {}
}

function State.bind(state)
  State.current = state
  for _,cb in ipairs(State.callbacks) do
    cb(State.current)
  end
end

function State.onBind(proc)
  table.insert(State.callbacks, proc)
end

if fcpu_debug_enabled then
  setmetatable(State, {
    __index = { current = State.current, bind = State.bind },
    __newindex = function(self, i, v)
      if self.current then
        error('State.current is readonly', 2)
      else
        self.current = v
      end
    end
  })
end

return State
