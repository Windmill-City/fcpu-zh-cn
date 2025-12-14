local Errors = {
  TypeIsNotSupported = function(t) return { 'fcpu-errors.type-is-not-supported', t } end,
  UnknownRegister = function(name) return { 'fcpu-errors.unknown-register', name } end,
  CantParseNumber = function(numstr) return { 'fcpu-errors.cant-parse-number', numstr } end,
  UnknownOpcode = function(name) return { 'fcpu-errors.unknown-opcode', name } end,
  UnableToParse = function(str) return { 'fcpu-errors.unable-to-parse', str } end,
  ExpectedOpcodeButRead = function(t) return { 'fcpu-errors.expected-opcode-but-read', t } end,
  WritingUnsupported = function() return { 'fcpu-errors.writing-unsupported' } end,
  UnexpectedType = function(name) return { 'fcpu-errors.unexpected-type', name } end,
  ReadingNil = function(name) return { 'fcpu-errors.reading-nil', name } end,
  UnknownLabel = function(label) return { 'fcpu-errors.unknown-label', label } end,
  WritingToUnknownWire = function(wire) return { 'fcpu-errors.writing-to-unknown-wire', wire } end,
  UnknownMemoryBank = function(bank) return { 'fcpu-errors.unknown-memory-bank', bank } end,
  UnknownChannel = function(channel) return { 'fcpu-errors.unknown-channel', channel } end,
  NotConnectedWire = function(wire) return { 'fcpu-errors.not-connected-wire', wire } end,
  NotConnectedLognet = function() return { 'fcpu-errors.not-connected-lognet', } end,
  ScalarMemoryFull = function(n) return { 'fcpu-errors.scalar-memory-full', n } end,
  UnknownRegisterWithIndex = function(index) return { 'fcpu-errors.unknown-register-with-index', index } end,
  UnknownPrototypeGroup = function(type_name) return { 'fcpu-errors.unknown-prototype-group', type_name } end,
  UnknownPrototype = function(name) return { 'fcpu-errors.unknown-prototype', name } end,
}

return Errors
