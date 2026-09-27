---------------------------
---- RICE BORDER COLOURS ----
---------------------------

-- Window border colours that follow the wallpaper. rice renders
-- ./wallpaper-colors.lua (next to this file) with matugen (template
-- rice/matugen/templates/hypr-colors.lua) and runs `hyprctl reload` after
-- every wallpaper change. Until that file exists, or if it cannot be read,
-- nothing here applies and the colours from Looks/look.lua stay in effect.
--
-- Require this after Looks.look so it overrides those colours.

local function state_dir()
    local getenv = os and os.getenv
    if not getenv then return nil end
    local state = getenv("XDG_STATE_HOME")
    if state == nil or state == "" then
        local home = getenv("HOME")
        if home == nil or home == "" then return nil end
        state = home .. "/.local/state"
    end
    return state .. "/rice"
end

local function load_colors(path)
    if dofile then
        local ok, result = pcall(dofile, path)
        if ok then return result end
    end
    -- Fallback for sandboxes without dofile.
    if io and io.open and load then
        local file = io.open(path, "r")
        if not file then return nil end
        local source = file:read("*a")
        file:close()
        local chunk = load(source, "@" .. path, "t", {})
        if not chunk then return nil end
        local ok, result = pcall(chunk)
        if ok then return result end
    end
    return nil
end

-- Generated next to this file (Dotfiles/hypr/Rice/wallpaper-colors.lua);
-- older rice versions wrote it to the state dir.
local function config_dir()
    local getenv = os and os.getenv
    if not getenv then return nil end
    local conf = getenv("XDG_CONFIG_HOME")
    if conf == nil or conf == "" then
        local home = getenv("HOME")
        if home == nil or home == "" then return nil end
        conf = home .. "/.config"
    end
    return conf .. "/hypr/Rice"
end

local cdir, sdir = config_dir(), state_dir()
local c = (cdir and load_colors(cdir .. "/wallpaper-colors.lua"))
    or (sdir and load_colors(sdir .. "/hypr-colors.lua"))

if type(c) == "table" and type(c.active_border) == "table" and type(c.inactive_border) == "string" then
    local ok, err = pcall(hl.config, {
        general = {
            col = {
                active_border   = { colors = c.active_border, angle = 45 },
                inactive_border = c.inactive_border,
            },
        },
    })
    if not ok and print then
        print("rice colors.lua: could not apply border colours: " .. tostring(err))
    end
end
