--------------------
---- RICE SHELL ----
--------------------

-- Quickshell desktop shell from ~/Modules/nixos/rice (installed by rice.nix).
-- Every panel is driven through `rice ipc call <target> <function>`;
-- `rice ipc show` lists all targets.

hl.on("hyprland.start", function ()
    hl.exec_cmd("rice")
    -- Clipboard history for the launcher (SUPER + C).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- ~/.config/autostart entries (Settings > Autostart).
    hl.exec_cmd("dex -a -e Hyprland")
end)

local mainMod = "SUPER"
local ipc = function (target, fn)
    return hl.dsp.exec_cmd("rice ipc call " .. target .. " " .. fn)
end

-- Panels
hl.bind(mainMod .. " + R",          ipc("launcher", "toggle"))
hl.bind(mainMod .. " + W",              ipc("launcher", "wallpapers"))
hl.bind(mainMod .. " + C",              ipc("spotlight", "clipboard"))
hl.bind(mainMod .. " + PERIOD",         ipc("spotlight", "emoji"))
hl.bind(mainMod .. " + SHIFT + F",      ipc("spotlight", "files"))
hl.bind(mainMod .. " + SLASH",          ipc("spotlight", "help"))       -- every keybind, searchable
hl.bind(mainMod .. " + N",              ipc("sidebar", "toggle"))
hl.bind(mainMod .. " + A",              ipc("dashboard", "toggle"))
hl.bind(mainMod .. " + I",              ipc("island", "toggle"))
hl.bind(mainMod .. " + SHIFT + M",      ipc("island", "media"))
hl.bind(mainMod .. " + SHIFT + P",      ipc("island", "timer"))
hl.bind(mainMod .. " + SHIFT + T",      ipc("island", "tools"))
hl.bind(mainMod .. " + COMMA",          ipc("settings", "open"))
hl.bind(mainMod .. " + SHIFT + R",      ipc("shell", "reload"))         -- reload rice
hl.bind(mainMod .. " + ESCAPE",         ipc("power", "toggle"))
hl.bind(mainMod .. " + L",              ipc("lock", "lock"))

-- Window switcher: hold Alt, tap Tab to move, release Alt to switch.
hl.bind("ALT + TAB",                    ipc("switcher", "next"))
hl.bind("ALT + SHIFT + TAB",            ipc("switcher", "prev"))
hl.bind("ALT + ALT_L",                  ipc("switcher", "commit"), { release = true })

-- Desktop
hl.bind(mainMod .. " + D",              ipc("dock", "toggleAutohide"))
hl.bind(mainMod .. " + SHIFT + E",      ipc("desktop", "editToggle"))
hl.bind(mainMod .. " + SHIFT + D",      ipc("theme", "toggleDark"))
hl.bind(mainMod .. " + SHIFT + N",      ipc("notifs", "toggleDnd"))
hl.bind(mainMod .. " + SHIFT + B",      ipc("nightlight", "toggle"))

-- Capture
hl.bind("Print",                        ipc("capture", "region"))
hl.bind("SHIFT + Print",                ipc("capture", "screen"))
hl.bind(mainMod .. " + SHIFT + X",      ipc("capture", "region"))
hl.bind(mainMod .. " + SHIFT + W",      ipc("capture", "window"))
hl.bind(mainMod .. " + SHIFT + O",      ipc("capture", "ocr"))
hl.bind(mainMod .. " + SHIFT + C",      ipc("capture", "pick"))
hl.bind(mainMod .. " + CTRL + R",       ipc("capture", "recordRegion"))
hl.bind(mainMod .. " + ALT + R",        ipc("capture", "record"))
hl.bind(mainMod .. " + ALT + A",        ipc("capture", "recordAudio"))

-- The settings app is a normal window; keep it floating and centred.
hl.window_rule({
    name  = "rice-settings",
    match = { class = "^org.quickshell$", title = "^Rice Settings$" },

    float  = true,
    size   = "1080 720",
    center = true,
})

-- Screen capture overlay must appear/disappear instantly.
hl.layer_rule({
    name    = "rice-capture-no-anim",
    match   = { namespace = "^rice-capture$" },
    no_anim = true,
})
