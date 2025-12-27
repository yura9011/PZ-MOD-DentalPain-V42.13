-- DentalPain/ZombiePractice.lua
-- Zombie dental practice system for safe skill training
-- Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6

require "DentalPain/Core"
require "DentalPain/SkillManager"
require "DentalPain/FormulaCalculator"

DentalPain.ZombiePractice = {}

local ZombiePractice = DentalPain.ZombiePractice
local SkillManager = DentalPain.SkillManager
local FormulaCalculator = DentalPain.FormulaCalculator

-----------------------------------------------------------
-- Constants
-----------------------------------------------------------
ZombiePractice.MAX_TEETH_PER_CORPSE = 5  -- Requirement 4.6

-----------------------------------------------------------
-- Get Teeth Remaining
-- Returns the number of teeth remaining on a zombie corpse (0-5)
-- @param zombie - The zombie corpse (IsoDeadBody or IsoZombie)
-- @return number - Teeth remaining (0-5)
-----------------------------------------------------------
function ZombiePractice.getTeethRemaining(zombie)
    if not zombie then return 0 end
    
    local modData = zombie:getModData()
    if not modData then return ZombiePractice.MAX_TEETH_PER_CORPSE end
    
    local extracted = modData.dentalTeethExtracted or 0
    return math.max(0, ZombiePractice.MAX_TEETH_PER_CORPSE - extracted)
end

-----------------------------------------------------------
-- Can Practice
-- Checks if a zombie corpse can be practiced on
-- @param zombie - The zombie corpse
-- @return boolean - True if practice is possible
-- Requirement: 4.6
-----------------------------------------------------------
function ZombiePractice.canPractice(zombie)
    if not zombie then return false end
    return ZombiePractice.getTeethRemaining(zombie) > 0
end

-----------------------------------------------------------
-- Perform Extraction
-- Performs a practice extraction on a zombie corpse
-- - Awards 50% XP on success (Requirement 4.2)
-- - Awards 25% XP on failure (Requirement 4.4)
-- - No damage to player (Requirement 4.5)
-- - Adds ZombieTooth item on success (Requirement 4.3)
-- 
-- @param player - The player performing extraction
-- @param zombie - The zombie corpse
-- @return boolean - True if extraction succeeded
-----------------------------------------------------------
function ZombiePractice.performExtraction(player, zombie)
    if not player or not zombie then return false end
    
    -- Check if practice is still possible
    if not ZombiePractice.canPractice(zombie) then
        DentalPain.debug("ZombiePractice: No teeth remaining on corpse")
        return false
    end
    
    -- Calculate success chance using FormulaCalculator
    local chance = FormulaCalculator.getExtractionChance(player, "pliers")
    local roll = ZombRand(100)
    
    -- Update zombie corpse teeth count
    local zombieData = zombie:getModData()
    zombieData.dentalTeethExtracted = (zombieData.dentalTeethExtracted or 0) + 1
    
    -- Play extraction sounds
    DentalPain.playCrunchSound(player)
    
    if roll < chance then
        -- SUCCESS
        -- Add ZombieTooth item to inventory (Requirement 4.3)
        player:getInventory():AddItem("DentalPain.ZombieTooth")
        
        -- Award 50% XP (Requirement 4.2)
        SkillManager.awardXP(player, "ZOMBIE_EXTRACTION_SUCCESS")
        
        DentalPain.debug("ZombiePractice: Success! Teeth remaining: " .. ZombiePractice.getTeethRemaining(zombie))
        
        -- Show success dialogue if available
        if DentalPain.Dialogue then
            DentalPain.Dialogue.sayRandom(player, "ZombiePractice", "Success")
        end
        
        return true
    else
        -- FAILURE
        -- Award 25% XP (Requirement 4.4)
        SkillManager.awardXP(player, "ZOMBIE_EXTRACTION_FAIL")
        
        -- NO damage to player (Requirement 4.5)
        -- This is intentionally empty - zombie practice is safe
        
        DentalPain.debug("ZombiePractice: Failed. Teeth remaining: " .. ZombiePractice.getTeethRemaining(zombie))
        
        -- Show failure dialogue if available
        if DentalPain.Dialogue then
            DentalPain.Dialogue.sayRandom(player, "ZombiePractice", "Fail")
        end
        
        return false
    end
end

-----------------------------------------------------------
-- Context Menu Hook
-- Adds "Practice Extraction" option to zombie corpse context menu
-- Updated to show skill level (Requirement 5.1)
-- Requirement: 4.1
-----------------------------------------------------------
function ZombiePractice.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end
    
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    
    -- Check if player has pliers equipped or in inventory
    local inv = player:getInventory()
    if not inv:contains("Base.Pliers") then 
        return 
    end
    
    -- In B42, we need to find zombie corpses from the tile, not worldObjects
    -- Try to get the square/tile from worldObjects
    for _, obj in ipairs(worldObjects) do
        local square = nil
        
        if obj.getSquare then
            square = obj:getSquare()
        elseif instanceof(obj, "IsoGridSquare") then
            square = obj
        end
        
        if square then
            -- Look for dead bodies on this square
            local corpses = square:getDeadBodys()
            if corpses then
                for i = 0, corpses:size() - 1 do
                    local corpse = corpses:get(i)
                    DentalPain.debug("ZombiePractice: Found corpse on tile!")
                    
                    if ZombiePractice.canPractice(corpse) then
                        local teethLeft = ZombiePractice.getTeethRemaining(corpse)
                        local chance = FormulaCalculator.getExtractionChance(player, "pliers")
                        local skillLevel = SkillManager.getLevel(player)
                        
                        local optionText = getText("ContextMenu_PracticeExtraction") 
                            .. " (" .. teethLeft .. " " .. getText("ContextMenu_TeethLeft") .. ") - " 
                            .. math.floor(chance) .. "% [Skill: " .. skillLevel .. "]"
                        
                        context:addOption(optionText, player, function()
                            ISTimedActionQueue.add(ISZombiePracticeAction:new(player, corpse, 300))
                        end)
                        return -- Only add option once
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------
-- Register Event Hook
-----------------------------------------------------------
Events.OnFillWorldObjectContextMenu.Add(ZombiePractice.onFillWorldObjectContextMenu)

return ZombiePractice
