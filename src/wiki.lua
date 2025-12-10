local have_informatron = Compatibility['informatron']
local have_booktorio = Compatibility['Booktorio']

if have_informatron or have_booktorio then
  local Source_readme = require('src/wiki/readme.src.lua')
  local md2frt = require('src/wiki/md2frt')

  local fulltext
  local mdstate

  fulltext, mdstate = md2frt.render(Source_readme)
  local sections = md2frt.renderSections(mdstate)

  Compatibility.wiki_register(sections, fulltext)
end

---@param e {player_index:int32, old_locale:string, name:string, tick:int32}
function on_player_locale_changed(e)
  local player = game.players[e.player_index]
end

script.on_event(defines.events.on_player_locale_changed, on_player_locale_changed)
