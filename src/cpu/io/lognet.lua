local state
local ioLognet = {}

-- Logistic
function ioLognet.content_size()
  return state.cache.lognet and table_size(state.cache.lognet.get_contents()) or 0
end

function ioLognet.bind(state_)
  state = state_
end

return ioLognet
