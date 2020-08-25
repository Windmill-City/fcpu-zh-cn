local have_informatron = require('src/wiki/informatron.lua')
local have_booktorio = require('src/wiki/booktorio.lua')

if have_informatron or have_booktorio then
    local Source_readme = require('src/wiki/readme.src.lua')
    local md2frt = require('src/wiki/md2frt')

    local fulltext
    local mdstate

    fulltext, mdstate = md2frt.render(Source_readme)
    local sections = md2frt.renderSections(mdstate)

    if have_informatron then
        fcpu_wiki_informatron_register(sections, fulltext)
    end
    if have_booktorio then
        fcpu_wiki_booktorio_register(sections, fulltext)
    end
end
