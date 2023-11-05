-- Predefined signals
NULL_SIGNAL = { signal = nil, count = 0 }
HALT_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-halt" }, count = 1 }
RUN_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-run" }, count = 1 }
STEP_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-step" }, count = 1 }
SLEEP_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-sleep" }, count = 1 }
JUMP_SIGNAL = { signal = { type = "virtual", name = "signal-fcpu-jump" }, count = 1 }
