-- DentalPain/Medical.lua
-- Logic for dental pain, anesthetics, and extractions

require "DentalPain/ToothManager"
require "DentalPain/FormulaCalculator"
require "DentalPain/SkillManager"

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
-- Now uses FormulaCalculator for skill-based calculations
function DP.Medical.calculateChance(player, method)
    return DP.FormulaCalculator.getExtractionChance(player, method)
end

-- Perform tooth extraction
-- Now uses ToothManager for individual tooth tracking
function DP.Medical.performExtraction(player, method)
    local modData = player:getModData()
    
    -- Find a broken tooth to extract using ToothManager
    local brokenTooth = DP.ToothManager.getFirstBrokenTooth(player)
    
    -- Fallback to legacy hasBrokenTooth flag for backwards compatibility
    if not brokenTooth and not modData.hasBrokenTooth then 
        return 
    end
    
    local chance = DP.Medical.calculateChance(player, method)
    local roll = ZombRand(100)
    
    DentalPain.playCrunchSound(player)
    DentalPain.playPainSound(player)
    
    if roll < chance then
        -- SUCCESS
        if brokenTooth then
            -- Use ToothManager to extract the specific tooth
            DP.ToothManager.extractTooth(player, brokenTooth.index)
        else
            -- Legacy fallback
            modData.hasBrokenTooth = false
            modData.teethExtracted = (modData.teethExtracted or 0) + 1
        end
        
        DP.Dialogue.sayRandom(player, "Extraction", "Success")
        
        -- Apply some residual pain even if successful
        local bodyDamage = player:getBodyDamage()
        local head = bodyDamage:getBodyPart(BodyPartType.Head)
        head:setAdditionalPain(head:getAdditionalPain() + ZombRand(10, 21))
        
        -- Check if all teeth are extracted
        if not DP.ToothManager.hasAnyTeeth(player) then
            DP.debug("All teeth extracted - dental pain mechanics disabled")
        end
        
        -- Award XP for successful extraction
        DP.SkillManager.awardXP(player, "SELF_EXTRACTION_SUCCESS")
    else
        -- FAILURE - Bleeding! (shows in Health Panel)
        -- Use skill-based failure damage (Requirement 5.4)
        local failureDamage = DP.FormulaCalculator.getFailureDamage(player)
        
        local bodyDamage = player:getBodyDamage()
        local head = bodyDamage:getBodyPart(BodyPartType.Head)
        head:generateDeepWound()
        head:setBleeding(true)
        head:setAdditionalPain(head:getAdditionalPain() + failureDamage)
        
        DP.Dialogue.sayRandom(player, "Extraction", "Fail")
        
        -- Award XP for failed extraction attempt
        DP.SkillManager.awardXP(player, "SELF_EXTRACTION_FAIL")
    end
end

-- Tooth Break Logic
-- Now uses ToothManager for individual tooth tracking
function DP.Medical.checkBreak(player)
    local health = DP.getDentalHealth(player)
    if health >= DP.Config.MildThreshold then return end
    
    local modData = player:getModData()
    
    -- Check if there's already a broken tooth using ToothManager
    local existingBroken = DP.ToothManager.getFirstBrokenTooth(player)
    if existingBroken then return end
    
    -- Legacy check
    if modData.hasBrokenTooth then return end
    
    -- Check if player has any teeth left
    if not DP.ToothManager.hasAnyTeeth(player) then return end
    
    -- Chance increases as health drops
    if ZombRand(100) < 5 then -- Fixed 5% per check for simplicity
        -- Apply damage to break a random tooth
        local damagedIndex = DP.ToothManager.applyDamage(player, 100) -- 100 damage guarantees break
        
        if damagedIndex then
            DentalPain.playCrunchSound(player)
            DentalPain.playPainSound(player)
            DP.Dialogue.sayRandom(player, "Extraction", "Broken")
            
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            head:setAdditionalPain(DP.Config.BrokenToothPain)
            
            -- Also set legacy flag for backwards compatibility
            modData.hasBrokenTooth = true
        end
    end
end

-- Context Menu Hook: Medical
-- Updated to show skill level in extraction options (Requirement 5.1)
function DP.Medical.onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    
    local modData = player:getModData()
    
    -- Check for broken tooth using ToothManager first, then legacy flag
    local brokenTooth = DP.ToothManager.getFirstBrokenTooth(player)
    local hasBroken = brokenTooth ~= nil or (modData and modData.hasBrokenTooth)
    
    if not hasBroken then return end
    
    local inv = player:getInventory()
    
    -- Get skill level for display
    local skillLevel = DP.SkillManager.getLevel(player)
    local skillInfo = " [Skill: " .. skillLevel .. "]"
    
    -- Extraction Options - now shows skill level and uses FormulaCalculator
    if inv:contains("Base.Pliers") then
        local chance = DP.FormulaCalculator.getExtractionChance(player, "pliers")
        local toothInfo = brokenTooth and (" - " .. brokenTooth.name) or ""
        local optionText = getText("ContextMenu_ExtractPliers") .. toothInfo .. " (" .. math.floor(chance) .. "%)" .. skillInfo
        context:addOption(optionText, player, function()
            ISTimedActionQueue.add(ISExtractionAction:new(player, "pliers", 400))
        end)
    end
    
    if inv:contains("Base.Hammer") or inv:contains("Base.HammerStone") or inv:contains("Base.BallPeenHammer") then
        local chance = DP.FormulaCalculator.getExtractionChance(player, "hammer")
        local toothInfo = brokenTooth and (" - " .. brokenTooth.name) or ""
        local optionText = getText("ContextMenu_ExtractHammer") .. toothInfo .. " (" .. math.floor(chance) .. "%)" .. skillInfo
        context:addOption(optionText, player, function()
            ISTimedActionQueue.add(ISExtractionAction:new(player, "hammer", 600))
        end)
    end

    -- Anesthetic
    if inv:contains("DentalPain.DentalAnesthetic") and not DP.isNumbed(player) then
        context:addOption(getText("ContextMenu_TakeAnesthetic"), player, DP.Medical.takeAnesthetic)
    end
end

return DP
