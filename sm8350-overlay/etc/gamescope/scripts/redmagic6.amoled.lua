-- REDMAGIC 6 (Nubia NX669J) internal AMOLED (1080x2400 portrait, 144 Hz).
--
-- The panel driver (panel-nubia-nx669j) lists 144/120/90/60 Hz. Unlike the
-- Pocket FIT's video-mode panel these are not one timing with a stretched
-- front porch: it is a command-mode panel with a separate init sequence per
-- rate, all with the same timings and a pixel clock scaled to the rate.
-- The driver picks the sequence from the mode's refresh, so the generated
-- mode only has to carry the right clock.
--
-- The DSI panel has no EDID, so match on the device-tree model instead.

local redmagic6_refresh_rates = { 60, 90, 120, 144 }
-- htotal 1080+100+8+100, vtotal 2400+24+2+16 (stock NX669J timings)
local HTOTAL, VTOTAL = 1288, 2442

local function is_redmagic6()
    local ok, f = pcall(io.open, "/sys/firmware/devicetree/base/model", "r")
    if not ok or not f then return false end
    local model = f:read("*a") or ""
    f:close()
    return model:find("REDMAGIC 6", 1, true) ~= nil
end

gamescope.config.known_displays.redmagic6_amoled = {
    pretty_name = "REDMAGIC 6 AMOLED",
    dynamic_refresh_rates = redmagic6_refresh_rates,
    hdr = {
        -- The stock stack advertises HDR (qcom,mdss-dsi-panel-hdr-enabled,
        -- ~420 nits peak) but nothing here drives the panel's HDR mode yet.
        supported = false,
        force_enabled = false,
        eotf = gamescope.eotf.gamma22,
        max_content_light_level = 420,
        max_frame_average_luminance = 420,
        min_content_light_level = 0.0
    },
    dynamic_modegen = function(base_mode, refresh)
        local mode = base_mode
        mode.clock = math.floor(HTOTAL * VTOTAL * refresh / 1000 + 0.5)
        mode.vrefresh = gamescope.modegen.calc_vrefresh(mode)
        debug("[redmagic6_amoled] "..refresh.."Hz: clock "..mode.clock)
        return mode
    end,
    matches = function(display)
        if (display.vendor or "") == "" and (display.model or "") == "" and is_redmagic6() then
            debug("[redmagic6_amoled] Matched EDID-less REDMAGIC 6 panel")
            return 5000
        end
        return -1
    end
}
debug("Registered REDMAGIC 6 AMOLED as a known display")
