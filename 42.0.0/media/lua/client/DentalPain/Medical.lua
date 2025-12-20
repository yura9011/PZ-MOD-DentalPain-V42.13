-- DentalPain/Medical.lua
-- Logic for dental pain, anesthetics, and extractions

local DP = DentalPain or {}

DP.Medical = {}

function DP.Medical.takeAnesthetic(player)
    if not player then return end
    local modData = player:getModData()
    if not modData then return end
    modData.anestheticTimer = DP.Config.AnestheticDuration
    
    local item = player:getInventory():getFirstType("DentalPain.DentalAnesthetic")
    if item then
        player:getInventory():Remove(item)
    end
    
    DP.Dialogue.sayRandom(player, "Numbed")
    DP.debug("Took anesthetic. Duration: " .. DP.Config.AnestheticDuration .. " hours")
end

-- Calculate extraction success probability
function DP.Medical.calculateChance(player, method)
    local firstAid = player:getPerkLevel(Perks.Doctor) or 0
    local baseSuccess = (method == "pliers") and DP.Config.ExtractionSuccessBase or DP.Config.ExtractionDesperateBase
    
    local chance = baseSuccess + (firstAid * DP.Config.FirstAidBonus)
    
    -- Anesthetic Bonus
    if DP.isNumbed(player) then
        chance = chance + 30
    end
    
    return math.min(chance, 95)
end

-- Perform tooth extraction
function DP.Medical.performExtraction(player, method)
    local modData = player:getModData()
    if not modData.hasBrokenTooth then return end
    
    local chance = DP.Medical.calculateChance(player, method)
    local roll = ZombRand(100)
    
    DentalPain.playCrunchSound(player)
    DentalPain.playPainSound(player)
    
    if roll < chance then
        -- SUCCESS
        modData.hasBrokenTooth = false
        modData.teethExtracted = (modData.teethExtracted or 0) + 1
        
        DP.Dialogue.sayRandom(player, "Extraction", "Success")
        
        -- Apply some residual pain even if successful
        local bodyDamage = player:getBodyDamage()
        local head = bodyDamage:getBodyPart(BodyPartType.Head)
        head:setAdditionalPain(head:getAdditionalPain() + ZombRand(10, 21))
    else
        -- FAILURE - Bleeding! (shows in Health Panel)
        local bodyDamage = player:getBodyDamage()
        local head = bodyDamage:getBodyPart(BodyPartType.Head)
        head:generateDeepWound()
        head:setBleeding(true)
        head:setAdditionalPain(head:getAdditionalPain() + 50)
        
        DP.Dialogue.sayRandom(player, "Extraction", "Fail")
    end
end

-- Tooth Break Logic
function DP.Medical.checkBreak(player)
    local health = DP.getDentalHealth(player)
    if health >= DP.Config.MildThreshold then return end
    
    local modData = player:getModData()
    if modData.hasBrokenTooth then return end
    
    -- Chance increases as health drops
    local chance = DP.Config.ExtractionDesperateBase -- Reusing a base value for scaling
    if ZombRand(100) < 5 then -- Fixed 5% per check for simplicity
        modData.hasBrokenTooth = true
        DentalPain.playCrunchSound(player)
        DentalPain.playPainSound(player)
        DP.Dialogue.sayRandom(player, "Extraction", "Broken")
        
        local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
        head:setAdditionalPain(DP.Config.BrokenToothPain)
    end
end

-- Context Menu Hook: Medical
function DP.Medical.onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    
    local modData = player:getModData()
    if not modData or not modData.hasBrokenTooth then return end
    
    local inv = player:getInventory()
    
    -- Extraction Options
    if inv:contains("Base.Pliers") then
        local chance = DP.Medical.calculateChance(player, "pliers")
        context:addOption(getText("IGUI_ContextMenu_ExtractPliers") .. " (" .. math.floor(chance) .. "%)", player, function()
            ISTimedActionQueue.add(ISExtractionAction:new(player, "pliers", 400))
        end)
    end
    
    if inv:contains("Base.Hammer") or inv:contains("Base.HammerStone") or inv:contains("Base.BallPeenHammer") then
        local chance = DP.Medical.calculateChance(player, "hammer")
        context:addOption(getText("IGUI_ContextMenu_ExtractHammer") .. " (" .. math.floor(chance) .. "%)", player, function()
            ISTimedActionQueue.add(ISExtractionAction:new(player, "hammer", 600))
        end)
    end

    -- Anesthetic
    if inv:contains("DentalPain.DentalAnesthetic") and not DP.isNumbed(player) then
        context:addOption(getText("IGUI_ContextMenu_TakeAnesthetic"), player, DP.Medical.takeAnesthetic)
    end
end

return DP
