-- [[ 
--    scripts/hdr_detect.lua
--    VERSION: v1.7.4 (Universal Linux HDR - Smooth Messages)
--    LOGIC:
--      1. Detect HDR Video.
--      2. If Linux/KDE, Probe Passthrough immediately.
--      3. Show "Probing..." then "Active" once the handshake completes.
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_state = nil 
local os_hdr_state = false 
local manual_override = false 

-- [NEW] Config Path
local hdr_conf_path = mp.command_native({"expand-path", "~~/script-opts/hdr-mode.conf"})

-- [NEW] Helper to read the user's saved preference
local function get_saved_tone_mapping()
    local mode = "bt.2390" -- Default fallback if file missing
    local f = io.open(hdr_conf_path, "r")
    if f then
        for line in f:lines() do
            local v = line:match("tone_mapping=(%S+)")
            if v then mode = v end
        end
        f:close()
    end
    return mode
end

-- OSD Colors
local C = {
    GREEN  = "{\\c&H00FF00&}", 
    BLUE   = "{\\c&HFFFF00&}",
    RED    = "{\\c&H0000FF&}",
    WHITE  = "{\\c&HFFFFFF&}",
    ORANGE = "{\\c&H0080FF&}"
}

function show_hdr_osd(text)
    overlay.data = "{\\an9}{\\fs26}" .. text
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(4, function() overlay:remove() end)
end

-- --------------------------------------------------------------------------
-- 1. DETECT OS HDR STATUS
-- --------------------------------------------------------------------------
local function check_hdr_status()
    -- Windows WMI Check
    if mp.get_property("platform") == "windows" then
        local cmd = 'powershell -NoProfile -Command "try { (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorAdvancedColorProperties -ErrorAction Stop).AdvancedColorEnabled } catch { Write-Output \'Fallback\' }"'
        local res = utils.subprocess({
            args = {"powershell", "-NoProfile", "-Command", cmd},
            playback_only = false,
            capture_stdout = true
        })
        if res.status == 0 and res.stdout then
            local output = res.stdout:gsub("%s+", "")
            if output == "True" then return true 
            elseif output == "False" then return false end
        end
    end

    -- Universal display-params check
    local d = mp.get_property_native("display-params")
    if d then
        if d.primaries == "bt.2020" or d.primaries == "dci-p3" or d.gamma == "pq" or d.gamma == "st2084" then
            return true
        end
    end
    
    -- Linux Fallback: Always Probe first
    if mp.get_property("platform") ~= "windows" then
        return "probe" 
    end

    return false
end

-- --------------------------------------------------------------------------
-- 2. EVALUATE LOGIC
-- --------------------------------------------------------------------------
function evaluate_hdr_state()
    if manual_override then return end

    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")

    if not is_hdr_video then 
        if last_state ~= "sdr" then
            mp.set_property("target-colorspace-hint", "no")
            last_state = "sdr"
        end
        return 
    end

    local hdr_check = check_hdr_status()
    local is_os_hdr = (hdr_check == true or hdr_check == "probe")
    local target = is_os_hdr and "passthrough" or "tonemap"

    if target == "passthrough" then
        if last_state ~= "passthrough" then
            mp.set_property("target-colorspace-hint", "yes")
            mp.set_property("target-trc", "auto")
            mp.set_property("tone-mapping", "auto")
            show_hdr_osd(C.GREEN .. "HDR Mode: " .. C.WHITE .. "Passthrough (Probing...)")
            
            -- Visual Confirmation after 1.8 seconds (KDE Handshake Time)
            mp.add_timeout(1.8, function()
                if not manual_override and last_state == "passthrough" then
                    show_hdr_osd(C.GREEN .. "HDR Mode: " .. C.WHITE .. "True Passthrough (Active)")
                end
            end)
        end
    elseif target == "tonemap" then
        if last_state ~= "tonemap" then
            mp.set_property("target-colorspace-hint", "no")
            mp.set_property("target-trc", "srgb")
            mp.set_property("tone-mapping", get_saved_tone_mapping())
            show_hdr_osd(C.BLUE .. "HDR Mode: " .. C.WHITE .. "Tone-Mapping (Active)")
        end
    end

    last_state = target
end

-- --------------------------------------------------------------------------
-- 3. MANUAL TOGGLE
-- --------------------------------------------------------------------------
function toggle_hdr_manual()
    manual_override = true
    
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")
    
    if not is_hdr_video then
        show_hdr_osd(C.RED .. "Error: Not an HDR Video")
        return
    end

    if last_state == "passthrough" then
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", get_saved_tone_mapping())
        last_state = "tonemap"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "Tone-Mapping (Forced)")
    else
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "auto")
        last_state = "passthrough"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "True Passthrough (Forced)")
    end
end

-- --------------------------------------------------------------------------
-- 4. TRIGGERS
-- --------------------------------------------------------------------------

mp.register_event("file-loaded", function()
    manual_override = false 
    os_hdr_state = check_hdr_status()
    evaluate_hdr_state()
end)

mp.observe_property("video-params", "native", function()
    evaluate_hdr_state()
end)

mp.observe_property("vo-configured", "bool", function(name, val) 
    if val then 
        os_hdr_state = check_hdr_status()
        evaluate_hdr_state()
    end 
end)

mp.add_key_binding(nil, "toggle-hdr-hybrid", toggle_hdr_manual)
mp.register_script_message("toggle-hdr-mode", toggle_hdr_manual)
