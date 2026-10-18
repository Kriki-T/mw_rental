Bridge = {}

local fw, QBCore, ESX

local function init()
    if fw then return end
    fw = Config.Framework
    if fw == 'auto' then
        if GetResourceState('qbx_core') == 'started' then fw = 'qbox'
        elseif GetResourceState('qb-core') == 'started' then fw = 'qb'
        elseif GetResourceState('es_extended') == 'started' then fw = 'esx'
        else fw = nil error('[mw_rental] Framework nije pronadjen (qbx_core / qb-core / es_extended).') end
    end
    if fw == 'qb' then QBCore = exports['qb-core']:GetCoreObject()
    elseif fw == 'esx' then ESX = exports['es_extended']:getSharedObject() end
end

local function getPlayer(src)
    init()
    if fw == 'qbox' then return exports.qbx_core:GetPlayer(src)
    elseif fw == 'qb' then return QBCore.Functions.GetPlayer(src)
    else return ESX.GetPlayerFromId(src) end
end

function Bridge.GetIdentifier(src)
    local p = getPlayer(src)
    if not p then return end
    return fw == 'esx' and p.identifier or p.PlayerData.citizenid
end

function Bridge.GetName(src)
    local p = getPlayer(src)
    if not p then return 'Unknown' end
    if fw == 'esx' then return p.getName() end
    local ci = p.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname, ci.lastname)
end

-- account: 'cash' | 'bank'
function Bridge.GetMoney(src, account)
    local p = getPlayer(src)
    if not p then return 0 end
    if fw == 'esx' then
        return account == 'cash' and p.getMoney() or p.getAccount('bank').money
    end
    return p.Functions.GetMoney(account) or 0
end

function Bridge.RemoveMoney(src, account, amount, reason)
    local p = getPlayer(src)
    if not p or amount <= 0 then return amount <= 0 end
    if Bridge.GetMoney(src, account) < amount then return false end
    if fw == 'esx' then
        if account == 'cash' then p.removeMoney(amount, reason)
        else p.removeAccountMoney('bank', amount, reason) end
        return true
    end
    return p.Functions.RemoveMoney(account, amount, reason) and true or false
end

function Bridge.AddMoney(src, account, amount, reason)
    local p = getPlayer(src)
    if not p or amount <= 0 then return end
    if fw == 'esx' then
        if account == 'cash' then p.addMoney(amount, reason)
        else p.addAccountMoney('bank', amount, reason) end
    else
        p.Functions.AddMoney(account, amount, reason)
    end
end

-- cb(src) kad se igrac ucita
function Bridge.OnLoaded(cb)
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        if Player and Player.PlayerData then cb(Player.PlayerData.source) end
    end)
    AddEventHandler('esx:playerLoaded', function(src) cb(src) end)
end