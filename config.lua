Config = {}

Config.Locale    = 'sr'      -- 'sr' | 'en'
Config.Framework = 'auto'    -- 'auto' | 'qbox' | 'qb' | 'esx'
Config.Currency  = '$'

Config.PapersItem = 'rental_papers'   -- ox_inventory item

-- Opcije naplate (u minutima). Igrac bira jednu pri rentanju.
Config.Periods = { 15, 30, 60 }

-- Koliko uzastopnih neuspelih naplata pre nego sto se vozilo oduzme
Config.MaxMissedCycles = 2

Config.DamageFeeMultiplier = 1.0   -- stetu skidamo iz depozita
Config.ReturnKey = 'E'

Config.Ped = {
    model    = 'a_m_y_business_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

Config.Blip = {
    sprite = 225,
    color  = 27,   -- ljubicasta
    scale  = 0.8,
}

Config.StartFuel = 100.0   -- gorivo pri rentanju (lc_fuel)

-- price = cena po SATU (naplata po periodu se racuna: price * period / 60)
-- speed = 1-100 (samo za izgled bara u NUI)
Config.Vehicles = {
    { model = 'faggio', label = 'Faggio',   category = 'bike',  type = 'bike',       seats = 2, speed = 25, price = 40,  deposit = 200 },
    { model = 'panto',  label = 'Panto',    category = 'city',  type = 'automobile', seats = 2, speed = 40, price = 60,  deposit = 300 },
    { model = 'blista', label = 'Blista',   category = 'city',  type = 'automobile', seats = 4, speed = 50, price = 90,  deposit = 450 },
    { model = 'sultan', label = 'Sultan',   category = 'sport', type = 'automobile', seats = 4, speed = 70, price = 150, deposit = 800 },
    { model = 'baller2',label = 'Baller',   category = 'suv',   type = 'automobile', seats = 4, speed = 65, price = 170, deposit = 900 },
    { model = 'comet2', label = 'Comet',    category = 'sport', type = 'automobile', seats = 2, speed = 85, price = 260, deposit = 1500 },
}

-- Koordinate su PRIMER, namesti ih po svojoj mapi.
-- vehicles = nil -> sva vozila, ili lista modela za tu lokaciju.
Config.Locations = {
    {
        id = 'legion',
        label = 'Legion Square',
        ped = vec4(223.6, -789.3, 30.7, 250.0),
        spawns = {
            vec4(231.0, -799.0, 30.5, 157.0),
            vec4(234.0, -800.0, 30.5, 157.0),
            vec4(237.0, -801.0, 30.5, 157.0),
        },
        returnZone = { coords = vec3(228.0, -796.0, 30.5), radius = 8.0 },
        vehicles = nil,
    },
    {
        id = 'airport',
        label = 'LS Aerodrom',
        ped = vec4(-1034.4, -2730.5, 20.17, 240.0),
        spawns = {
            vec4(-1042.0, -2721.0, 13.8, 330.0),
            vec4(-1045.5, -2723.0, 13.8, 330.0),
        },
        returnZone = { coords = vec3(-1040.0, -2722.0, 13.8), radius = 8.0 },
        vehicles = { 'faggio', 'panto', 'blista', 'sultan' },
    },
    {
        id = 'sandy',
        label = 'Sandy Shores',
        ped = vec4(1964.5, 3740.0, 32.34, 300.0),
        spawns = {
            vec4(1970.0, 3744.0, 32.2, 120.0),
            vec4(1973.0, 3746.0, 32.2, 120.0),
        },
        returnZone = { coords = vec3(1968.0, 3742.0, 32.2), radius = 8.0 },
        vehicles = nil,
    },
}