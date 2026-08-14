-- Phase 3 epic gem cuts (Indormi recipes) + raw materials from BT / Hyjal
GemOrder_Gems = {
    { name = "Crimson Spinel", color = "Red", raw = true, stats = "Uncut red epic", itemId = 32227 },
    { name = "Lionseye", color = "Yellow", raw = true, stats = "Uncut yellow epic", itemId = 32205 },
    { name = "Empyrean Sapphire", color = "Blue", raw = true, stats = "Uncut blue epic", itemId = 32229 },
    { name = "Seaspray Emerald", color = "Green", raw = true, stats = "Uncut green epic", itemId = 32230 },
    { name = "Shadowsong Amethyst", color = "Purple", raw = true, stats = "Uncut purple epic", itemId = 32231 },

    -- Pre-Phase 3 uncut rare gems (blue item quality)
    { name = "Living Ruby", color = "Red", raw = true, rare = true, stats = "Uncut red rare", itemId = 23436 },
    { name = "Talasite", color = "Green", raw = true, rare = true, stats = "Uncut green rare", itemId = 23437 },
    { name = "Star of Elune", color = "Blue", raw = true, rare = true, stats = "Uncut blue rare", itemId = 23438 },
    { name = "Noble Topaz", color = "Orange", raw = true, rare = true, stats = "Uncut orange rare", itemId = 23439 },
    { name = "Nightseye", color = "Purple", raw = true, rare = true, stats = "Uncut purple rare", itemId = 23441 },
    { name = "Dawnstone", color = "Yellow", raw = true, rare = true, stats = "Uncut yellow rare", itemId = 23440 },

    -- Rare gem cuts (IDs verified at wowhead.com/tbc/item=...)
    { name = "Bold Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+14 Strength", itemId = 24027 },
    { name = "Delicate Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+14 Agility", itemId = 24028 },
    { name = "Teardrop Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+26 Healing, +9 Spell Damage", itemId = 24029 },
    { name = "Runed Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+14 Spell Damage", itemId = 24030 },
    { name = "Bright Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+28 Attack Power", itemId = 24031 },
    { name = "Subtle Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+14 Dodge Rating", itemId = 24032 },
    { name = "Flashing Living Ruby", color = "Red", material = "Living Ruby", rare = true, stats = "+14 Parry Rating", itemId = 24036 },

    { name = "Solid Star of Elune", color = "Blue", material = "Star of Elune", rare = true, stats = "+18 Stamina", itemId = 24033 },
    { name = "Sparkling Star of Elune", color = "Blue", material = "Star of Elune", rare = true, stats = "+14 Spirit", itemId = 24035 },
    { name = "Lustrous Star of Elune", color = "Blue", material = "Star of Elune", rare = true, stats = "+13 Mana per 5 sec.", itemId = 24037 },
    { name = "Stormy Star of Elune", color = "Blue", material = "Star of Elune", rare = true, stats = "+14 Spell Penetration", itemId = 24039 },

    { name = "Sovereign Nightseye", color = "Purple", material = "Nightseye", rare = true, stats = "+10 Strength, +11 Stamina", itemId = 24054 },
    { name = "Shifting Nightseye", color = "Purple", material = "Nightseye", rare = true, stats = "+10 Agility, +11 Stamina", itemId = 24055 },
    { name = "Glowing Nightseye", color = "Purple", material = "Nightseye", rare = true, stats = "+10 Spirit, +11 Stamina", itemId = 24056 },
    { name = "Royal Nightseye", color = "Purple", material = "Nightseye", rare = true, stats = "+11 Healing, +4 Spell Damage", itemId = 24057 },
    { name = "Balanced Nightseye", color = "Purple", material = "Nightseye", rare = true, stats = "+8 Attack Power, +6 Stamina", itemId = 31863 },
    { name = "Infused Nightseye", color = "Purple", material = "Nightseye", rare = true, stats = "+8 Spell Damage, +6 Stamina", itemId = 31865 },

    { name = "Enduring Talasite", color = "Green", material = "Talasite", rare = true, stats = "+11 Defense, +11 Stamina", itemId = 24062 },
    { name = "Dazzling Talasite", color = "Green", material = "Talasite", rare = true, stats = "+10 Intellect, +4 Mana/5", itemId = 24065 },
    { name = "Radiant Talasite", color = "Green", material = "Talasite", rare = true, stats = "+11 Spell Pen, +11 Stamina", itemId = 24066 },
    { name = "Jagged Talasite", color = "Green", material = "Talasite", rare = true, stats = "+10 Crit, +11 Stamina", itemId = 24067 },
    { name = "Steady Talasite", color = "Green", material = "Talasite", rare = true, stats = "+10 Resilience, +11 Stamina", itemId = 33782 },

    { name = "Inscribed Noble Topaz", color = "Orange", material = "Noble Topaz", rare = true, stats = "+10 Strength, +10 Crit", itemId = 24058 },
    { name = "Potent Noble Topaz", color = "Orange", material = "Noble Topaz", rare = true, stats = "+10 Spell Damage, +10 Crit", itemId = 24059 },
    { name = "Luminous Noble Topaz", color = "Orange", material = "Noble Topaz", rare = true, stats = "+11 Healing, +10 Intellect", itemId = 24060 },
    { name = "Glinting Noble Topaz", color = "Orange", material = "Noble Topaz", rare = true, stats = "+10 Spell Damage, +10 Intellect", itemId = 24061 },
    { name = "Veiled Noble Topaz", color = "Orange", material = "Noble Topaz", rare = true, stats = "+10 Spell Damage, +10 Hit", itemId = 31867 },
    { name = "Wicked Noble Topaz", color = "Orange", material = "Noble Topaz", rare = true, stats = "+10 Attack Power, +10 Crit", itemId = 31868 },

    { name = "Brilliant Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Intellect", itemId = 24047 },
    { name = "Smooth Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Hit Rating", itemId = 24048 },
    { name = "Gleaming Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Critical Strike", itemId = 24050 },
    { name = "Rigid Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Defense Rating", itemId = 24051 },
    { name = "Thick Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Resilience", itemId = 24052 },
    { name = "Mystic Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Spell Penetration", itemId = 24053 },
    { name = "Great Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+14 Spell Damage", itemId = 31861 },
    { name = "Quick Dawnstone", color = "Yellow", material = "Dawnstone", rare = true, stats = "+10 Haste Rating", itemId = 35315 },

    { name = "Bold Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+10 Strength", itemId = 32193 },
    { name = "Delicate Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+10 Agility", itemId = 32197 },
    { name = "Runed Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+12 Spell Damage", itemId = 32195 },
    { name = "Bright Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+20 Attack Power", itemId = 32194 },
    { name = "Teardrop Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+22 Healing, +8 Spell Damage", itemId = 32196 },
    { name = "Subtle Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+10 Dodge Rating", itemId = 32198 },
    { name = "Flashing Crimson Spinel", color = "Red", material = "Crimson Spinel", stats = "+10 Parry Rating", itemId = 32199 },

    { name = "Great Lionseye", color = "Yellow", material = "Lionseye", stats = "+10 Critical Strike Rating", itemId = 32204 },
    { name = "Smooth Lionseye", color = "Yellow", material = "Lionseye", stats = "+10 Hit Rating", itemId = 32206 },
    { name = "Rigid Lionseye", color = "Yellow", material = "Lionseye", stats = "+10 Defense Rating", itemId = 32209 },
    { name = "Gleaming Lionseye", color = "Yellow", material = "Lionseye", stats = "+10 Intellect", itemId = 32210 },
    { name = "Thick Lionseye", color = "Yellow", material = "Lionseye", stats = "+10 Resilience Rating", itemId = 32207 },
    { name = "Mystic Lionseye", color = "Yellow", material = "Lionseye", stats = "+10 Spell Penetration", itemId = 32208 },

    { name = "Solid Empyrean Sapphire", color = "Blue", material = "Empyrean Sapphire", stats = "+15 Stamina", itemId = 32200 },
    { name = "Sparkling Empyrean Sapphire", color = "Blue", material = "Empyrean Sapphire", stats = "+10 Spirit", itemId = 32202 },
    { name = "Stormy Empyrean Sapphire", color = "Blue", material = "Empyrean Sapphire", stats = "+10 Spell Penetration", itemId = 32203 },
    { name = "Lustrous Empyrean Sapphire", color = "Blue", material = "Empyrean Sapphire", stats = "+11 Mana per 5 sec.", itemId = 32201 },

    { name = "Enduring Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Defense, +7 Stamina", itemId = 32222 },
    { name = "Jagged Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Crit, +7 Stamina", itemId = 32224 },
    { name = "Steady Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Resilience, +7 Stamina", itemId = 32225 },
    { name = "Forceful Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Attack Power, +7 Stamina", itemId = 32221 },
    { name = "Radiant Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Spell Pen, +7 Stamina", itemId = 32223 },
    { name = "Dazzling Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Intellect, +2 Mana/5", itemId = 32220 },
    { name = "Sundered Seaspray Emerald", color = "Green", material = "Seaspray Emerald", stats = "+5 Strength, +7 Stamina", itemId = 32219 },

    { name = "Sovereign Shadowsong Amethyst", color = "Purple", material = "Shadowsong Amethyst", stats = "+5 Strength, +6 Stamina", itemId = 32218 },
    { name = "Shifting Shadowsong Amethyst", color = "Purple", material = "Shadowsong Amethyst", stats = "+5 Agility, +6 Stamina", itemId = 32217 },
    { name = "Timeless Shadowsong Amethyst", color = "Purple", material = "Shadowsong Amethyst", stats = "+5 Spell Damage, +6 Stamina", itemId = 32226 },
    { name = "Purified Shadowsong Amethyst", color = "Purple", material = "Shadowsong Amethyst", stats = "+5 Intellect, +6 Stamina", itemId = 32213 },
    { name = "Balanced Shadowsong Amethyst", color = "Purple", material = "Shadowsong Amethyst", stats = "+5 Crit, +6 Stamina", itemId = 32212 },
    { name = "Infused Shadowsong Amethyst", color = "Purple", material = "Shadowsong Amethyst", stats = "+5 Mana/5, +6 Stamina", itemId = 32214 },
}

GemOrder_GemByName = {}
GemOrder_GemByItemId = {}
for _, gem in ipairs(GemOrder_Gems) do
    GemOrder_GemByName[gem.name] = gem
    if gem.itemId then
        GemOrder_GemByItemId[gem.itemId] = gem
    end
end

function GemOrder_GetCutGems()
    if GemOrder_CutGemsCache then
        return GemOrder_CutGemsCache
    end
    local list = {}
    for _, gem in ipairs(GemOrder_Gems) do
        if not gem.raw and not gem.rare then
            table.insert(list, gem)
        end
    end
    GemOrder_CutGemsCache = list
    return list
end

function GemOrder_GetEpicCutGems()
    return GemOrder_GetCutGems()
end

function GemOrder_GetRareCutGems()
    if GemOrder_RareCutGemsCache then
        return GemOrder_RareCutGemsCache
    end
    local list = {}
    for _, gem in ipairs(GemOrder_Gems) do
        if not gem.raw and gem.rare then
            table.insert(list, gem)
        end
    end
    GemOrder_RareCutGemsCache = list
    return list
end

function GemOrder_GetRawGems()
    local list = {}
    for _, gem in ipairs(GemOrder_Gems) do
        if gem.raw then
            table.insert(list, gem)
        end
    end
    return list
end

function GemOrder_GetGemColor(name)
    local gem = GemOrder_GemByName[name]
    return gem and gem.color or "Unknown"
end

function GemOrder_GetRecipeGems(tier)
    if tier == "rare" then
        return GemOrder_GetRareCutGems()
    end
    return GemOrder_GetEpicCutGems()
end

function GemOrder_IsTrackedRecipeItemId(itemId)
    local gem = GemOrder_GemByItemId[itemId]
    return gem and not gem.raw
end

function GemOrder_FormatGemLabel(gem)
    return gem.name
end
