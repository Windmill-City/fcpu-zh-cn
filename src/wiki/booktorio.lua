local wiki_pages

function fcpu_wiki_booktorio_register(sections, fulltext)
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

function fcpu_wiki_booktorio_init()
  if remote.interfaces["Booktorio"] then
    remote.call("Booktorio", "add_thread", wiki_pages)
  end
end

return remote.interfaces["Booktorio"]
