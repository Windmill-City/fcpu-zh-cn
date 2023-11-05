local state
local ioLognet = {}

-- Logistic
function ioLognet.find_item(signal_to_find)
  if signal_to_find then
    local lognet = state.cache.lognet
    if not lognet then
      Assert.exception("Tried to access logistic network while it is unreachable")
    end
    local count = lognet.get_item_count(signal_to_find)
    return count
  end
end

function ioLognet.content_size()
  return state.cache.lognet and table_size(state.cache.lognet.get_contents()) or 0
end

function ioLognet.bind(state_)
  state = state_
end

return ioLognet
