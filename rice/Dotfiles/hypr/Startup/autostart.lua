-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor: Bibata (package bibata-cursors in rice.nix). Other variants:
-- Bibata-Modern-Ice (white), Bibata-Modern-Amber, Bibata-Original-* (sharp tips).
local cursorTheme = "Bibata-Modern-Classic"
local cursorSize  = "24"
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_SIZE", cursorSize)

-- The env vars above are all Hyprland needs. GTK/libadwaita apps read the
-- cursor from gsettings instead (shared with GNOME), so set it there too.
hl.on("hyprland.start", function ()
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. cursorTheme)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. cursorSize)
end)

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")