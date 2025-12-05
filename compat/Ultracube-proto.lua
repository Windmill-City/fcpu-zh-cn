--[[ Need to remove compatibility from __Ultracube__/updates/compatibility/fcpu.lua

local fcpu_recipe = data.raw['recipe']['fcpu']

fcpu_recipe.category = 'cube-fabricator-handcraft'
fcpu_recipe.enabled = false
for i, ingredient in ipairs(fcpu_recipe.ingredients) do
    if ingredient.name == 'processing-unit' then
    ingredient.name = 'cube-spectral-processor'
    end
end

local fcpu_item = data.raw['item']['fcpu']

fcpu_item.subgroup = "cube-combinator-extra"
fcpu_item.order = "cube-" .. fcpu_item.order

local fcpu_technology = data.raw['technology']['fcpu']

fcpu_technology.prerequisites = { 'cube-combinatorics', 'cube-spectral-processor' }
fcpu_technology.unit = tech_cost_unit('2', 200)

--[[]]
