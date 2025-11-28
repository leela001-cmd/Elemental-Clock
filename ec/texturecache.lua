-- texturecache.lua
-- Version: 1.0.9 (no-placeholder variant)
local d3d8    = require('d3d8')
local ffi     = require('ffi')

-- ========= Logging (quiet by default) =========
local LOG = {
    level = 'off',  -- 'off' | 'error' | 'warn' | 'info' | 'debug'
    tag   = '[CraftTrack v1.1.158] ',
}
local _prio = { off=0, error=1, warn=2, info=3, debug=4 }
local function log(level, msg)
    local pl = _prio[level] or 0
    local cl = _prio[LOG.level] or 0
    if pl > 0 and pl <= cl then
        print(LOG.tag .. msg)
    end
end
-- =============================================

local TextureCache = { ItemCache = {}, ImageCache = {} }

function TextureCache:Clear()
    self.ItemCache = {}
    self.ImageCache = {}
end

-- Small helper: resolve an image key to an on-disk path (no placeholder).
local function resolve_image_path(key)
    local base = AshitaCore and AshitaCore:GetInstallPath() or ''
    local rel  = tostring(key)

    -- addons/ec/<key>
    local abs1 = string.format('%saddons/ec/%s', base, rel)
    local ok1, ex1 = pcall(function() return ashita.fs.exists(abs1) end)
    if ok1 and ex1 then
        return abs1
    end

    -- addons/ec/<key>.png (if no extension)
    if not rel:lower():match('%.png$') then
        local abs2 = string.format('%saddons/ec/%s.png', base, rel)
        local ok2, ex2 = pcall(function() return ashita.fs.exists(abs2) end)
        if ok2 and ex2 then
            return abs2
        end
    end

    return nil
end



function TextureCache:GetTexture(file)
    if type(file) ~= 'string' then
        log('error', 'Invalid texture key: ' .. tostring(file))
        return nil
    end

    -------------------------------------------------------------------------
    -- ITEM:<id> path (game item icons via ResourceManager)
    -------------------------------------------------------------------------
    if string.sub(file, 1, 5) == 'ITEM:' then
        local itemId = tonumber(string.sub(file, 6))
        if type(itemId) ~= 'number' or itemId == 0 then
            log('warn', 'Invalid item id in key: ' .. tostring(file))
            return nil
        end

        -- cache hit
        local cached = self.ItemCache[itemId]
        if cached then return cached end

        local rm = AshitaCore and AshitaCore:GetResourceManager() or nil
        if not rm then
            log('error', 'ResourceManager unavailable.')
            return nil
        end

        local item = rm:GetItemById(itemId)
        if not item then
            log('warn', 'Item not found by id: ' .. tostring(itemId))
            return nil
        end
        if not (item.Bitmap and item.ImageSize and item.ImageSize > 0) then
            log('warn', 'Item bitmap missing/invalid for id: ' .. tostring(itemId))
            return nil
        end

        local dxp = ffi.new('IDirect3DTexture8*[1]')
        local ok = (ffi.C.D3DXCreateTextureFromFileInMemoryEx(
            d3d8.get_device(),
            item.Bitmap,
            item.ImageSize,
            0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
            ffi.C.D3DFMT_A8R8G8B8,
            ffi.C.D3DPOOL_MANAGED,
            ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT,
            0xFF000000, nil, nil, dxp
        ) == ffi.C.S_OK)

        if not ok then
            log('warn', 'D3DXCreateTextureFromFileInMemoryEx failed for item id: ' .. tostring(itemId))
            return nil
        end

        local tex = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dxp[0]))
        local result, desc = tex:GetLevelDesc(0)
        if result ~= 0 then
            log('warn', 'GetLevelDesc failed for item id: ' .. tostring(itemId))
            return nil
        end

        local tx = { Texture = tex, Width = desc.Width, Height = desc.Height }
        self.ItemCache[itemId] = tx
        return tx
    end

    -------------------------------------------------------------------------
    -- Local images under resources/ (UI icons, etc.)
    -------------------------------------------------------------------------
    -- cache hit
    local cached = self.ImageCache[file]
    if cached then return cached end

    local path = resolve_image_path(file)
    if not path then
        -- No placeholder: return nil so the caller decides what to draw.
        log('warn', 'Image key not found: ' .. tostring(file))
        return nil
    end

    local dxp = ffi.new('IDirect3DTexture8*[1]')
    local ok = (ffi.C.D3DXCreateTextureFromFileA(d3d8.get_device(), path, dxp) == ffi.C.S_OK)
    if not ok then
        log('warn', 'D3DXCreateTextureFromFileA failed: ' .. tostring(path))
        return nil
    end

    local tex = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dxp[0]))
    local result, desc = tex:GetLevelDesc(0)
    if result ~= 0 then
        log('warn', 'GetLevelDesc failed for file: ' .. tostring(file))
        return nil
    end

    local tx = { Texture = tex, Width = desc.Width, Height = desc.Height }
    self.ImageCache[file] = tx
    return tx
end

return TextureCache
