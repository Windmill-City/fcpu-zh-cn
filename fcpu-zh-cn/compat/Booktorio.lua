local wiki_pages

local function fcpu_wiki_booktorio_register(locale_renderer)
  local sections, fulltext = locale_renderer()

  if wiki_pages == nil then
    local topics = {}
    for _, v in ipairs(sections) do
      topics[#topics + 1] = {
        name = v.header,
        localized = false,
        topic = {
          {type = "image", spritename = "fcpu_image_thumbnail"},
          {type = "text", text = v.content ~= '' and v.content or string.lower(v.header) == 'fcpu' and fulltext, localized = false}
        }
      }
    end

    wiki_pages = {
      name = 'fCPU',
      localized = false,
      specified_version = 0,
      topics = topics
    }
  end
end

local function fcpu_wiki_booktorio_init()
  if remote.interfaces["Booktorio"] then
    remote.call("Booktorio", "add_thread", wiki_pages)
  end
end

--return remote.interfaces["Booktorio"]
return {
  wiki_register = fcpu_wiki_booktorio_register,
  on_init = fcpu_wiki_booktorio_init,
  on_configuration_changed = fcpu_wiki_booktorio_init,
}