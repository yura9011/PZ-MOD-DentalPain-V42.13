-- DentalPain/SkillManager.lua
-- Manages Dental Care skill XP, levels, and ability unlocks
-- Uses ModData instead of custom Perks for compatibility
-- Requirements: 3.2, 3.3, 3.4, 3.5

require "DentalPain/Core"

DentalPain.SkillManager = {}

local SkillManager = DentalPain.SkillManager

-----------------------------------------------------------
-- XP Constants
-----------------------------------------------------------
SkillManager.XP = {
    SELF_EXTRACTION_SUCCESS = 50,
    SELF_EXTRACTION_FAIL = 10,
    ZOMBIE_EXTRACTION_SUCCESS = 25,  -- 50% of self
    ZOMBIE_EXTRACTION_FAIL = 6,      -- ~25% of success
    CAVITY_FILL = 30,
}

-- XP required per level (cumulative)
SkillManager.XP_PER_LEVEL = 100

-----------------------------------------------------------
-- Skill Unlock Thresholds
-----------------------------------------------------------
SkillManager.UNLOCKS = {
    cavity_fill = 3,
    craft_tools = 5,
}

-----------------------------------------------------------
-- Max Skill Level (Requirement 3.6)
-----------------------------------------------------------
SkillManager.MAX_LEVEL = 10

-----------------------------------------------------------
-- Get Level
-- Returns current Dental Care skill level (0-10) from ModData
-----------------------------------------------------------
function SkillManager.getLevel(player)
    if not player then return 0 end
    
    local modData = player:getModData()
    if not modData then return 0 end
    
    local xp = modData.dentalCareXP or 0
    local level = math.floor(xp / SkillManager.XP_PER_LEVEL)
    return math.min(level, SkillManager.MAX_LEVEL)
end

-----------------------------------------------------------
-- Get XP
-- Returns current XP amount
-----------------------------------------------------------
function SkillManager.getXP(player)
    if not player then return 0 end
    
    local modData = player:getModData()
    if not modData then return 0 end
    
    return modData.dentalCareXP or 0
end

-----------------------------------------------------------
-- Award XP
-- Adds XP to Dental Care skill based on action type
-- xpType: key from SkillManager.XP table
-----------------------------------------------------------
function SkillManager.awardXP(player, xpType)
    if not player then return false end
    
    local xpAmount = SkillManager.XP[xpType]
    if not xpAmount then
        DentalPain.debug("SkillManager: Unknown XP type '" .. tostring(xpType) .. "'")
        return false
    end
    
    local modData = player:getModData()
    if not modData then return false end
    
    -- Check if already at max level
    local currentLevel = SkillManager.getLevel(player)
    if currentLevel >= SkillManager.MAX_LEVEL then
        DentalPain.debug("SkillManager: Already at max level, no XP awarded")
        return false
    end
    
    -- Add XP to ModData
    modData.dentalCareXP = (modData.dentalCareXP or 0) + xpAmount
    
    -- Check for level up
    local newLevel = SkillManager.getLevel(player)
    if newLevel > currentLevel then
        DentalPain.debug("SkillManager: Level up! Now level " .. newLevel)
        player:Say("[Dental Care] Level " .. newLevel .. "!")
    end
    
    DentalPain.debug("SkillManager: Awarded " .. xpAmount .. " XP for " .. xpType .. " (Total: " .. modData.dentalCareXP .. ")")
    
    return true
end

-----------------------------------------------------------
-- Is Unlocked
-- Checks if a specific ability is unlocked based on skill level
-- ability: "cavity_fill" (level 3), "craft_tools" (level 5)
-----------------------------------------------------------
function SkillManager.isUnlocked(player, ability)
    if not player then return false end
    if not ability then return false end
    
    local requiredLevel = SkillManager.UNLOCKS[ability]
    if not requiredLevel then
        DentalPain.debug("SkillManager: Unknown ability '" .. tostring(ability) .. "'")
        return false
    end
    
    local currentLevel = SkillManager.getLevel(player)
    return currentLevel >= requiredLevel
end

-----------------------------------------------------------
-- Get All Unlocked Abilities
-- Returns a table of all currently unlocked abilities
-----------------------------------------------------------
function SkillManager.getUnlockedAbilities(player)
    if not player then return {} end
    
    local unlocked = {}
    local currentLevel = SkillManager.getLevel(player)
    
    for ability, requiredLevel in pairs(SkillManager.UNLOCKS) do
        if currentLevel >= requiredLevel then
            table.insert(unlocked, ability)
        end
    end
    
    return unlocked
end

return SkillManager
