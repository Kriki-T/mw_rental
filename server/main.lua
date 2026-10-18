local Rentals, BySource, Busy, Plates = {}, {}, {}, {}
local NextId = 0

local VehicleCfg, LocationCfg, PeriodOk = {}, {}, {}
for _, v in ipairs(Config.Vehicles) do VehicleCfg[v.model] = v end
for _, l in ipairs(Config.Locations) do LocationCfg[l.id] = l end
for _, p in ipairs(Config.Periods) do PeriodOk[p] = true end

---------------------------------------------------------------- helpers
local function notify(src, ntype, desc)
    lib.notify(src, {
        title = L('notify_title'), description = desc, type = ntype,
        icon = 'car', iconColor = '#a855f7',
    })
end

local function money(n) return Config.Currency .. math.floor(n) end

local function fmtDuration(sec)
    local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
    if h > 0 then return ('%dh %dmin'):format(h, m) end
    return ('%dmin'):format(m)
end

local function allowedAt(loc, model)
    if not loc.vehicles then return true end
    for _, m in ipairs(loc.vehicles) do if m == model then return true end end
    return false
end

local function generatePlate()
    local chars, plate = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
    repeat
        local t = { 'M', 'W' }
        for i = 3, 6 do
            local r = math.random(#chars)
            t[i] = chars:sub(r, r)
        end
        plate = table.concat(t)
    until not Plates[plate]
    Plates[plate] = true
    return plate
end

local function clientInfo(r)
    local now = os.time()
    return {
        id = r.id, netId = r.netId, plate = r.plate, label = r.label, model = r.model,
        renter = r.renter, period = r.period, cycleCost = r.cycleCost,
        deposit = r.deposit, paid = r.paid, debt = r.debt, method = r.method,
        elapsed = now - r.startedAt, nextIn = math.max(0, r.nextCharge - now),
        started = os.date('%d.%m.%Y %H:%M', r.startedAt),
    }
end

---------------------------------------------------------------- papiri (ox_inventory)
local function papersMeta(r)
    local now = os.time()
    local lines = {
        ('**%s:** %s'):format(L('doc_renter'), r.renter),
        ('**%s:** %s'):format(L('doc_vehicle'), r.label),
        ('**%s:** %s'):format(L('doc_plate'), r.plate),
        ('**%s:** %s'):format(L('doc_started'), os.date('%d.%m.%Y %H:%M', r.startedAt)),
        ('**%s:** %s'):format(L('doc_elapsed'), fmtDuration(now - r.startedAt)),
        ('**%s:** %s'):format(L('doc_billing'), L('doc_billing_v', money(r.cycleCost), r.period)),
        ('**%s:** %s'):format(L('doc_next'), os.date('%H:%M', r.nextCharge)),
        ('**%s:** %s'):format(L('doc_paid'), money(r.paid)),
        ('**%s:** %s'):format(L('doc_deposit'), money(r.deposit)),
        '',
        ('*%s*'):format(L('doc_footer')),
    }
    return {
        rentalId = r.id,
        plate = r.plate,
        label = ('%s [%s]'):format(L('doc_title'), r.plate),
        description = table.concat(lines, '  \n'),
    }
end

local function findPapersSlot(src, rid)
    local ok, slots = pcall(exports.ox_inventory.Search, exports.ox_inventory, src, 'slots', Config.PapersItem)
    if not ok or not slots then return end
    for _, s in pairs(slots) do
        if s.metadata and s.metadata.rentalId == rid then return s.slot end
    end
end

local function updatePapers(r)
    local slot = findPapersSlot(r.src, r.id)
    if slot then exports.ox_inventory:SetMetadata(r.src, slot, papersMeta(r)) end
end

local function removePapers(src, rid)
    local slot = findPapersSlot(src, rid)
    if slot then exports.ox_inventory:RemoveItem(src, Config.PapersItem, 1, nil, slot) end
end

---------------------------------------------------------------- zatvaranje rente
local function closeRental(r)
    Rentals[r.id] = nil
    if BySource[r.src] == r.id then BySource[r.src] = nil end
    Plates[r.plate] = nil

    local veh = r.netId and NetworkGetEntityFromNetworkId(r.netId)
    local exists = veh and veh ~= 0 and DoesEntityExist(veh)

    pcall(Keys.Remove, r.src, r.plate, exists and veh or nil)
    if exists then DeleteEntity(veh) end
    pcall(removePapers, r.src, r.id)
    TriggerClientEvent('mw_rental:client:ended', r.src)
end

---------------------------------------------------------------- naplata
local function charge(r, amount, reason)
    local order = r.method == 'bank' and { 'bank', 'cash' } or { 'cash', 'bank' }
    for _, acc in ipairs(order) do
        if Bridge.RemoveMoney(r.src, acc, amount, reason) then return true end
    end
    return false
end

local function processCycle(r)
    local now = os.time()
    r.nextCharge = r.nextCharge + r.period * 60

    if charge(r, r.cycleCost, 'car-rental-' .. r.plate) then
        r.paid, r.missed = r.paid + r.cycleCost, 0
        notify(r.src, 'inform', L('charge_ok', money(r.cycleCost), r.period))
    else
        r.missed = r.missed + 1
        r.debt = r.debt + r.cycleCost
        if r.missed >= Config.MaxMissedCycles then
            notify(r.src, 'error', L('repossessed'))
            return closeRental(r)
        end
        notify(r.src, 'warning', L('charge_fail', r.missed, Config.MaxMissedCycles))
    end

    r.nextMeta = now + 60
    updatePapers(r)
    TriggerClientEvent('mw_rental:client:update', r.src, clientInfo(r))
end

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, r in pairs(Rentals) do
            if now >= r.nextCharge then
                processCycle(r)
            elseif now >= r.nextMeta then
                r.nextMeta = now + 60
                updatePapers(r)   -- osvezava "traje do sada"
            end
        end
    end
end)

---------------------------------------------------------------- callbacks
lib.callback.register('mw_rental:getData', function(src)
    local id = BySource[src]
    return {
        cash = Bridge.GetMoney(src, 'cash'),
        bank = Bridge.GetMoney(src, 'bank'),
        rental = id and Rentals[id] and clientInfo(Rentals[id]) or nil,
    }
end)

lib.callback.register('mw_rental:getActive', function(src)
    local id = BySource[src]
    return id and Rentals[id] and clientInfo(Rentals[id]) or nil
end)

lib.callback.register('mw_rental:rent', function(src, data)
    if type(data) ~= 'table' then return { ok = false, msg = L('err_generic') } end
    if Busy[src] then return { ok = false, msg = L('err_busy') } end
    if BySource[src] then return { ok = false, msg = L('err_has_rental') } end

    local loc = LocationCfg[data.location]
    local veh = VehicleCfg[data.model]
    local period = tonumber(data.period)
    if not loc then return { ok = false, msg = L('err_generic') } end
    if not veh or not allowedAt(loc, veh.model) then return { ok = false, msg = L('err_vehicle_na') } end
    if not period or not PeriodOk[period] then return { ok = false, msg = L('err_period') } end

    local pcoords = GetEntityCoords(GetPlayerPed(src))
    if #(pcoords - loc.ped.xyz) > 15.0 then return { ok = false, msg = L('err_too_far') } end

    local method = data.method == 'bank' and 'bank' or 'cash'
    local spawn = loc.spawns[tonumber(data.spawn) or 1] or loc.spawns[1]
    local cycleCost = math.max(1, math.ceil(veh.price * period / 60))
    local total = cycleCost + veh.deposit

    if Bridge.GetMoney(src, method) < total then return { ok = false, msg = L('err_no_money') } end
    if not exports.ox_inventory:CanCarryItem(src, Config.PapersItem, 1) then
        return { ok = false, msg = L('err_no_carry') }
    end

    Busy[src] = true
    if not Bridge.RemoveMoney(src, method, total, 'car-rental-start') then
        Busy[src] = nil
        return { ok = false, msg = L('err_no_money') }
    end

    local entity = CreateVehicleServerSetter(joaat(veh.model), veh.type or 'automobile',
        spawn.x, spawn.y, spawn.z, spawn.w)
    local tries = 0
    while (not entity or entity == 0 or not DoesEntityExist(entity)) and tries < 60 do
        Wait(50)
        tries = tries + 1
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        Bridge.AddMoney(src, method, total, 'car-rental-refund')
        Busy[src] = nil
        return { ok = false, msg = L('err_spawn') }
    end

    local plate = generatePlate()
    SetVehicleNumberPlateText(entity, plate)
    local netId = NetworkGetNetworkIdFromEntity(entity)

    NextId = NextId + 1
    local now = os.time()
    local r = {
        id = NextId, src = src, identifier = Bridge.GetIdentifier(src), renter = Bridge.GetName(src),
        model = veh.model, label = veh.label, plate = plate, netId = netId,
        period = period, cycleCost = cycleCost, deposit = veh.deposit, method = method,
        paid = cycleCost, debt = 0, missed = 0,
        startedAt = now, nextCharge = now + period * 60, nextMeta = now + 60,
    }

    if not exports.ox_inventory:AddItem(src, Config.PapersItem, 1, papersMeta(r)) then
        DeleteEntity(entity)
        Plates[plate] = nil
        Bridge.AddMoney(src, method, total, 'car-rental-refund')
        Busy[src] = nil
        return { ok = false, msg = L('err_no_carry') }
    end

    Rentals[r.id], BySource[src] = r, r.id
    Entity(entity).state:set('mwRental', r.id, true)
    Keys.Give(src, entity, plate, netId)

    Busy[src] = nil
    notify(src, 'success', L('ok_rented', veh.label, plate))
    return { ok = true, netId = netId, rental = clientInfo(r) }
end)

lib.callback.register('mw_rental:return', function(src)
    if Busy[src] then return { ok = false, msg = L('err_busy') } end
    local r = BySource[src] and Rentals[BySource[src]]
    if not r then return { ok = false, msg = L('err_no_rental') } end

    local veh = NetworkGetEntityFromNetworkId(r.netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        notify(src, 'error', L('lost'))
        closeRental(r)
        return { ok = true, lost = true }
    end

    local vc = GetEntityCoords(veh)
    local inZone = false
    for _, loc in ipairs(Config.Locations) do
        if #(vc - loc.returnZone.coords) <= loc.returnZone.radius + 4.0 then inZone = true break end
    end
    if not inZone or #(GetEntityCoords(GetPlayerPed(src)) - vc) > 40.0 then
        return { ok = false, msg = L('err_not_in_zone') }
    end

    Busy[src] = true
    local function clamp(v) return math.max(0.0, math.min(1000.0, v or 1000.0)) end
    local ratio = ((1000 - clamp(GetVehicleBodyHealth(veh))) + (1000 - clamp(GetVehicleEngineHealth(veh)))) / 2000
    local damageFee = math.min(r.deposit, math.floor(r.deposit * ratio * Config.DamageFeeMultiplier))
    local refund = math.max(0, r.deposit - damageFee - r.debt)

    if refund > 0 then Bridge.AddMoney(src, r.method, refund, 'car-rental-deposit-refund') end
    notify(src, 'success', L('returned', money(refund), money(damageFee), money(r.debt)))
    closeRental(r)
    Busy[src] = nil
    return { ok = true, refund = refund }
end)

---------------------------------------------------------------- cleanup
AddEventHandler('playerDropped', function()
    local src = source
    local id = BySource[src]
    if id and Rentals[id] then closeRental(Rentals[id]) end
    Busy[src] = nil
end)

-- Ostali papiri (npr. igrac izasao sa rentom) se brisu pri loginu
Bridge.OnLoaded(function(src)
    SetTimeout(5000, function()
        if BySource[src] then return end
        local ok, slots = pcall(exports.ox_inventory.Search, exports.ox_inventory, src, 'slots', Config.PapersItem)
        if ok and slots then
            for _, s in pairs(slots) do
                exports.ox_inventory:RemoveItem(src, Config.PapersItem, 1, nil, s.slot)
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(Rentals) do
        local veh = NetworkGetEntityFromNetworkId(r.netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end)