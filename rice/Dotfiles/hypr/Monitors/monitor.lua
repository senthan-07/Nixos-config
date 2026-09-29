
------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output    = "HDMI-A-1",
    mode      = "2560x1440@144.00",
    position  = "0x0",
    scale     = 1,
    transform = 0,
})



-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output    = "eDP-1",
    mode      = "1920x1080@165.00",
    position  = "2560x0",
    scale     = 1,
    transform = 0,
})

---- PER-MONITOR WORKSPACES ----
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1", persistent = true })
end
for i = 6, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", persistent = true })
end