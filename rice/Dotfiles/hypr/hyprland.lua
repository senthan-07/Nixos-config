-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")

---- MONITORS ----
require("Monitors.monitor")

---- WINDOWS AND WORKSPACES ----
require("Monitors.windowrules")

---- AUTOSTART ----
require("Startup.autostart")

---- LOOK AND FEEL ----
require("Looks.look")

----  MISC  ----
require("Looks.misc")

---- INPUT ----
require("Inputs.inputs")

---- KEYBINDINGS ----
require("Inputs.keybind")

---- RICE SHELL ----
require("Rice.rice")
require("Rice.colors")   -- wallpaper border colours; after Looks.look so it overrides them


