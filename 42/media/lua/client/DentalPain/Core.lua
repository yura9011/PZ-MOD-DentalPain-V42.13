-- DentalPain/Core.lua
-- Central configuration and state for the DentalPain mod
-- VERSION: LOCAL_DEV_20241220_0800

print("[DentalPain] Core.lua loading - LOCAL DEV VERSION 20241220.0800")

DentalPain = DentalPain or {}

-- Configuration Constants
DentalPain.Config = {
    InitialDentalHealth = 100,
    DentalHealthDecline = 0.25,   -- Per hour
    PainThreshold = 20,           -- Below this = severe pain
    MildThreshold = 50,           -- Below this = mild effects + tooth break risk
    SeverePainAmount = 30,        -- Pain applied when below threshold
    BrokenToothPain = 100,        -- Max pain when tooth breaks
    MildUnhappiness = 10,         -- Unhappiness when below mild threshold
    BrushHealthGain = 30,         -- Health restored by brushing
    FlossHealthGain = 15,         -- Health restored by flossing
    MouthwashHealthGain = 10,     -- Health restored by mouthwash
    AnestheticDuration = 4,       -- Hours the "Numbed" status lasts
    ExtractionSuccessBase = 60,   -- Pliers base success %
    ExtractionDesperateBase = 35, -- Hammer base success %
    FirstAidBonus = 10,           -- % per level of First Aid
    TeethTotal = 32,              -- Total teeth
    HealthPerTooth = 3,           -- Max health lost per extraction
    DebugMode = false,
}

-- Food Impact Table (Damage per consumption)
DentalPain.FoodImpact = {
    -- High Sugary
    ["Base.Chocolate"] = 5.0,
    ["Base.Lollipop"] = 5.0,
    ["Base.Crisps"] = 3.0,
    ["Base.Pop"] = 4.0,
    ["Base.OrangeSoda"] = 4.0,
    ["Base.Gum"] = 6.0,
    ["Base.HardCandy"] = 5.0,
    ["Base.CakeSlice"] = 4.5,
    ["Base.IceCream"] = 5.0,
    ["Base.PeanutButter"] = 3.5,
    ["Base.JellyBeans"] = 5.5,
    ["Base.ChocolateChip"] = 4.0,
    ["Base.CookiesChocolate"] = 4.5,
    ["Base.Cupcake"] = 4.5,
    ["Base.Honey"] = 3.0,
    ["Base.Pancakes"] = 3.0,
    ["Base.Waffles"] = 3.0,
    
    -- High Starch/Processed
    ["Base.Steak"] = 1.5,
    ["Base.Bread"] = 1.2,
    ["Base.Cereal"] = 2.0,
    ["Base.Pasta"] = 1.5,
    ["Base.Rice"] = 1.5,
    ["Base.BagelSesame"] = 1.5,
    ["Base.Burger"] = 2.0,
    ["Base.Burrito"] = 2.0,
    
    -- Low Impact
    ["Base.Apple"] = 0.5,
    ["Base.Banana"] = 0.5,
    ["Base.Carrots"] = 0.2,
    ["Base.Broccoli"] = 0.1,
    ["Base.Cabbage"] = 0.1,
    ["Base.BerryGeneric1"] = 0.3,
}

-- Utility: Get current dental health
function DentalPain.getDentalHealth(player)
    if not player then return 100 end
    local modData = player:getModData()
    if not modData then return 100 end
    return modData.dentalHealth or DentalPain.Config.InitialDentalHealth
end

-- Utility: Set dental health
function DentalPain.setDentalHealth(player, value)
    if not player then return end
    local modData = player:getModData()
    if not modData then return end
    local maxH = DentalPain.Config.InitialDentalHealth
    modData.dentalHealth = math.max(0, math.min(value, maxH))
end

-- Utility: Check for Anesthetic
function DentalPain.isNumbed(player)
    if not player then return false end
    local modData = player:getModData()
    if not modData then return false end
    return (modData.anestheticTimer or 0) > 0
end

-- Utility: Play pain sound
function DentalPain.playPainSound(player)
    if not player then return end
    local isFemale = player:isFemale()
    local sound = isFemale and "PZ_Female_Pain_01" or "PZ_Male_Pain_01"
    if ZombRand(2) == 0 then
        sound = isFemale and "PZ_Female_Pain_02" or "PZ_Male_Pain_02"
    end
    player:playSound(sound)
end

-- Utility: Play crunch sound (B42 compatible)
function DentalPain.playCrunchSound(player)
    if not player then return end
    -- Use simple player:playSound which works in B42
    player:playSound("PZ_Crunch")
end

-- Utility: Improve dental health 
function DentalPain.improveDentalHealth(player, amount)
    if not player then return end
    local oldHealth = DentalPain.getDentalHealth(player)
    DentalPain.setDentalHealth(player, oldHealth + amount)
    
    -- Show relief message via Dialogue module
    if DentalPain.Dialogue then
        DentalPain.Dialogue.sayRandom(player, "Relief")
    end
end

DentalPain.debug = function(msg)
    if DentalPain.Config.DebugMode then
        print("[DentalPain] " .. msg)
    end
end

return DentalPain
