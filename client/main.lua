local activeRental, currentLoc, uiOpen = nil, nil, false
local zoneCount, textShown = 0, false
local peds = {}

---------------------------------------------------------------- UI
local function openUI(loc)
    if uiOpen then return end
    local srv = lib.callback.await('mw_rental:getData', false)
    if not srv then return end
    activeRental = srv.rental

    local vehicles = {}
    local allowed
    if loc.vehicles then
        allowed = {}
        for _, m in ipairs(loc.vehicles) do allowed[m] = true end
    end
    for _, v in ipairs(Config.Vehicles) do
        if not allowed or allowed[v.model] then vehicles[#vehicles + 1] = v end
    end

    currentLoc, uiOpen = loc, true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            location = loc.label, currency = Config.Currency,
            cash = srv.cash, bank = srv.bank, rental = srv.rental,
            vehicles = vehicles, periods = Config.Periods,
            locale = GetUiLocale(),
        },
    })
end

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) closeUI() cb(1) end)

local function findFreeSpawn(loc)
    for i, s in ipairs(loc.spawns) do
        if not IsAnyVehicleNearPoint(s.x, s.y, s.z, 2.5) then return i end
    end
end

RegisterNUICallback('rent', function(body, cb)
    local loc = currentLoc
    if not loc then return cb({ ok = false }) end

    local spawn = findFreeSpawn(loc)
    if not spawn then return cb({ ok = false, msg = L('err_no_spawn') }) end

    local res = lib.callback.await('mw_rental:rent', false, {
        location = loc.id, model = body.model, period = body.period,
        method = body.method, spawn = spawn,
    })
    if not res or not res.ok then
        return cb({ ok = false, msg = res and res.msg or L('err_generic') })
    end

    activeRental = res.rental
    closeUI()
    cb({ ok = true })

    local ok, veh = pcall(lib.waitFor, function()
        if NetworkDoesEntityExistWithNetworkId(res.netId) then return NetToVeh(res.netId) end
    end, 'vehicle timeout', 5000)
    if ok and veh and veh ~= 0 then TaskWarpPedIntoVehicle(cache.ped, veh, -1) end
end)

---------------------------------------------------------------- povrat
local function returnVehicle()
    if not activeRental then
        return lib.notify({ title = L('notify_title'), description = L('err_no_rental'), type = 'error' })
    end
    local confirm = lib.alertDialog({
        header = L('return_header'), content = L('return_text'),
        centered = true, cancel = true,
    })
    if confirm ~= 'confirm' then return end

    local res = lib.callback.await('mw_rental:return', false)
    if res and not res.ok then
        lib.notify({ title = L('notify_title'), description = res.msg or L('err_generic'), type = 'error' })
    end
end

-- TextUI + keybind (bez petlji)
local function refreshTextUI()
    local show = zoneCount > 0 and activeRental ~= nil
        and cache.vehicle and NetworkGetEntityIsNetworked(cache.vehicle)
        and VehToNet(cache.vehicle) == activeRental.netId
    if show and not textShown then
        textShown = true
        lib.showTextUI(('[%s] %s'):format(Config.ReturnKey, L('textui_return')),
            { icon = 'car', iconColor = '#a855f7' })
    elseif not show and textShown then
        textShown = false
        lib.hideTextUI()
    end
end

lib.addKeybind({
    name = 'mw_rental_return',
    description = L('keybind_return'),
    defaultKey = Config.ReturnKey,
    onPressed = function()
        if textShown then returnVehicle() end
    end,
})

lib.onCache('vehicle', function() refreshTextUI() end)

for _, loc in ipairs(Config.Locations) do
    lib.zones.sphere({
        coords = loc.returnZone.coords,
        radius = loc.returnZone.radius,
        onEnter = function() zoneCount = zoneCount + 1 refreshTextUI() end,
        onExit  = function() zoneCount = math.max(0, zoneCount - 1) refreshTextUI() end,
    })
end

---------------------------------------------------------------- NPC + blip
local function spawnPed(loc)
    if peds[loc.id] then return end
    local model = joaat(Config.Ped.model)
    lib.requestModel(model)
    local p = loc.ped
    local ped = CreatePed(0, model, p.x, p.y, p.z - 1.0, p.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    FreezeEntityPosition(ped, true)
    if Config.Ped.scenario then TaskStartScenarioInPlace(ped, Config.Ped.scenario, 0, true) end
    SetModelAsNoLongerNeeded(model)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'mw_rent_' .. loc.id,
            icon = 'fa-solid fa-car',
            label = L('target_rent'),
            distance = 2.5,
            onSelect = function() openUI(loc) end,
        },
        {
            name = 'mw_return_' .. loc.id,
            icon = 'fa-solid fa-rotate-left',
            label = L('target_return'),
            distance = 2.5,
            canInteract = function() return activeRental ~= nil end,
            onSelect = returnVehicle,
        },
    })
    peds[loc.id] = ped
end

local function removePed(loc)
    local ped = peds[loc.id]
    if not ped then return end
    exports.ox_target:removeLocalEntity(ped)
    DeleteEntity(ped)
    peds[loc.id] = nil
end

for _, loc in ipairs(Config.Locations) do
    lib.points.new({
        coords = loc.ped.xyz, distance = 60.0,
        onEnter = function() spawnPed(loc) end,
        onExit  = function() removePed(loc) end,
    })

    local blip = AddBlipForCoord(loc.ped.x, loc.ped.y, loc.ped.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('blip_label'))
    EndTextCommandSetBlipName(blip)
end

---------------------------------------------------------------- eventi
RegisterNetEvent('mw_rental:client:update', function(info)
    activeRental = info
    refreshTextUI()
    if uiOpen then SendNUIMessage({ action = 'rental', data = info }) end
end)

RegisterNetEvent('mw_rental:client:ended', function()
    activeRental = nil
    refreshTextUI()
    if uiOpen then SendNUIMessage({ action = 'rental', data = false }) end
end)

CreateThread(function()
    activeRental = lib.callback.await('mw_rental:getActive', false)
end)

-- Klik na item "papiri za rentu" u inventaru
exports('usePapers', function(_, slot)
    local m = slot and slot.metadata
    if not m then return end
    lib.alertDialog({
        header = m.label or L('doc_title'),
        content = m.description or '',
        centered = true, cancel = false,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if textShown then lib.hideTextUI() end
    for _, loc in ipairs(Config.Locations) do removePed(loc) end
end)