---@class OpRef_Base

---@class (exact) OpRef_Comment : OpRef_Base
---@field type 'nop'
---@field name 'comment'

---@class (exact) OpRef_Abstract : OpRef_Base
---@field type string

---@class (exact) OpRef_Label : OpRef_Base
---@field type 'label'
---@field label string

---@class (exact) OpRef_Number : OpRef_Base
---@field type 'value'
---@field count int32

---@class (exact) OpRef_String : OpRef_Base
---@field type 'string'
---@field str string

---@class (exact) OpRef_Type : OpRef_Base
---@field type 'type'
---@field signal SignalID

---@class (exact) OpRef_Signal : OpRef_Base, Signal
---@field type 'signal'

---@alias OpRef_Constant OpRef_Signal | Signal | OpRef_Number | OpRef_String | OpRef_Type

---@class (exact) OpRef_Address : OpRef_Base
---@field type 'lognet' | 'reference' | 'register' | 'memory' | 'wire'
---@field addr integer?
---@field pointer boolean

---@class (exact) OpRef_LogNet : OpRef_Address
---@field type 'lognet'

---@class (exact) OpRef_Reference : OpRef_Address
---@field type 'reference'

---@class (exact) OpRef_Register : OpRef_Address
---@field type 'register'

---@class (exact) OpRef_Special : OpRef_Register
---@field special boolean

---@class (exact) OpRef_Channel : OpRef_Base
---@field type 'channel'
---@field channel string

---@class (exact) OpRef_MemoryBank : OpRef_Base
---@field type 'memory'
---@field channel string
---@field bank number?

---@class (exact) OpRef_Memory : OpRef_MemoryBank, OpRef_Address

---@class (exact) OpRef_Wire : OpRef_Address
---@field type 'wire'
---@field color string

---@alias OpRefType
---|'nop'
---|'label'
---|'value'
---|'string'
---|'type'
---|'signal'
---|'lognet'
---|'reference'
---|'register'
---|'channel'
---|'memory'
---|'wire'
---|'output'
---|'input'

---@alias OpRef
---| OpRef_Comment
---| OpRef_Abstract
---| OpRef_Label
---| OpRef_Constant
---| OpRef_Address
---| OpRef_Special
---| OpRef_LogNet
---| OpRef_Reference
---| OpRef_Register
---| OpRef_Channel
---| OpRef_MemoryBank
---| OpRef_Memory
---| OpRef_Wire

---@class Emitter
local Emitter = {

  ---@return OpRef_Comment
  make_comment = function()
    return { type = 'nop', name = 'comment' } ---@type OpRef_Comment
  end,

  ---@param type string
  ---@return OpRef_Abstract
  make_abstract = function(type)
    return { type = type } ---@type OpRef_Abstract
  end,


  ---@param label string
  ---@return OpRef_Label
  make_label = function(label)
    return { type = 'label', label = label } ---@type OpRef_Label
  end,


  ---@param numstr string
  ---@return OpRef_Number
  make_value = function(numstr)
    local number = tonumber(numstr)
    if number == nil then
      Assert.exception("Can't parse number '".. numstr .."'")
    end
    return { type = 'value', count = number } ---@type OpRef_Number
  end,

  ---@param str string
  ---@return OpRef_String
  make_string = function(str)
    return { type = 'string', str = str } ---@type OpRef_String
  end,

  ---@param signal_id SignalID
  ---@return OpRef_Type
  make_type = function(signal_id)
    return { type = 'type', signal = signal_id } ---@type OpRef_Type
  end,

  ---@param signal_id SignalID
  ---@param countstr string | number
  ---@return OpRef_Signal
  make_signal = function(signal_id, countstr)
    local count = tonumber(countstr)
    if count == nil then
      Assert.exception("Can't parse number '".. (countstr or 'nil') .."'")
    end
    return { type = 'signal', signal = signal_id, count = count or 0 } ---@type OpRef_Signal
  end,

  ---@param addr integer
  ---@return OpRef_Special
  make_special_register_ro = function(addr)
    return { type = 'register', special = true, addr = tonumber(addr), pointer = false } ---@type OpRef_Special
  end,

  ---@param addr integer
  ---@param is_ptr boolean
  ---@return OpRef_LogNet
  make_lognet = function(addr, is_ptr)
    return { type = 'lognet', addr = tonumber(addr), pointer = is_ptr } ---@type OpRef_LogNet
  end,

  ---@param addr integer
  ---@param is_ptr boolean
  ---@return OpRef_Reference
  make_reference = function(addr, is_ptr)
    Assert.check(addr ~= nil)
    return { type = 'reference', addr = tonumber(addr), pointer = is_ptr } ---@type OpRef_Reference
  end,

  ---@param name string?
  ---@param ref OpRef_Reference
  ---@return OpRef_Register
  make_register = function(name, ref) -- +[reference]
    return { type = 'register', addr = ref.addr, pointer = ref.pointer } ---@type OpRef_Register
  end,

  ---@param name string
  ---@return OpRef_Channel
  make_channel = function(name)
    return { type = 'channel', channel = name } ---@type OpRef_Channel
  end,

  --make_channel_ref = function(name, ref) -- +[reference]
  --  return { type = 'channel', channel = name, addr = ref.addr, pointer = ref.pointer } ---@type OpRef
  --end,

  ---@param name string
  ---@param bank integer|string
  ---@return OpRef_MemoryBank
  make_memory_bank = function(name, bank) -- +[channel]
    return { type = 'memory', channel = name..bank, bank = tonumber(bank) } ---@type OpRef_MemoryBank
  end,

  ---@param name string
  ---@param bank integer|string
  ---@param ref OpRef_Reference
  ---@return OpRef_Memory
  make_memory = function(name, bank, ref) -- +[memory_bank, reference]
    return { type = 'memory', channel = name..bank, bank = tonumber(bank), addr = ref.addr, pointer = ref.pointer } ---@type OpRef_Memory
  end,

  ---@param name string
  ---@param ref OpRef_Reference
  ---@return OpRef_Wire
  make_wire = function(name, ref)
    return { type = 'wire', color = name, addr = ref.addr, pointer = ref.pointer} ---@type OpRef_Wire
  end,
}

return Emitter
