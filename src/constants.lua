MC_DEBUG = __DebugAdapter ~= nil and settings.startup['fcpu-debug-enabled'].value
MC_FACTORIO2 = storage ~= nil

MC_OUTPUT = 256
MC_LINES = settings.startup['fcpu-program-lines'].value
MC_REGS = 8 -- used for GUI preview
MC_REGS_EXT = 64
MC_REGS_RO_FIRST = 1000
MC_REGS_RO_MSLOT = 2000
MC_MEMORY_CHANNELS = 4
MC_MEMORY_SLOTS_MIN = 8
MC_BROWNOUT_LEVEL = 0.4

MC_SECTIONS_MAX = 101