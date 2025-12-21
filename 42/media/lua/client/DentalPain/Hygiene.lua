-- DentalPain/Hygiene.lua
-- Logic for dental cleaning and hygiene items

local DP = DentalPain or {}

DP.Hygiene = {}

-- Brushing logic (Regular & Homemade)
function DP.Hygiene.brushTeeth(player, isHomemade)
    if not player then return end
    local gain = isHomemade and (DentalPain.Config.BrushHealthGain / 2) or DentalPain.Config.BrushHealthGain
    local unhappiness = isHomemade and 5 or 0
    
    DentalPain.improveDentalHealth(player, gain)
    
    if unhappiness > 0 then
        local stats = player:getStats()
        if stats then
            stats:add(CharacterStat.UNHAPPINESS, unhappiness)
        end
    end
    
    DentalPain.debug("Brushed teeth. Gain: " .. gain .. " | Unhappiness: " .. unhappiness)
end

-- Flossing logic
function DP.Hygiene.flossTeeth(player)
    if not player then return end
    DentalPain.improveDentalHealth(player, DentalPain.Config.FlossHealthGain)
    DentalPain.debug("Flossed teeth. Gain: " .. DentalPain.Config.FlossHealthGain)
end

-- Mouthwash logic
function DP.Hygiene.gargle(player)
    if not player then return end
    DentalPain.improveDentalHealth(player, DentalPain.Config.MouthwashHealthGain)
    DentalPain.debug("Gargled mouthwash. Gain: " .. DentalPain.Config.MouthwashHealthGain)
end

-- Context Menu Hook: Hygiene
function DP.Hygiene.onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    
    local modData = player:getModData()
    if not modData or modData.hasBrokenTooth then return end -- Can't clean with a broken tooth
    
    local inv = player:getInventory()
    local dentalHealth = DP.getDentalHealth(player)
    local healthLabel = " (Health: " .. math.floor(dentalHealth) .. "%)"

    -- Toothbrush + Paste (Standard)
    if inv:contains("Base.Toothbrush") and inv:contains("Base.Toothpaste") then
        context:addOption(getText("ContextMenu_BrushTeeth") .. healthLabel, player, function()
            ISTimedActionQueue.add(ISDentalAction:new(player, "brush", 200))
        end)
    end

    -- Toothbrush + Paste (Homemade)
    if inv:contains("DentalPain.HomemadeToothbrush") and inv:contains("DentalPain.HomemadeToothpaste") then
        context:addOption(getText("ContextMenu_BrushTeethHomemade") .. healthLabel, player, function()
            ISTimedActionQueue.add(ISDentalAction:new(player, "brushHomemade", 250))
        end)
    end
    
    -- Floss
    if inv:contains("DentalPain.DentalFloss") then
        context:addOption(getText("ContextMenu_DentalFloss"), player, function()
            ISTimedActionQueue.add(ISDentalAction:new(player, "floss", 150))
        end)
    end
    
    -- Mouthwash
    if inv:contains("DentalPain.Mouthwash") then
        context:addOption(getText("ContextMenu_Mouthwash"), player, function()
            ISTimedActionQueue.add(ISDentalAction:new(player, "gargle", 100))
        end)
    end
end

return DP
