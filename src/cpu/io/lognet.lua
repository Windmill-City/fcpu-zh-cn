local state
local ioRegister
local ioLognet = {}

-- Logistic
local function lognet_getchannel_contents()
  local lognet = state.cache.wires.lognet
  if not lognet then
    Assert.exception(Errors.NotConnectedLognet())
  end
  return lognet.signals
end

function ioLognet.get(address)
  local contents = lognet_getchannel_contents()
  if contents then
    local addr = ioRegister.addr_deref(address)
    return contents[addr] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function ioLognet.find_item(signal_to_find)
  if signal_to_find then
    local lognet = state.cache.wires.lognet
    if not lognet then
      Assert.exception(Errors.NotConnectedLognet())
    end
    local count = lognet.get_signal(signal_to_find)
    return count
  end
end

---@return integer
function ioLognet.content_size()
  return state.cache.wires.lognet and table_size(state.cache.wires.lognet.signals) or 0
end

function ioLognet.bind(state_)
  state = state_
end

function ioLognet.setup(ioRegister_)
  ioRegister = ioRegister_
end

return ioLognet
