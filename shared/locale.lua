Locales = Locales or {}

function L(key, ...)
    local str = (Locales[Config.Locale] and Locales[Config.Locale][key])
        or (Locales.en and Locales.en[key])
        or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

-- Svi "ui_" kljucevi za NUI
function GetUiLocale()
    local out = {}
    for k, v in pairs(Locales.en or {}) do out[k] = v end
    for k, v in pairs(Locales[Config.Locale] or {}) do out[k] = v end
    return out
end