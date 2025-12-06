-- Predefined signals
---@type Signal
NULL_SIGNAL = { signal = nil, count = 0 }
---@type Signal
HALT_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-halt" }, count = 1 }
---@type Signal
RUN_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-run" }, count = 1 }
---@type Signal
STEP_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-step" }, count = 1 }
---@type Signal
SLEEP_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-sleep" }, count = 1 }
---@type Signal
JUMP_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-jump" }, count = 1 }
