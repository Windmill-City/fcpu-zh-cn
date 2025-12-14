local Errors = {
  TypeIsNotSupported = function(t) return "A signal of type '" .. t .. "' is not supported" end,
  UnknownRegister = function(name) return "Unknown register `" .. name .. "`" end,
  CantParseNumber = function(numstr) return "Can't parse the number '" .. numstr .. "'" end,
  UnknownOpcode = function(name) return "Unknown opcode: " .. name .. "" end,
  UnableToParse = function(str) return "Unable to parse code: " .. str .. "" end,
  ExpectedOpcodeButRead = function(t) return "Expected an opcode, but instead read a " .. t .. "" end,
  WritingUnsupported = function() return "This memory channel does not support writing" end,
  UnexpectedType = function(name) return "Unexpected type: " .. name .. "" end,
  ReadingNil = function(name) return "Attempted to retrieve a nil value for " .. name .. "" end,
  UnknownLabel = function(label) return "The label '" .. label .. "' could not be found" end,
  WritingToUnknownWire = function(wire) return "Could not write to the " .. wire .. " input wire" end,
  UnknownMemoryBank = function(bank) return "Memory bank " .. bank .. " does not exist" end,
  UnknownChannel = function(channel) return "Channel " .. channel .. " does not exist" end,
  NotConnectedWire = function(wire) return "Tried to access the " .. wire .. " wire while it is not connected" end,
  NotConnectedLognet = function() return "Tried to access the logistic network while it is unreachable" end,
  ScalarMemoryFull = function(n) return "The scalar memory block is already full (maximum " .. n .. " items)" end,
  UnknownRegisterWithIndex = function(index) return "Unknown register with internal index " .. index .. "" end,
  UnknownPrototypeGroup = function(type_name) return "Unknown prototype group specified: " .. type_name .. "" end,
  UnknownPrototype = function(name) return "Unknown prototype specified: " .. name .. "" end,
}

return Errors
