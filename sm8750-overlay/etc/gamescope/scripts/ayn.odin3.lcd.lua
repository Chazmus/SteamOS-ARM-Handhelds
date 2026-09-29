-- AYN Odin 3 internal AMOLED panel (1080x1920, native 120 Hz).
-- Provides dynamic refresh rate support (60 Hz / 120 Hz) for Steam Game Mode.

local odin3_refresh_rates = { 60, 120 }

local function is_odin3()
    local ok, f = pcall(io.open, "/sys/firmware/devicetree/base/model", "r")
    if not ok or not f then return false end
    local model = f:read("*a") or ""
    f:close()
    return model:find("AYN Odin 3", 1, true) ~= nil or model:find("Odin 3", 1, true) ~= nil
end

gamescope.config.known_displays.ayn_odin3_lcd = {
    pretty_name = "AYN Odin 3 AMOLED",
    dynamic_refresh_rates = odin3_refresh_rates,
    hdr = {
        supported = false,
        force_enabled = false,
        eotf = gamescope.eotf.gamma22,
        max_content_light_level = 600,
        max_frame_average_luminance = 600,
        min_content_light_level = 0.0
    },
    matches = function(display)
        if is_odin3() then
            debug("[ayn_odin3_lcd] Matched AYN Odin 3 device model")
            return 5000
        end
        return -1
    end
}
debug("Registered AYN Odin 3 AMOLED as a known display")
