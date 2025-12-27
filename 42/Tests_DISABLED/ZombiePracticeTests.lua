-- DentalPain/Tests/ZombiePracticeTests.lua
-- Property-based tests for ZombiePractice
--
-- **Feature: dental-skill-system, Property 10: Zombie Practice XP Rewards**
-- **Feature: dental-skill-system, Property 11: Zombie Practice Safety**
-- **Feature: dental-skill-system, Property 12: Zombie Corpse Extraction Limit**
-- **Validates: Requirements 4.2, 4.4, 4.5, 4.6**

require "DentalPain/Core"
require "DentalPain/SkillManager"
require "DentalPain/ZombiePractice"

DentalPain.Tests = DentalPain.Tests or {}
DentalPain.Tests.ZombiePractice = {}

local Tests = DentalPain.Tests.ZombiePractice
local ZombiePractice = DentalPain.ZombiePractice
local SkillManager = DentalPain.SkillManager

-----------------------------------------------------------
-- Mock Player Object for Testing
-----------------------------------------------------------
local function createMockPlayer(skillLevel)
    skillLevel = skillLevel or 0
    
    local mockPlayer = {
        _modData = {},
        _perkLevels = {
            DentalCare = skillLevel,
            Doctor = 0
        },
        _xp = {
            history = {}
        },
        _inventory = {
            items = {}
        },
        _health = 100,
        _bodyDamage = nil
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
    
    function mockPlayer:getXp()
        local xpObj = {
            player = mockPlayer,
            AddXP = function(self, perk, amount)
                table.insert(mockPlayer._xp.history, {
                    perk = perk,
                    amount = amount
                })
            end
        }
        return xpObj
    end
    
    function mockPlayer:getInventory()
        local invObj = {
            player = mockPlayer,
            AddItem = function(self, itemType)
                table.insert(mockPlayer._inventory.items, itemType)
            end,
            contains = function(self, itemType)
                for _, item in ipairs(mockPlayer._inventory.items) do
                    if item == itemType then return true end
                end
                return false
            end
        }
        return invObj
    end
    
    function mockPlayer:getBodyDamage()
        if not mockPlayer._bodyDamage then
            mockPlayer._bodyDamage = {
                _parts = {},
                getBodyPart = function(self, partType)
                    if not self._parts[partType] then
                        self._parts[partType] = {
                            _pain = 0,
                            _bleeding = false,
                            _deepWound = false,
                            getAdditionalPain = function(self) return self._pain end,
                            setAdditionalPain = function(self, val) self._pain = val end,
                            setBleeding = function(self, val) self._bleeding = val end,
                            generateDeepWound = function(self) self._deepWound = true end
                        }
                    end
                    return self._parts[partType]
                end
            }
        end
        return mockPlayer._bodyDamage
    end
    
    return mockPlayer
end

-----------------------------------------------------------
-- Mock Zombie Corpse for Testing
-----------------------------------------------------------
local function createMockZombie(teethExtracted)
    teethExtracted = teethExtracted or 0
    
    local mockZombie = {
        _modData = {
            dentalTeethExtracted = teethExtracted
        }
    }
    
    function mockZombie:getModData()
        return self._modData
    end
    
    return mockZombie
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
-- Mock ZombRand for Testing
-----------------------------------------------------------
local originalZombRand = ZombRand
if not ZombRand then
    ZombRand = function(max)
        return math.random(0, max - 1)
    end
end

-----------------------------------------------------------
-- Property 10: Zombie Practice XP Rewards
-- *For any* zombie practice extraction:
-- - Success SHALL award exactly 50% of self-extraction XP (25 XP)
-- - Failure SHALL award exactly 25% of success XP (6 XP)
-- **Validates: Requirements 4.2, 4.4**
-----------------------------------------------------------
function Tests.property_ZombiePracticeXPRewards(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    -- Expected XP values from SkillManager
    local expectedSuccessXP = SkillManager.XP.ZOMBIE_EXTRACTION_SUCCESS -- 25
    local expectedFailXP = SkillManager.XP.ZOMBIE_EXTRACTION_FAIL -- 6
    
    -- Verify XP values match requirements
    local selfSuccessXP = SkillManager.XP.SELF_EXTRACTION_SUCCESS -- 50
    
    -- Check that zombie success XP is 50% of self success XP
    if expectedSuccessXP ~= math.floor(selfSuccessXP * 0.5) then
        return {
            property = "Zombie Practice XP Rewards",
            iterations = 1,
            passed = 0,
            failed = 1,
            failures = {{
                iteration = 0,
                reason = "ZOMBIE_EXTRACTION_SUCCESS (" .. expectedSuccessXP .. 
                    ") is not 50% of SELF_EXTRACTION_SUCCESS (" .. selfSuccessXP .. ")"
            }},
            success = false
        }
    end
    
    -- Check that zombie fail XP is ~25% of zombie success XP
    local expectedFailFromSuccess = math.floor(expectedSuccessXP * 0.25)
    -- Allow small rounding difference (6 vs 6.25)
    if math.abs(expectedFailXP - expectedFailFromSuccess) > 1 then
        return {
            property = "Zombie Practice XP Rewards",
            iterations = 1,
            passed = 0,
            failed = 1,
            failures = {{
                iteration = 0,
                reason = "ZOMBIE_EXTRACTION_FAIL (" .. expectedFailXP .. 
                    ") is not ~25% of ZOMBIE_EXTRACTION_SUCCESS (" .. expectedSuccessXP .. ")"
            }},
            success = false
        }
    end
    
    for i = 1, iterations do
        local mockPlayer = createMockPlayer(0)
        local mockZombie = createMockZombie(0)
        
        -- Clear XP history
        mockPlayer._xp.history = {}
        
        -- Perform extraction (result is random)
        local result = ZombiePractice.performExtraction(mockPlayer, mockZombie)
        
        local isValid = true
        local failReason = nil
        
        -- Check XP was awarded
        if #mockPlayer._xp.history == 0 then
            isValid = false
            failReason = "No XP was awarded"
        else
            local xpAwarded = mockPlayer._xp.history[1].amount
            
            if result then
                -- Success - should award ZOMBIE_EXTRACTION_SUCCESS XP
                if xpAwarded ~= expectedSuccessXP then
                    isValid = false
                    failReason = "Success awarded " .. xpAwarded .. " XP, expected " .. expectedSuccessXP
                end
            else
                -- Failure - should award ZOMBIE_EXTRACTION_FAIL XP
                if xpAwarded ~= expectedFailXP then
                    isValid = false
                    failReason = "Failure awarded " .. xpAwarded .. " XP, expected " .. expectedFailXP
                end
            end
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                result = result
            })
        end
    end
    
    return {
        property = "Zombie Practice XP Rewards",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Property 11: Zombie Practice Safety
-- *For any* zombie practice extraction (success or failure),
-- the player's health and body damage SHALL remain unchanged.
-- **Validates: Requirements 4.5**
-----------------------------------------------------------
function Tests.property_ZombiePracticeSafety(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    for i = 1, iterations do
        local mockPlayer = createMockPlayer(0)
        local mockZombie = createMockZombie(0)
        
        -- Record initial body state
        local bodyDamage = mockPlayer:getBodyDamage()
        local headPart = bodyDamage:getBodyPart("Head")
        local initialPain = headPart:getAdditionalPain()
        local initialBleeding = headPart._bleeding
        local initialDeepWound = headPart._deepWound
        
        -- Perform extraction
        local result = ZombiePractice.performExtraction(mockPlayer, mockZombie)
        
        local isValid = true
        local failReason = nil
        
        -- Check body damage unchanged
        local finalPain = headPart:getAdditionalPain()
        local finalBleeding = headPart._bleeding
        local finalDeepWound = headPart._deepWound
        
        if finalPain ~= initialPain then
            isValid = false
            failReason = "Pain changed from " .. initialPain .. " to " .. finalPain .. 
                " (result: " .. tostring(result) .. ")"
        end
        
        if isValid and finalBleeding ~= initialBleeding then
            isValid = false
            failReason = "Bleeding changed from " .. tostring(initialBleeding) .. 
                " to " .. tostring(finalBleeding) .. " (result: " .. tostring(result) .. ")"
        end
        
        if isValid and finalDeepWound ~= initialDeepWound then
            isValid = false
            failReason = "Deep wound changed from " .. tostring(initialDeepWound) .. 
                " to " .. tostring(finalDeepWound) .. " (result: " .. tostring(result) .. ")"
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                result = result
            })
        end
    end
    
    return {
        property = "Zombie Practice Safety",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Property 12: Zombie Corpse Extraction Limit
-- *For any* zombie corpse, after 5 extractions have been
-- performed, no further extractions SHALL be possible.
-- **Validates: Requirements 4.6**
-----------------------------------------------------------
function Tests.property_ZombieCorpseExtractionLimit(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    for i = 1, iterations do
        local mockPlayer = createMockPlayer(0)
        local mockZombie = createMockZombie(0)
        
        local isValid = true
        local failReason = nil
        
        -- Perform 5 extractions (the maximum)
        for j = 1, 5 do
            local canPractice = ZombiePractice.canPractice(mockZombie)
            if not canPractice then
                isValid = false
                failReason = "canPractice returned false on extraction " .. j .. " (should allow up to 5)"
                break
            end
            
            local teethBefore = ZombiePractice.getTeethRemaining(mockZombie)
            ZombiePractice.performExtraction(mockPlayer, mockZombie)
            local teethAfter = ZombiePractice.getTeethRemaining(mockZombie)
            
            -- Verify teeth count decreased
            if teethAfter ~= teethBefore - 1 then
                isValid = false
                failReason = "Teeth count didn't decrease properly on extraction " .. j .. 
                    " (before: " .. teethBefore .. ", after: " .. teethAfter .. ")"
                break
            end
        end
        
        -- After 5 extractions, no more should be possible
        if isValid then
            local teethRemaining = ZombiePractice.getTeethRemaining(mockZombie)
            if teethRemaining ~= 0 then
                isValid = false
                failReason = "After 5 extractions, teeth remaining is " .. teethRemaining .. ", expected 0"
            end
        end
        
        if isValid then
            local canPracticeAfter = ZombiePractice.canPractice(mockZombie)
            if canPracticeAfter then
                isValid = false
                failReason = "canPractice returned true after 5 extractions (should be false)"
            end
        end
        
        -- Try to perform 6th extraction (should fail)
        if isValid then
            local result = ZombiePractice.performExtraction(mockPlayer, mockZombie)
            if result then
                isValid = false
                failReason = "6th extraction succeeded (should fail)"
            end
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason
            })
        end
    end
    
    return {
        property = "Zombie Corpse Extraction Limit",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Run All ZombiePractice Property Tests
-----------------------------------------------------------
function Tests.runAll(iterations)
    iterations = iterations or 100
    
    print("[DentalPain Tests] Running ZombiePractice Property-Based Tests...")
    print("  Iterations per property: " .. iterations)
    print("")
    
    local results = {}
    
    -- Property 10: Zombie Practice XP Rewards
    local result10 = Tests.property_ZombiePracticeXPRewards(iterations)
    table.insert(results, result10)
    
    -- Property 11: Zombie Practice Safety
    local result11 = Tests.property_ZombiePracticeSafety(iterations)
    table.insert(results, result11)
    
    -- Property 12: Zombie Corpse Extraction Limit
    local result12 = Tests.property_ZombieCorpseExtractionLimit(iterations)
    table.insert(results, result12)
    
    -- Print results
    print("=== ZOMBIEPRACTICE PROPERTY TEST RESULTS ===")
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
    print("=============================================")
    
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
    subMenu:addOption("--- ZombiePractice Tests ---", nil, nil)
    
    subMenu:addOption("Run All Zombie Tests (100 iter)", player, function()
        local success, results = Tests.runAll(100)
        if success then
            player:Say("[Zombie Tests] All PASSED!")
        else
            player:Say("[Zombie Tests] Some FAILED - check console")
        end
    end)
    
    subMenu:addOption("P10: XP Rewards", player, function()
        local result = Tests.property_ZombiePracticeXPRewards(100)
        if result.success then
            player:Say("[P10] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P10] FAILED - " .. result.failures[1].reason)
        end
    end)
    
    subMenu:addOption("P11: Practice Safety", player, function()
        local result = Tests.property_ZombiePracticeSafety(100)
        if result.success then
            player:Say("[P11] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P11] FAILED - " .. result.failures[1].reason)
        end
    end)
    
    subMenu:addOption("P12: Extraction Limit", player, function()
        local result = Tests.property_ZombieCorpseExtractionLimit(100)
        if result.success then
            player:Say("[P12] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P12] FAILED - " .. result.failures[1].reason)
        end
    end)
end

return Tests
