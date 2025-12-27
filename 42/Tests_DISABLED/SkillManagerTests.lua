-- DentalPain/Tests/SkillManagerTests.lua
-- Property-based tests for SkillManager
--
-- **Feature: dental-skill-system, Property 8: Skill Unlock Thresholds**
-- **Feature: dental-skill-system, Property 9: Skill Level Cap**
-- **Validates: Requirements 3.4, 3.5, 3.6**

require "DentalPain/Core"
require "DentalPain/SkillManager"

DentalPain.Tests = DentalPain.Tests or {}
DentalPain.Tests.SkillManager = {}

local Tests = DentalPain.Tests.SkillManager
local SkillManager = DentalPain.SkillManager

-----------------------------------------------------------
-- Mock Player Object for Testing
-----------------------------------------------------------
local function createMockPlayer(skillLevel)
    skillLevel = skillLevel or 0
    
    local mockPlayer = {
        _modData = {},
        _perkLevels = {
            DentalCare = skillLevel
        },
        _xp = {}
    }
    
    function mockPlayer:getModData()
        return self._modData
    end
    
    function mockPlayer:getPerkLevel(perk)
        if perk == Perks.DentalCare then
            return self._perkLevels.DentalCare or 0
        end
        return 0
    end
    
    function mockPlayer:getXp()
        local xpObj = {
            player = mockPlayer,
            AddXP = function(self, perk, amount)
                -- Simulate XP addition (simplified)
                if perk == Perks.DentalCare then
                    -- In real game, XP accumulates and levels up
                    -- For testing, we just track that XP was added
                    mockPlayer._xp.lastPerk = perk
                    mockPlayer._xp.lastAmount = amount
                end
            end
        }
        return xpObj
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

-----------------------------------------------------------
-- Property 8: Skill Unlock Thresholds
-- *For any* player:
-- - "cavity_fill" ability SHALL be locked when Dental_Skill < 3
-- - "cavity_fill" ability SHALL be unlocked when Dental_Skill >= 3
-- - "craft_tools" ability SHALL be locked when Dental_Skill < 5
-- - "craft_tools" ability SHALL be unlocked when Dental_Skill >= 5
-- **Validates: Requirements 3.4, 3.5**
-----------------------------------------------------------
function Tests.property_SkillUnlockThresholds(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    local function testRand(max)
        return math.random(0, max - 1)
    end
    
    for i = 1, iterations do
        -- Generate random skill level 0-10
        local skillLevel = testRand(11)
        local mockPlayer = createMockPlayer(skillLevel)
        
        local isValid = true
        local failReason = nil
        
        -- Test cavity_fill (threshold: 3)
        local cavityFillUnlocked = SkillManager.isUnlocked(mockPlayer, "cavity_fill")
        local expectedCavityFill = skillLevel >= 3
        
        if cavityFillUnlocked ~= expectedCavityFill then
            isValid = false
            failReason = "cavity_fill: level " .. skillLevel .. 
                ", expected " .. tostring(expectedCavityFill) .. 
                ", got " .. tostring(cavityFillUnlocked)
        end
        
        -- Test craft_tools (threshold: 5)
        if isValid then
            local craftToolsUnlocked = SkillManager.isUnlocked(mockPlayer, "craft_tools")
            local expectedCraftTools = skillLevel >= 5
            
            if craftToolsUnlocked ~= expectedCraftTools then
                isValid = false
                failReason = "craft_tools: level " .. skillLevel .. 
                    ", expected " .. tostring(expectedCraftTools) .. 
                    ", got " .. tostring(craftToolsUnlocked)
            end
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                skillLevel = skillLevel
            })
        end
    end
    
    return {
        property = "Skill Unlock Thresholds",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Property 9: Skill Level Cap
-- *For any* amount of XP gained, the Dental_Skill level
-- SHALL never exceed 10.
-- **Validates: Requirements 3.6**
-----------------------------------------------------------
function Tests.property_SkillLevelCap(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    local function testRand(max)
        return math.random(0, max - 1)
    end
    
    for i = 1, iterations do
        -- Generate random skill level including values > 10 to test cap
        local rawLevel = testRand(20) -- 0-19, some above cap
        local mockPlayer = createMockPlayer(rawLevel)
        
        local isValid = true
        local failReason = nil
        
        -- Get level through SkillManager (should be capped)
        local reportedLevel = SkillManager.getLevel(mockPlayer)
        
        -- Level should never exceed MAX_LEVEL (10)
        if reportedLevel > SkillManager.MAX_LEVEL then
            isValid = false
            failReason = "Level " .. reportedLevel .. " exceeds max " .. SkillManager.MAX_LEVEL
        end
        
        -- Level should be capped at MAX_LEVEL when raw > MAX_LEVEL
        if isValid and rawLevel > SkillManager.MAX_LEVEL then
            if reportedLevel ~= SkillManager.MAX_LEVEL then
                isValid = false
                failReason = "Raw level " .. rawLevel .. 
                    " should cap to " .. SkillManager.MAX_LEVEL .. 
                    ", got " .. reportedLevel
            end
        end
        
        -- Level should match raw when raw <= MAX_LEVEL
        if isValid and rawLevel <= SkillManager.MAX_LEVEL then
            if reportedLevel ~= rawLevel then
                isValid = false
                failReason = "Raw level " .. rawLevel .. 
                    " should equal reported " .. reportedLevel
            end
        end
        
        if isValid then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(failures, {
                iteration = i,
                reason = failReason,
                rawLevel = rawLevel,
                reportedLevel = reportedLevel
            })
        end
    end
    
    return {
        property = "Skill Level Cap",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Run All SkillManager Property Tests
-----------------------------------------------------------
function Tests.runAll(iterations)
    iterations = iterations or 100
    
    print("[DentalPain Tests] Running SkillManager Property-Based Tests...")
    print("  Iterations per property: " .. iterations)
    print("")
    
    local results = {}
    
    -- Property 8: Skill Unlock Thresholds
    local result8 = Tests.property_SkillUnlockThresholds(iterations)
    table.insert(results, result8)
    
    -- Property 9: Skill Level Cap
    local result9 = Tests.property_SkillLevelCap(iterations)
    table.insert(results, result9)
    
    -- Print results
    print("=== SKILLMANAGER PROPERTY TEST RESULTS ===")
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
    print("==========================================")
    
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
    subMenu:addOption("--- SkillManager Tests ---", nil, nil)
    
    subMenu:addOption("Run All Skill Tests (100 iter)", player, function()
        local success, results = Tests.runAll(100)
        if success then
            player:Say("[Skill Tests] All PASSED!")
        else
            player:Say("[Skill Tests] Some FAILED - check console")
        end
    end)
    
    subMenu:addOption("P8: Skill Unlock Thresholds", player, function()
        local result = Tests.property_SkillUnlockThresholds(100)
        if result.success then
            player:Say("[P8] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P8] FAILED - " .. result.failures[1].reason)
        end
    end)
    
    subMenu:addOption("P9: Skill Level Cap", player, function()
        local result = Tests.property_SkillLevelCap(100)
        if result.success then
            player:Say("[P9] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P9] FAILED - " .. result.failures[1].reason)
        end
    end)
end

return Tests
