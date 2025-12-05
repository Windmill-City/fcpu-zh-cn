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
