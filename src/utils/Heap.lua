local floor = math.floor

local function swim(h)
  local heap = h.heap
  local i = h.size
  while floor(i / 2) > 0 do
    local half = floor(i / 2)
    if heap[i][1] < heap[half][1] then
      heap[i], heap[half] = heap[half], heap[i]
    end
    i = half
  end
end

local function min_child(h, i)
  if (i * 2) + 1 > h.size then
    return i * 2
  else
    if h.heap[i * 2][1] < h.heap[i * 2 + 1][1] then
      return i * 2
    else
      return i * 2 + 1
    end
  end
end

local function sink(h)
  local size = h.size
  local heap = h.heap
  local i = 1
  while (i * 2) <= size do
    local mc = min_child(h, i)
    if heap[i][1] > heap[mc][1] then
      heap[i], heap[mc] = heap[mc], heap[i]
    end
    i = mc
  end
end

local Heap = {}

function Heap.new()
  return {
    heap = {},
    size = 0
  }
end

function Heap.empty(h)
  return h.size == 0
end

function Heap.size(h)
  return h.size
end

function Heap.put(h, p, v)
  h.heap[h.size + 1] = {p, v}
  h.size = h.size + 1
  swim(h)
end

function Heap.pop(h)
  local heap = h.heap
  local retval = heap[1]
  heap[1] = heap[h.size]
  heap[h.size] = nil
  h.size = h.size - 1
  sink(h)
  return retval[1], retval[2]
end

function Heap.priority(h)
  return 0 < h.size and h.heap[1][1] or nil
end

return Heap
