-- DentalPain/Tests/FormulaCalculatorTests.lua
-- Property-based tests for FormulaCalculator
--
-- **Feature: dental-skill-system, Property 7: Skill Level Success Rate Formula**
-- **Feature: dental-skill-system, Property 13: Failure Damage Inverse Relationship**
-- **Feature: dental-skill-system, Property 14: Tool Modifier Difference**
-- **Validates: Requirements 5.1, 5.3, 5.4, 5.5**

require "DentalPain/Core"
require "DentalPain/SkillManager"
require "DentalPain/FormulaCalculator"

DentalPain.Tests = DentalPain.Tests or {}
DentalPain.Tests.FormulaCalculator = {}

local Tests = DentalPain.Tests.FormulaCalculator
local FormulaCalculator = DentalPain.FormulaCalculator
local SkillManager = DentalPain.SkillManager

-----------------------------------------------------------
-- Mock Player Object for Testing
-----------------------------------------------------------
local function createMockPlayer(dentalSkillLevel, doctorLevel, isNumbed)
    dentalSkillLevel = dentalSkillLevel or 0
    doctorLevel = doctorLevel or 0
    isNumbed = isNumbed or false
    
    local mockPlayer = {
        _modData = {
            anestheticTimer = isNumbed and 1 or 0
        },
        _perkLevels = {
            DentalCare = dentalSkillLevel,
            Doctor = doctorLevel
        }
    }
    
    function mockPlayer:getModData()
        return self._modData
    end
    
    function mockPlayer:getPerkLevel(perk)
        if perk == Perks.DentalCare then
            return self._perkLevels.DentalCare or 0
        elseif perk == Perks.Doctor then
            return self._perkLevels.Doctor or 0
        end
        return 0
    end
    
    return mockPlayer
end

-----------------------------------------------------------
-- Mock Perks for Testing (if not available)
-----------------------------------------------------------
if not Perks then
    Perks = {}
end
if not Perks.DentalCare then
    Perks.DentalCare = "DentalCare"
end
if not Perks.Doctor then
    Perks.Doctor = "Doctor"
end

-----------------------------------------------------------
-- Property 7: Skill Level Success Rate Formula
-- *For any* combination of Dental_Skill level (0-10) and Doctor level (0-10),
-- the extraction success chance SHALL equal:
-- min(95, BaseChance + (Dental_Skill * 5) + (Doctor * 10) + AnestheticBonus)
-- **Validates: Requirements 3.3, 5.1, 5.3**
-----------------------------------------------------------
function Tests.property_SkillLevelSuccessRateFormula(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    local function testRand(max)
        return math.random(0, max - 1)
    end
    
    for i = 1, iterations do
        -- Generate random skill levels 0-10
        local dentalSkill = testRand(11)
        local doctorSkill = testRand(11)
        local isNumbed = testRand(2) == 1
        local method = testRand(2) == 0 and "pliers" or "hammer"
        
        local mockPlayer = createMockPlayer(dentalSkill, doctorSkill, isNumbed)
        
        local isValid = true
        local failReason = nil
        
        -- Calculate expected value using the formula
        local base = (method == "pliers") and FormulaCalculator.BASE_PLIERS or FormulaCalculator.BASE_HAMMER
        local anestheticBonus = isNumbed and FormulaCalculator.ANESTHETIC_BONUS or 0
        local expectedChance = base 
            + (dentalSkill * FormulaCalculator.SKILL_BONUS) 
            + (doctorSkill * FormulaCalculator.DOCTOR_BONUS) 
            + anestheticBonus
        expectedChance = math.min(expectedChance, FormulaCalculator.MAX_CHANCE)
        
        -- Get actual value from FormulaCalculator
        local actualChance = FormulaCalculator.getExtractionChance(mockPlayer, method)
        
        if actualChance ~= expectedChance then
            isValid = false
            failReason = string.format(
                "Method=%s, DentalSkill=%d, DoctorSkill=%d, Numbed=%s: expected %d%%, got %d%%",
                method, dentalSkill, doctorSkill, tostring(isNumbed), expectedChance, actualChance
            )
        end
        
        -- Verify cap at 95%
        if isValid and actualChance > FormulaCalculator.MAX_CHANCE then
            isValid = false
            failReason = string.format(
                "Chance %d%% exceeds max cap of %d%%",
                actualChance, FormulaCalculator.MAX_CHANCE
            )
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                dentalSkill = dentalSkill,
                doctorSkill = doctorSkill,
                isNumbed = isNumbed,
                method = method,
                expected = expectedChance,
                actual = actualChance
            })
        end
    end
    
    return {
        property = "Skill Level Success Rate Formula (P7)",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Property 13: Failure Damage Inverse Relationship
-- *For any* failed extraction, the damage applied SHALL decrease
-- as Dental_Skill level increases (higher skill = less damage)
-- **Validates: Requirements 5.4**
-----------------------------------------------------------
function Tests.property_FailureDamageInverseRelationship(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    local function testRand(max)
        return math.random(0, max - 1)
    end
    
    for i = 1, iterations do
        -- Generate two different skill levels to compare
        local skillLevel1 = testRand(11)
        local skillLevel2 = testRand(11)
        
        -- Ensure they're different for meaningful comparison
        while skillLevel1 == skillLevel2 do
            skillLevel2 = testRand(11)
        end
        
        local mockPlayer1 = createMockPlayer(skillLevel1, 0, false)
        local mockPlayer2 = createMockPlayer(skillLevel2, 0, false)
        
        local damage1 = FormulaCalculator.getFailureDamage(mockPlayer1)
        local damage2 = FormulaCalculator.getFailureDamage(mockPlayer2)
        
        local isValid = true
        local failReason = nil
        
        -- Higher skill should result in less or equal damage
        if skillLevel1 > skillLevel2 then
            if damage1 > damage2 then
                isValid = false
                failReason = string.format(
                    "Higher skill (%d) has more damage (%d) than lower skill (%d) with damage (%d)",
                    skillLevel1, damage1, skillLevel2, damage2
                )
            end
        else
            if damage2 > damage1 then
                isValid = false
                failReason = string.format(
                    "Higher skill (%d) has more damage (%d) than lower skill (%d) with damage (%d)",
                    skillLevel2, damage2, skillLevel1, damage1
                )
            end
        end
        
        -- Verify damage is within expected bounds
        if isValid then
            if damage1 < FormulaCalculator.MIN_FAILURE_DAMAGE or damage1 > FormulaCalculator.BASE_FAILURE_DAMAGE then
                isValid = false
                failReason = string.format(
                    "Damage %d is outside bounds [%d, %d]",
                    damage1, FormulaCalculator.MIN_FAILURE_DAMAGE, FormulaCalculator.BASE_FAILURE_DAMAGE
                )
            end
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                skillLevel1 = skillLevel1,
                skillLevel2 = skillLevel2,
                damage1 = damage1,
                damage2 = damage2
            })
        end
    end
    
    return {
        property = "Failure Damage Inverse Relationship (P13)",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Property 14: Tool Modifier Difference
-- *For any* extraction attempt, the hammer base chance SHALL be
-- exactly 25% lower than the pliers base chance
-- **Validates: Requirements 5.5**
-----------------------------------------------------------
function Tests.property_ToolModifierDifference(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    local function testRand(max)
        return math.random(0, max - 1)
    end
    
    -- First verify the constant difference
    local expectedDifference = 25
    local actualDifference = FormulaCalculator.BASE_PLIERS - FormulaCalculator.BASE_HAMMER
    
    if actualDifference ~= expectedDifference then
        return {
            property = "Tool Modifier Difference (P14)",
            iterations = 1,
            passed = 0,
            failed = 1,
            failures = {{
                iteration = 0,
                reason = string.format(
                    "Base difference is %d, expected %d (pliers=%d, hammer=%d)",
                    actualDifference, expectedDifference,
                    FormulaCalculator.BASE_PLIERS, FormulaCalculator.BASE_HAMMER
                )
            }},
            success = false
        }
    end
    
    for i = 1, iterations do
        -- Generate random skill levels
        local dentalSkill = testRand(11)
        local doctorSkill = testRand(11)
        local isNumbed = testRand(2) == 1
        
        local mockPlayer = createMockPlayer(dentalSkill, doctorSkill, isNumbed)
        
        local pliersChance = FormulaCalculator.getExtractionChance(mockPlayer, "pliers")
        local hammerChance = FormulaCalculator.getExtractionChance(mockPlayer, "hammer")
        
        local isValid = true
        local failReason = nil
        
        -- The difference should be exactly 25 (unless capped)
        local difference = pliersChance - hammerChance
        
        -- If neither is capped, difference should be exactly 25
        local pliersUncapped = pliersChance < FormulaCalculator.MAX_CHANCE
        local hammerUncapped = hammerChance < FormulaCalculator.MAX_CHANCE
        
        if pliersUncapped and hammerUncapped then
            if difference ~= expectedDifference then
                isValid = false
                failReason = string.format(
                    "Uncapped difference is %d, expected %d (pliers=%d, hammer=%d)",
                    difference, expectedDifference, pliersChance, hammerChance
                )
            end
        else
            -- When capped, pliers should be >= hammer
            if pliersChance < hammerChance then
                isValid = false
                failReason = string.format(
                    "Pliers chance (%d) is less than hammer chance (%d)",
                    pliersChance, hammerChance
                )
            end
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                dentalSkill = dentalSkill,
                doctorSkill = doctorSkill,
                isNumbed = isNumbed,
                pliersChance = pliersChance,
                hammerChance = hammerChance
            })
        end
    end
    
    return {
        property = "Tool Modifier Difference (P14)",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Run All FormulaCalculator Property Tests
-----------------------------------------------------------
function Tests.runAll(iterations)
    iterations = iterations or 100
    
    print("[DentalPain Tests] Running FormulaCalculator Property-Based Tests...")
    print("  Iterations per property: " .. iterations)
    print("")
    
    local results = {}
    
    -- Property 7: Skill Level Success Rate Formula
    local result7 = Tests.property_SkillLevelSuccessRateFormula(iterations)
    table.insert(results, result7)
    
    -- Property 13: Failure Damage Inverse Relationship
    local result13 = Tests.property_FailureDamageInverseRelationship(iterations)
    table.insert(results, result13)
    
    -- Property 14: Tool Modifier Difference
    local result14 = Tests.property_ToolModifierDifference(iterations)
    table.insert(results, result14)
    
    -- Print results
    print("=== FORMULACALCULATOR PROPERTY TEST RESULTS ===")
    for _, result in ipairs(results) do
        local status = result.success and "PASSED" or "FAILED"
        print(string.format("  [%s] %s (%d/%d iterations)", 
            status, result.property, result.passed, result.iterations))
        
        if not result.success and #result.failures > 0 then
            print("    First failure:")
            local firstFail = result.failures[1]
            print("      Iteration: " .. firstFail.iteration)
            print("      Reason: " .. firstFail.reason)
        end
    end
    print("===============================================")
    
    -- Return overall success
    local allPassed = true
    for _, result in ipairs(results) do
        if not result.success then
            allPassed = false
            break
        end
    end
    
    return allPassed, results
end

-----------------------------------------------------------
-- Debug Menu Integration
-----------------------------------------------------------
function Tests.addDebugMenuOptions(subMenu, player)
    subMenu:addOption("--- FormulaCalculator Tests ---", nil, nil)
    
    subMenu:addOption("Run All Formula Tests (100 iter)", player, function()
        local success, results = Tests.runAll(100)
        if success then
            player:Say("[Formula Tests] All PASSED!")
        else
            player:Say("[Formula Tests] Some FAILED - check console")
        end
    end)
    
    subMenu:addOption("P7: Success Rate Formula", player, function()
        local result = Tests.property_SkillLevelSuccessRateFormula(100)
        if result.success then
            player:Say("[P7] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P7] FAILED - " .. result.failures[1].reason)
        end
    end)
    
    subMenu:addOption("P13: Failure Damage Inverse", player, function()
        local result = Tests.property_FailureDamageInverseRelationship(100)
        if result.success then
            player:Say("[P13] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P13] FAILED - " .. result.failures[1].reason)
        end
    end)
    
    subMenu:addOption("P14: Tool Modifier Difference", player, function()
        local result = Tests.property_ToolModifierDifference(100)
        if result.success then
            player:Say("[P14] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P14] FAILED - " .. result.failures[1].reason)
        end
    end)
end

return Tests
