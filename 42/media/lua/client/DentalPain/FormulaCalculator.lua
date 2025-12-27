-- DentalPain/FormulaCalculator.lua
-- Calculates extraction success rates and failure damage based on skill levels
-- Requirements: 5.1, 5.2, 5.3, 5.4, 5.5

require "DentalPain/Core"
require "DentalPain/SkillManager"

DentalPain.FormulaCalculator = {}

local FormulaCalculator = DentalPain.FormulaCalculator
local SkillManager = DentalPain.SkillManager

-----------------------------------------------------------
-- Base Chances (Requirement 5.2)
-----------------------------------------------------------
FormulaCalculator.BASE_PLIERS = 60   -- Base success % with pliers
FormulaCalculator.BASE_HAMMER = 35   -- Base success % with hammer (25% lower than pliers)

-----------------------------------------------------------
-- Bonuses (Requirements 5.1, 5.3)
-----------------------------------------------------------
FormulaCalculator.SKILL_BONUS = 5      -- % per Dental Care level
FormulaCalculator.DOCTOR_BONUS = 10    -- % per Doctor level
FormulaCalculator.ANESTHETIC_BONUS = 30 -- % bonus when numbed

-----------------------------------------------------------
-- Caps (Requirement 5.3)
-----------------------------------------------------------
FormulaCalculator.MAX_CHANCE = 95      -- Maximum success rate cap

-----------------------------------------------------------
-- Failure Damage Constants (Requirement 5.4)
-----------------------------------------------------------
FormulaCalculator.BASE_FAILURE_DAMAGE = 50  -- Base damage on failed extraction
FormulaCalculator.DAMAGE_REDUCTION_PER_LEVEL = 4  -- Damage reduction per skill level
FormulaCalculator.MIN_FAILURE_DAMAGE = 10   -- Minimum damage on failure

-----------------------------------------------------------
-- Get Extraction Chance
-- Calculates extraction success probability using formula:
-- BaseChance + (Dental_Skill * 5) + (Doctor * 10) + AnestheticBonus
-- Capped at 95% max
-- 
-- @param player - The player performing extraction
-- @param method - "pliers" or "hammer"
-- @return number - Success chance percentage (0-95)
-- Requirements: 5.1, 5.2, 5.3
-----------------------------------------------------------
function FormulaCalculator.getExtractionChance(player, method)
    if not player then return 0 end
    
    -- Get base chance based on tool (Requirement 5.2, 5.5)
    local base
    if method == "pliers" then
        base = FormulaCalculator.BASE_PLIERS
    else
        base = FormulaCalculator.BASE_HAMMER
    end
    
    -- Get Dental Care skill level (Requirement 5.1)
    local dentalSkill = SkillManager.getLevel(player)
    
    -- Get Doctor skill level (Requirement 5.1)
    local doctorSkill = 0
    if player.getPerkLevel then
        doctorSkill = player:getPerkLevel(Perks.Doctor) or 0
    end
    
    -- Check for anesthetic bonus
    local anestheticBonus = 0
    if DentalPain.isNumbed and DentalPain.isNumbed(player) then
        anestheticBonus = FormulaCalculator.ANESTHETIC_BONUS
    end
    
    -- Calculate total chance (Requirement 5.1)
    local chance = base 
        + (dentalSkill * FormulaCalculator.SKILL_BONUS) 
        + (doctorSkill * FormulaCalculator.DOCTOR_BONUS) 
        + anestheticBonus
    
    -- Cap at maximum (Requirement 5.3)
    return math.min(chance, FormulaCalculator.MAX_CHANCE)
end

-----------------------------------------------------------
-- Get Failure Damage
-- Calculates damage applied on failed extraction
-- Higher skill = less damage (inverse relationship)
-- 
-- @param player - The player who failed extraction
-- @return number - Damage amount
-- Requirement: 5.4
-----------------------------------------------------------
function FormulaCalculator.getFailureDamage(player)
    if not player then return FormulaCalculator.BASE_FAILURE_DAMAGE end
    
    -- Get Dental Care skill level
    local dentalSkill = SkillManager.getLevel(player)
    
    -- Calculate damage with inverse skill relationship
    -- Higher skill = less damage
    local damage = FormulaCalculator.BASE_FAILURE_DAMAGE 
        - (dentalSkill * FormulaCalculator.DAMAGE_REDUCTION_PER_LEVEL)
    
    -- Ensure minimum damage
    return math.max(damage, FormulaCalculator.MIN_FAILURE_DAMAGE)
end

-----------------------------------------------------------
-- Get Tool Base Chance
-- Returns the base chance for a specific tool
-- Useful for UI display
-- 
-- @param method - "pliers" or "hammer"
-- @return number - Base chance percentage
-----------------------------------------------------------
function FormulaCalculator.getToolBaseChance(method)
    if method == "pliers" then
        return FormulaCalculator.BASE_PLIERS
    else
        return FormulaCalculator.BASE_HAMMER
    end
end

-----------------------------------------------------------
-- Get Tool Modifier Difference
-- Returns the difference between pliers and hammer base chances
-- Should always be 25 (Requirement 5.5)
-- 
-- @return number - Difference in base chances
-----------------------------------------------------------
function FormulaCalculator.getToolModifierDifference()
    return FormulaCalculator.BASE_PLIERS - FormulaCalculator.BASE_HAMMER
end

return FormulaCalculator
