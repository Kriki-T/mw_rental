Keys = {}

-- src    = server id igraca
-- entity = server entity vozila
-- plate  = tablice
-- netId  = network id vozila

function Keys.Give(src, entity, plate, netId)
    -- === OVDE UBACI SVOJ EXPORT ===
    -- qbx_vehiclekeys:   exports.qbx_vehiclekeys:GiveKeys(src, entity)
    -- qb-vehiclekeys:    TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate)
    -- wasabi_carlock:    exports.wasabi_carlock:GiveKey(src, plate)
    -- Renewed:           exports['Renewed-Vehiclekeys']:addKey(src, plate)

    -- Bez key sistema vozilo je otkljucano
    SetVehicleDoorsLocked(entity, 1)
end

function Keys.Remove(src, plate, entity)
    -- === OVDE UBACI SVOJ EXPORT ===
    -- qbx_vehiclekeys:   exports.qbx_vehiclekeys:RemoveKeys(src, entity)
    -- qb-vehiclekeys:    TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', src, plate)
    -- wasabi_carlock:    exports.wasabi_carlock:RemoveKey(src, plate)
    -- Renewed:           exports['Renewed-Vehiclekeys']:removeKey(src, plate)
end