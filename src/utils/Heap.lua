local Heap = {}

function Heap.put(h, p, v)
  local q = h[p]
  if not q then
    q = {first = 1, last = 0}
    h[p] = q
  end
  q.last = q.last + 1
  q[q.last] = v
end

function Heap.pop(h)
  for p, q in pairs(h) do
    if q.first <= q.last then
      local v = q[q.first]
      q[q.first] = nil
      q.first = q.first + 1
      return p, v
    else
      h[p] = nil
    end
  end
end

function Heap.empty(h) -- TODO: optimize or remove
  for p, q in pairs(h) do
    if q.first <= q.last then
      return false
    end
  end
  return true
end

function Heap.new()
  return {}
end

--[[
  local pq = Heap.new()
local tasks = {
    {3, 'Clear drains'},
    {4, 'Feed cat'},
    {5, 'Make tea'},
    {1, 'Solve RC tasks'},
    {2, 'Tax return'}
}
for _, task in ipairs(tasks) do
  __DebugAdapter.print(string.format("Putting: %d - %s", table.unpack(task)))
  Heap.put(pq, table.unpack(task))
end
while not Heap.empty(pq) do
  local prio, task = Heap.pop(pq)
  __DebugAdapter.print(string.format("Popped: %d - %s", prio, task))
end
]]

return Heap
