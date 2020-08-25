if mods['informatron'] then
    informatron_make_image("fcpu_image_thumbnail", "__fcpu__/thumbnail.png", 145, 145)
end

if mods['Booktorio'] then
    data:extend({
        {
            type     = "sprite",
            name     = "fcpu_image_thumbnail",
            filename = "__fcpu__/thumbnail.png",
            width    = 145,
            height   = 145,
            scale    = 1.0
        }
    })
end
