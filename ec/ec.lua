-------------------------------------------------------------------------------
-- EC - Elemental Clock
-------------------------------------------------------------------------------
-- Name: EC
-- Author: Lunem
-- Version: 1.5
-- Desc: Displays current in-game weather, day, time, and moon phase, with icon.
-- Link: https://ashitaxi.com/
-------------------------------------------------------------------------------

addon.name    = 'EC'
addon.author  = 'Lunem'
addon.version = '1.4'
addon.desc    = 'Displays current in-game weather, day, time, and moon phase, with icon.'
addon.link    = 'https://ashitaxi.com/'

require('common')

-- EC settings state (with simple file persistence)
local windowOpacity = 1.0
local showSettings  = false
local contentScale  = 1.0

local showClock        = true
local showWeather      = true
local showDay          = true
local showMoon         = true
local showDayText      = true
local showOppElement   = true
local showOppElemText  = true

-- Fonts: name + size for EC UI (clock + tooltips)
local ec_font_name        = 'Lato'
local ec_font_size        = 21
local ec_font             = nil       -- used in EC window
local ec_settings_font    = nil       -- fixed size, used only in settings

local ec_settings = {
    window_opacity   = windowOpacity,
    content_scale    = contentScale,
    show_clock       = showClock,
    show_weather     = showWeather,
    show_day         = showDay,
    show_moon        = showMoon,
    show_day_text    = showDayText,
    show_opp_element = showOppElement,
    show_opp_text    = showOppElemText,
    font_name        = ec_font_name,
    font_size        = ec_font_size,
}

local function ec_get_settings_path()
    local base = AshitaCore and AshitaCore:GetInstallPath() or ''
    return string.format('%saddons/ec/settings.lua', base)
end

local function ec_load_settings()
    local path = ec_get_settings_path()
    local ok, exists = pcall(function() return ashita.fs.exists(path) end)
    if ok and exists then
        local chunk, err = loadfile(path)
        if chunk then
            local ok2, t = pcall(chunk)
            if ok2 and type(t) == 'table' then
                for k, v in pairs(t) do
                    ec_settings[k] = v
                end
            end
        end
    end

    if type(ec_settings.window_opacity) == 'number' then
        windowOpacity = ec_settings.window_opacity
    end
    if type(ec_settings.content_scale) == 'number' then
        contentScale = ec_settings.content_scale
    end
    if type(ec_settings.show_clock) == 'boolean' then
        showClock = ec_settings.show_clock
    end
    if type(ec_settings.show_weather) == 'boolean' then
        showWeather = ec_settings.show_weather
    end
    if type(ec_settings.show_day) == 'boolean' then
        showDay = ec_settings.show_day
    end
    if type(ec_settings.show_moon) == 'boolean' then
        showMoon = ec_settings.show_moon
    end
    if type(ec_settings.show_day_text) == 'boolean' then
        showDayText = ec_settings.show_day_text
    end
    if type(ec_settings.show_opp_element) == 'boolean' then
        showOppElement = ec_settings.show_opp_element
    end
    if type(ec_settings.show_opp_text) == 'boolean' then
        showOppElemText = ec_settings.show_opp_text
    end
    if type(ec_settings.font_name) == 'string' then
        ec_font_name = ec_settings.font_name
    end
    if type(ec_settings.font_size) == 'number' then
        ec_font_size = ec_settings.font_size
    end
end

local function ec_save_settings()
    ec_settings.window_opacity   = windowOpacity
    ec_settings.content_scale    = contentScale
    ec_settings.show_clock       = showClock
    ec_settings.show_weather     = showWeather
    ec_settings.show_day         = showDay
    ec_settings.show_moon        = showMoon
    ec_settings.show_day_text    = showDayText
    ec_settings.show_opp_element = showOppElement
    ec_settings.show_opp_text    = showOppElemText
    ec_settings.font_name        = ec_font_name
    ec_settings.font_size        = ec_font_size

    local path = ec_get_settings_path()
    local f, err = io.open(path, 'w+')
    if not f then
        return
    end

    f:write('return {\n')
    f:write(string.format('    window_opacity   = %.3f,\n', ec_settings.window_opacity or 1.0))
    f:write(string.format('    content_scale    = %.3f,\n', ec_settings.content_scale or 1.0))
    f:write(string.format('    show_clock       = %s,\n', tostring(ec_settings.show_clock ~= false)))
    f:write(string.format('    show_weather     = %s,\n', tostring(ec_settings.show_weather ~= false)))
    f:write(string.format('    show_day         = %s,\n', tostring(ec_settings.show_day ~= false)))
    f:write(string.format('    show_moon        = %s,\n', tostring(ec_settings.show_moon ~= false)))
    f:write(string.format('    show_day_text    = %s,\n', tostring(ec_settings.show_day_text ~= false)))
    f:write(string.format('    show_opp_element = %s,\n', tostring(ec_settings.show_opp_element ~= false)))
    f:write(string.format('    show_opp_text    = %s,\n', tostring(ec_settings.show_opp_text ~= false)))
    f:write(string.format('    font_name        = %q,\n', ec_settings.font_name or 'Lato'))
    f:write(string.format('    font_size        = %d,\n', ec_settings.font_size or 21))
    f:write('}\n')
    f:close()
end

ec_load_settings()

----------------------------------------------------------------
-- ImGui + bit
----------------------------------------------------------------
local bit   = bit or require('bit')
local imgui = _G.imgui
if imgui == nil then
    local ok, mod = pcall(require, 'imgui')
    if ok then
        imgui = mod
    end
end

----------------------------------------------------------------
-- Fonts: simple TTF loader with settings hook - default font
----------------------------------------------------------------
local function ec_font_path_for(name)
    local base = (rawget(_G,'addon') and addon.path) or ''
    local dir  = (base .. 'resources\\fonts\\'):gsub('\\\\+','\\')
    local map = {
        ['JetBrains Mono']    = 'JetBrainsMono-Regular.ttf',
        ['DejaVu Sans Mono']  = 'DejaVuSansMono.ttf',
        ['Overlock']          = 'Overlock-Regular.ttf',
        ['CarroisGothicSC']   = 'CarroisGothicSC-Regular.ttf',
        ['Lato']              = 'Lato-Regular.ttf',
        ['Default']           = 'Lato-Regular.ttf',
    }
    local file = map[name] or map['Default']
    return dir .. file
end

local function ec_reload_fonts()
    if not imgui or not imgui.AddFontFromFileTTF then
        return
    end

    local path = ec_font_path_for(ec_font_name or 'Lato')
    local size_ui  = ec_font_size or 21  -- EC window size (clock + tooltips)
    local size_set = 21                  -- fixed settings size

    local ok1, f1 = pcall(imgui.AddFontFromFileTTF, path, size_ui)
    if ok1 and f1 then
        ec_font = f1
        print(string.format('[EC] font OK (ui) -> %s @ %d', path, size_ui))
    else
        ec_font = nil
        print(string.format('[EC] font FAIL (ui) -> %s', path))
    end

    local ok2, f2 = pcall(imgui.AddFontFromFileTTF, path, size_set)
    if ok2 and f2 then
        ec_settings_font = f2
        print(string.format('[EC] font OK (settings) -> %s @ %d', path, size_set))
    else
        ec_settings_font = nil
        print(string.format('[EC] font FAIL (settings) -> %s', path))
    end
end

ashita.events.register('load', 'ec_font_load', function()
    ec_reload_fonts()
end)

----------------------------------------------------------------
-- Texture cache helpers (same style as CraftTrack)
----------------------------------------------------------------
local ffi = rawget(_G,'ffi') or require('ffi')
local texturecache = rawget(_G,'texturecache') or require('texturecache')
local _PNG_CACHE = _PNG_CACHE or {}

local function get_icon_png(path)
    if not path or path == '' then
        return nil
    end

    local t = _PNG_CACHE[path]
    if t == nil then
        if texturecache and texturecache.GetTexture then
            t = texturecache:GetTexture(path)
        else
            t = false
        end
        _PNG_CACHE[path] = t
    end

    if t == false then
        return nil
    end

    return t
end

local function draw_tex(tex, w, h)
    if not tex then
        if imgui.Dummy then pcall(imgui.Dummy, { w, h }) end
        return false
    end

    if type(tex) == 'table' and tex.Texture then
        if pcall(imgui.Image, tex.Texture, { w, h }) then return true end
        local ok, id = pcall(function() return tonumber(ffi.cast('uint32_t', tex.Texture)) end)
        if ok and id and id ~= 0 and pcall(imgui.Image, id, { w, h }) then return true end
    elseif type(tex) == 'number' then
        if pcall(imgui.Image, tex, { w, h }) then return true end
    elseif type(tex) == 'table' then
        local id = tex.id or tex.handle or tex.tex or tex.texture or tex[1]
        if id and pcall(imgui.Image, id, { w, h }) then return true end
    end

    if imgui.Dummy then pcall(imgui.Dummy, { w, h }) end
    return false
end

----------------------------------------------------------------
-- Pointers (same patterns LuAshitacast uses)
----------------------------------------------------------------
-- Vana'diel time base pointer
local pVanaTime = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0)

-- Weather pointer
local pWeather  = ashita.memory.find('FFXiMain.dll', 0, '66A1????????663D????72', 0, 0)

----------------------------------------------------------------
-- Timestamp from memory (adapted from LuAshitacast data.GetTimestamp)
----------------------------------------------------------------
local function GetTimestamp()
    if not pVanaTime or pVanaTime == 0 then
        return nil
    end

    local pointer = ashita.memory.read_uint32(pVanaTime + 0x34)
    if not pointer or pointer == 0 then
        return nil
    end

    local rawTime = ashita.memory.read_uint32(pointer + 0x0C) + 92514960

    local ts = {}
    ts.day    = math.floor(rawTime / 3456)
    ts.hour   = math.floor(rawTime / 144) % 24
    ts.minute = math.floor((rawTime % 144) / 2.4)
    return ts
end

----------------------------------------------------------------
-- Weather via memory
----------------------------------------------------------------
local weatherConstants = {
    [0]  = 'Clear',
    [1]  = 'Sunshine',
    [2]  = 'Clouds',
    [3]  = 'Fog',
    [4]  = 'Fire',
    [5]  = 'Fire x2',
    [6]  = 'Water',
    [7]  = 'Water x2',
    [8]  = 'Earth',
    [9]  = 'Earth x2',
    [10] = 'Wind',
    [11] = 'Wind x2',
    [12] = 'Ice',
    [13] = 'Ice x2',
    [14] = 'Thunder',
    [15] = 'Thunder x2',
    [16] = 'Light',
    [17] = 'Light x2',
    [18] = 'Dark',
    [19] = 'Dark x2',
}

local weatherTooltipNames = {
    [0]  = 'Clear Skys',
    [1]  = 'Sunny',
    [2]  = 'Cloudy',
    [3]  = 'Foggy',
    [4]  = 'Hot Spells',
    [5]  = 'Heat Wave',
    [6]  = 'Rain',
    [7]  = 'Squalls',
    [8]  = 'Dust Storm',
    [9]  = 'Sand Storm',
    [10] = 'Windy',
    [11] = 'Gales',
    [12] = 'Snow',
    [13] = 'Gales',
    [14] = 'Lightning',
    [15] = 'Thunderstorm',
    [16] = 'Aurora',
    [17] = 'Glare',
    [18] = 'Gloom',
    [19] = 'Miasma',
}

local function GetWeatherId()
    if not pWeather or pWeather == 0 then
        return nil
    end

    local ptr = ashita.memory.read_uint32(pWeather + 0x02)
    if not ptr or ptr == 0 then
        return nil
    end

    return ashita.memory.read_uint8(ptr + 0)
end

local function GetWeatherText()
    local id = GetWeatherId()
    if not id then
        return 'Unknown'
    end
    return weatherConstants[id] or ('Unknown (' .. tostring(id) .. ')')
end

local function GetWeatherTooltipText()
    local id = GetWeatherId()
    if not id then
        return nil
    end
    return weatherTooltipNames[id]
end

local function GetWeatherIcon()
    local id = GetWeatherId()
    if not id then
        return nil
    end
    local path = string.format('resources/weather/%d.png', id)
    return get_icon_png(path)
end

----------------------------------------------------------------
-- Day from timestamp
----------------------------------------------------------------
local weekdayNames = {
    [1] = 'Firesday',
    [2] = 'Earthsday',
    [3] = 'Watersday',
    [4] = 'Windsday',
    [5] = 'Iceday',
    [6] = 'Lightningday',
    [7] = 'Lightsday',
    [8] = 'Darksday',
}

local dayIconFiles = {
    [1] = 'firesday.png',
    [2] = 'earthsday.png',
    [3] = 'watersday.png',
    [4] = 'windsday.png',
    [5] = 'iceday.png',
    [6] = 'lightningday.png',
    [7] = 'lightsday.png',
    [8] = 'darksday.png',
}

-- Day text colors (RGBA 0-1)
local dayTextColors = {
    Firesday     = {1.000, 0.000, 0.000, 1.0}, -- ff0000
    Earthsday    = {0.722, 0.573, 0.125, 1.0}, -- b89220
    Watersday    = {0.212, 0.298, 0.827, 1.0}, -- 364cd3
    Windsday     = {0.145, 0.612, 0.145, 1.0}, -- 259c25
    Iceday       = {0.314, 0.733, 0.733, 1.0}, -- 50bbbb
    Lightningday = {0.714, 0.145, 0.714, 1.0}, -- b625b6
    Lightsday    = {1.000, 1.000, 1.000, 1.0}, -- ffffff
    Darksday     = {0.471, 0.439, 0.471, 1.0}, -- 787078
}

local function GetDayText()
    local ts = GetTimestamp()
    if not ts or type(ts.day) ~= 'number' then
        return '(none)'
    end

    local idx = (ts.day % 8) + 1
    return weekdayNames[idx] or ('Unknown (' .. tostring(idx) .. ')')
end

local function GetDayIcon()
    local ts = GetTimestamp()
    if not ts or type(ts.day) ~= 'number' then
        return nil
    end

    local idx = (ts.day % 8) + 1
    local filename = dayIconFiles[idx]
    if not filename then
        return nil
    end

    local path = 'resources/days/' .. filename
    return get_icon_png(path)
end

-- Map day index -> element name (canonical)
local dayIndexToElement = {
    [1] = 'Fire',
    [2] = 'Earth',
    [3] = 'Water',
    [4] = 'Wind',
    [5] = 'Ice',
    [6] = 'Lightning',
    [7] = 'Light',
    [8] = 'Dark',
}

local function GetDayElement()
    local ts = GetTimestamp()
    if not ts or type(ts.day) ~= 'number' then
        return nil
    end
    local idx = (ts.day % 8) + 1
    return dayIndexToElement[idx]
end

-- Weakness element mapping (based on day element)
-- Wheel: Fire >> Ice >> Wind >> Earth >> Lightning >> Water >> Fire
-- Weakness = previous element on the wheel
local WeaknessElementMap = {
    Fire      = 'Water',
    Ice       = 'Fire',
    Wind      = 'Ice',
    Earth     = 'Wind',
    Lightning = 'Earth',     -- Lightningday -> Earth
    Water     = 'Lightning', -- Watersday  -> Lightning
    Light     = 'Dark',
    Dark      = 'Light',
}


-- Element icon files for Weakness element
local elementIconFiles = {
    Fire      = 'fire.png',
    Ice       = 'ice.png',
    Wind      = 'Winds.png',
    Earth     = 'earth.png',
    Lightning = 'lightning.png',
    Water     = 'Water.png',
    Light     = 'light.png',
    Dark      = 'dark.png',
}

-- Element colors (same as day colors where relevant)
local elementTextColors = {
    Fire      = {1.000, 0.000, 0.000, 1.0}, -- Firesday
    Earth     = {0.722, 0.573, 0.125, 1.0}, -- Earthsday
    Water     = {0.212, 0.298, 0.827, 1.0}, -- Watersday
    Wind      = {0.145, 0.612, 0.145, 1.0}, -- Windsday
    Ice       = {0.314, 0.733, 0.733, 1.0}, -- Iceday
    Lightning = {0.714, 0.145, 0.714, 1.0}, -- Lightningday
    Light     = {1.000, 1.000, 1.000, 1.0}, -- Lightsday
    Dark      = {0.471, 0.439, 0.471, 1.0}, -- Darksday
}

local function GetWeaknessElement()
    local elem = GetDayElement()
    if not elem then
        return nil
    end
    return WeaknessElementMap[elem]
end

local function GetWeaknessElementIcon()
    local opp = GetWeaknessElement()
    if not opp then
        return nil
    end
    local file = elementIconFiles[opp]
    if not file then
        return nil
    end
    local path = 'resources/elements/' .. file
    return get_icon_png(path)
end

----------------------------------------------------------------
-- Time from timestamp
----------------------------------------------------------------
local function GetTimeText()
    local ts = GetTimestamp()
    if not ts or type(ts.hour) ~= 'number' or type(ts.minute) ~= 'number' then
        return '(none)'
    end

    local h = ts.hour
    local m = ts.minute

    if h < 0 then h = 0 end
    if h > 23 then h = 23 end
    if m < 0 then m = 0 end
    if m > 59 then m = 59 end

    return string.format('%02d:%02d', h, m)
end

----------------------------------------------------------------
-- Moon from timestamp (84-day cycle, simple approximation)
----------------------------------------------------------------
local function GetMoonInfo()
    local ts = GetTimestamp()
    if not ts or type(ts.day) ~= 'number' then
        return nil
    end

    local cycleLen = 84
    local d = (ts.day + 26) % cycleLen   -- 0..83

    local half = cycleLen / 2           -- 42
    local pct
    if d <= half then
        pct = math.floor(100 - (d * 100 / half) + 0.5)
    else
        pct = math.floor(((d - half) * 100 / half) + 0.5)
    end

    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end

    local waxing = (d > half)

    local phaseName
    if pct >= 90 then
        phaseName = 'Full Moon'
    elseif pct <= 10 then
        phaseName = 'New Moon'
    else
        if waxing then
            if pct >= 60 then
                phaseName = 'Waxing Gibbous'
            elseif pct >= 30 then
                phaseName = 'First Quarter'
            else
                phaseName = 'Waxing Crescent'
            end
        else
            if pct >= 60 then
                phaseName = 'Waning Gibbous'
            elseif pct >= 30 then
                phaseName = 'Last Quarter'
            else
                phaseName = 'Waning Crescent'
            end
        end
    end

    return pct, waxing, phaseName
end

local function GetMoonText()
    local pct, waxing, phaseName = GetMoonInfo()
    if not pct then
        return '(none)'
    end
    return string.format('%s (%d%%)', phaseName, pct)
end

local function GetMoonIcon()
    local pct, waxing, phaseName = GetMoonInfo()
    if not pct then
        return nil
    end

    local filename

    if pct >= 90 then
        filename = 'moon_full.png'
    elseif pct <= 10 then
        filename = 'moon_new.png'
    else
        if waxing then
            if pct >= 60 then
                filename = 'moon_waxing_gibbous.png'
            elseif pct >= 30 then
                filename = 'moon_first_quarter.png'
            elseif pct >= 20 then
                filename = 'moon_waxing_crescent.png'
            else
                filename = 'moon_waxing_crescent_thin.png'
            end
        else
            if pct >= 60 then
                filename = 'moon_waning_gibbous.png'
            elseif pct >= 30 then
                filename = 'moon_last_quarter.png'
            elseif pct >= 20 then
                filename = 'moon_waning_crescent.png'
            else
                filename = 'moon_waning_crescent_thin.png'
            end
        end
    end

    if not filename then
        return nil
    end

    local path = 'resources/moon/' .. filename
    return get_icon_png(path)
end

local function GetMoonTrendIcon()
    local pct, waxing = GetMoonInfo()
    if not pct then
        return nil
    end

    local filename = waxing and 'up.png' or 'down.png'
    local path = 'resources/moon/' .. filename
    return get_icon_png(path)
end

----------------------------------------------------------------
-- Draw
----------------------------------------------------------------
ashita.events.register('d3d_present', 'ec_render', function()
    if not imgui then
        return
    end

    -- Main EC window (background opacity controlled)
    local COL_WindowBg = rawget(_G,'ImGuiCol_WindowBg') or (imgui.Col and imgui.Col.WindowBg) or imgui.Col_WindowBg
    local pushedBg = false
    if COL_WindowBg and imgui.PushStyleColor and imgui.PopStyleColor then
        imgui.PushStyleColor(COL_WindowBg, { 0.0, 0.0, 0.0, windowOpacity })
        pushedBg = true
    end

    ----------------------------------------------------------------
    -- EC main window (uses ec_font with adjustable size)
    ----------------------------------------------------------------
    local pushedECFont = false
    if ec_font and imgui.PushFont and imgui.PopFont then
        imgui.PushFont(ec_font)
        pushedECFont = true
    end

    if imgui.Begin('Elemental Clock##EC_Window', true, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse)) then
        imgui.SetWindowFontScale(contentScale)

        local iconSize  = 32 * contentScale
        local arrowSize = 16 * contentScale

        local weatherText        = GetWeatherText()
        local weatherTooltip     = GetWeatherTooltipText() or weatherText
        local dayText            = GetDayText()
        local timeText           = GetTimeText()
        local moonText           = GetMoonText()
        local moonPct, _, moonPhaseName = GetMoonInfo()
        local moonTooltip        = moonPhaseName and string.format('%s %d%%', moonPhaseName, moonPct or 0) or moonText

        local weatherIcon        = GetWeatherIcon()
        local dayIcon            = GetDayIcon()
        local moonIcon           = GetMoonIcon()
        local moonTrendIcon      = GetMoonTrendIcon()

        local oppElementName     = GetWeaknessElement()
        local oppElementIcon     = GetWeaknessElementIcon()

        -- Single line: [time] [weather_icon] [day_icon(+text)] [moon_icon] [arrow] [weakness_icon(+text)]

        -- Time text first (if enabled)
        if showClock then
            imgui.Text(timeText or '')
            if imgui.SameLine then
                imgui.SameLine()
            end
        end

        -- Weather icon with tooltip (if enabled)
        if showWeather and weatherIcon then
            draw_tex(weatherIcon, iconSize, iconSize)
            if imgui.IsItemHovered() and imgui.BeginTooltip then
                imgui.BeginTooltip()
                imgui.TextUnformatted(weatherTooltip)
                imgui.EndTooltip()
            end
            if imgui.SameLine then
                imgui.SameLine()
            end
        end

        -- Day icon + colored day text (if enabled)
        if showDay and dayIcon then
            draw_tex(dayIcon, iconSize, iconSize)
            if imgui.IsItemHovered() and imgui.BeginTooltip then
                imgui.BeginTooltip()
                imgui.TextUnformatted(dayText)
                imgui.EndTooltip()
            end

            if showDayText and dayText then
                if imgui.SameLine then
                    imgui.SameLine()
                end
                local col = dayTextColors[dayText]
                if col and imgui.PushStyleColor and imgui.PopStyleColor then
                    local COL_Text = rawget(_G,'ImGuiCol_Text') or (imgui.Col and imgui.Col.Text) or imgui.Col_Text
                    if COL_Text then
                        imgui.PushStyleColor(COL_Text, col)
                        imgui.Text(dayText)
                        imgui.PopStyleColor()
                    else
                        imgui.Text(dayText)
                    end
                else
                    imgui.Text(dayText)
                end
            end

            if imgui.SameLine then
                imgui.SameLine()
            end
        end

        -- Moon icon with tooltip (phase + percent) and trend arrow (if enabled)
        if showMoon and (moonIcon or moonTrendIcon) then
            if moonIcon then
                draw_tex(moonIcon, iconSize, iconSize)
                if imgui.IsItemHovered() and imgui.BeginTooltip then
                    imgui.BeginTooltip()
                    imgui.TextUnformatted(moonTooltip)
                    imgui.EndTooltip()
                end
            end

            if moonTrendIcon then
                if imgui.SameLine then
                    imgui.SameLine()
                end
                draw_tex(moonTrendIcon, arrowSize, arrowSize)
            end
        end

        -- Weakness element (icon + colored text)
        if showOppElement and oppElementIcon and oppElementName then
            if imgui.SameLine then
                imgui.SameLine()
            end
            draw_tex(oppElementIcon, iconSize, iconSize)
            if imgui.IsItemHovered() and imgui.BeginTooltip then
                imgui.BeginTooltip()
                imgui.TextUnformatted('Weakness: ' .. oppElementName)
                imgui.EndTooltip()
            end

            if showOppElemText then
                if imgui.SameLine then
                    imgui.SameLine()
                end
                local col = elementTextColors[oppElementName]
                if col and imgui.PushStyleColor and imgui.PopStyleColor then
                    local COL_Text = rawget(_G,'ImGuiCol_Text') or (imgui.Col and imgui.Col.Text) or imgui.Col_Text
                    if COL_Text then
                        imgui.PushStyleColor(COL_Text, col)
                        imgui.Text(oppElementName)
                        imgui.PopStyleColor()
                    else
                        imgui.Text(oppElementName)
                    end
                else
                    imgui.Text(oppElementName)
                end
            end
        end

        imgui.SetWindowFontScale(1.0)
    end
    imgui.End()

    if pushedECFont and imgui.PopFont then
        imgui.PopFont()
    end

    ----------------------------------------------------------------
    -- Settings window (uses fixed size ec_settings_font)
    ----------------------------------------------------------------
    if showSettings then
        local pushedSettingsFont = false
        if ec_settings_font and imgui.PushFont and imgui.PopFont then
            imgui.PushFont(ec_settings_font)
            pushedSettingsFont = true
        end

        if imgui.Begin('EC Settings##EC_Settings_Window', true, ImGuiWindowFlags_AlwaysAutoResize) then
            imgui.Text('Elemental Clock Settings')
            imgui.Separator()

            -- Opacity row
            imgui.TextUnformatted('Opacity:')
            imgui.SameLine()
            local tmp = { windowOpacity }
            if imgui.SliderFloat('##EC_WindowOpacity', tmp, 0.0, 1.0) then
                local newOpacity = tmp[1] or windowOpacity
                if newOpacity < 0.0 then newOpacity = 0.0 end
                if newOpacity > 1.0 then newOpacity = 1.0 end
                windowOpacity = newOpacity
                ec_save_settings()
            end

            -- Scale row
            imgui.TextUnformatted('Scale:')
            imgui.SameLine()
            local tmpScale = { contentScale }
            if imgui.SliderFloat('##EC_ContentScale', tmpScale, 0.5, 2.0) then
                local s = tmpScale[1] or contentScale
                if s < 0.5 then s = 0.5 end
                if s > 2.0 then s = 2.0 end
                contentScale = s
                ec_save_settings()
            end

            imgui.Separator()

            -- Font name row
            imgui.TextUnformatted('Font:')
            imgui.SameLine()
            local current = tostring(ec_font_name or 'Lato')
            if imgui.BeginCombo('##EC_FontName', current) then
                local options = {
                    'JetBrains Mono',
                    'DejaVu Sans Mono',
                    'Overlock',
                    'CarroisGothicSC',
                    'Lato'
                }
                for _, nm in ipairs(options) do
                    local sel = (nm == current)
                    if imgui.Selectable(nm, sel) then
                        current      = nm
                        ec_font_name = nm
                        ec_save_settings()
                        ec_reload_fonts()
                    end
                    if sel then
                        imgui.SetItemDefaultFocus()
                    end
                end
                imgui.EndCombo()
            end

            -- Font size row (affects EC window only)
            imgui.TextUnformatted('Font size:')
            imgui.SameLine()
            local sizes = { 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24 }
            local cur_size = tonumber(ec_font_size or 21) or 21
            if imgui.BeginCombo('##EC_FontSize', tostring(cur_size)) then
                for _, sz in ipairs(sizes) do
                    local sel = (sz == cur_size)
                    if imgui.Selectable(tostring(sz), sel) then
                        cur_size     = sz
                        ec_font_size = sz
                        ec_save_settings()
                        ec_reload_fonts()
                    end
                    if sel then
                        imgui.SetItemDefaultFocus()
                    end
                end
                imgui.EndCombo()
            end

            imgui.Separator()

            -- Show/hide checkboxes
            local chkClock = { showClock }
            if imgui.Checkbox('Show Clock', chkClock) then
                showClock = chkClock[1] and true or false
                ec_save_settings()
            end

            local chkWeather = { showWeather }
            if imgui.Checkbox('Show Weather', chkWeather) then
                showWeather = chkWeather[1] and true or false
                ec_save_settings()
            end

            local chkDay = { showDay }
            if imgui.Checkbox('Show Day', chkDay) then
                showDay = chkDay[1] and true or false
                ec_save_settings()
            end

            local chkDayText = { showDayText }
            if imgui.Checkbox('Show Day Text', chkDayText) then
                showDayText = chkDayText[1] and true or false
                ec_save_settings()
            end

            local chkMoon = { showMoon }
            if imgui.Checkbox('Show Moon', chkMoon) then
                showMoon = chkMoon[1] and true or false
                ec_save_settings()
            end

            local chkOppElem = { showOppElement }
            if imgui.Checkbox('Show Weakness Element', chkOppElem) then
                showOppElement = chkOppElem[1] and true or false
                ec_save_settings()
            end

            local chkOppText = { showOppElemText }
            if imgui.Checkbox('Show Weakness Element Text', chkOppText) then
                showOppElemText = chkOppText[1] and true or false
                ec_save_settings()
            end

            imgui.Separator()

            -- Close button
            if imgui.Button('Close') then
                showSettings = false
            end
        end
        imgui.End()

        if pushedSettingsFont and imgui.PopFont then
            imgui.PopFont()
        end
    end

    if pushedBg then
        imgui.PopStyleColor()
    end
end)


----------------------------------------------------------------
-- Command handler (/ec settings)
----------------------------------------------------------------
ashita.events.register('command', 'ec_command', function(e)
    local args = e.command:args()
    if (#args == 0) then
        return
    end

    local cmd = args[1]:lower()
    if cmd ~= '/ec' then
        return
    end

    -- We are handling /ec now; block it from reaching the game.
    e.blocked = true

    local sub = args[2] and args[2]:lower() or ''

    if sub == 'settings' then
        showSettings = not showSettings
    end
end)

