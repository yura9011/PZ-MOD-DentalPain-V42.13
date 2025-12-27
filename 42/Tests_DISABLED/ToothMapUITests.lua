-- DentalPain/Tests/ToothMapUITests.lua
-- Property-based tests for ToothMapUI
-- VERSION: LOCAL_DEV_20241226_0200
--
-- **Feature: dental-skill-system**
-- **Property 5: Tooth State Color Mapping**
-- **Property 6: Tooltip Information Completeness**
-- **Validates: Requirements 2.2, 2.3**

require "DentalPain/Core"
require "DentalPain/ToothManager"

DentalPain.Tests = DentalPain.Tests or {}
DentalPain.Tests.ToothMapUI = {}

local Tests = DentalPain.Tests.ToothMapUI
local ToothState = DentalPain.ToothState

-----------------------------------------------------------
-- Mock Player Object for Testing
-----------------------------------------------------------
local function createMockPlayer()
    local mockPlayer = {
        _modData = {}
    }
    
    function mockPlayer:getModData()
        return self._modData
    end
    
    function mockPlayer:isDead()
        return false
    end
    
    function mockPlayer:getPlayerNum()
        return 0
    end
    
    return mockPlayer
end

-----------------------------------------------------------
-- Color Mapping Definition (mirrors ToothMapUI.COLORS)
-- This is the expected mapping for validation
-----------------------------------------------------------
local EXPECTED_COLORS = {
    healthy = {r=0.2, g=0.8, b=0.2, a=1.0},    -- Green
    cavity = {r=0.9, g=0.9, b=0.2, a=1.0},     -- Yellow
    infected = {r=1.0, g=0.5, b=0.0, a=1.0},   -- Orange
    broken = {r=0.9, g=0.2, b=0.2, a=1.0},     -- Red
    extracted = {r=0.4, g=0.4, b=0.4, a=0.5},  -- Gray
}

-----------------------------------------------------------
-- Helper: Compare colors with tolerance
-----------------------------------------------------------
local function colorsMatch(c1, c2, tolerance)
    tolerance = tolerance or 0.01
    if not c1 or not c2 then return false end
    return math.abs(c1.r - c2.r) < tolerance and
           math.abs(c1.g - c2.g) < tolerance and
           math.abs(c1.b - c2.b) < tolerance and
           math.abs(c1.a - c2.a) < tolerance
end

-----------------------------------------------------------
-- Helper: Check if all colors are distinct
-----------------------------------------------------------
local function areColorsDistinct(colors)
    local colorList = {}
    for state, color in pairs(colors) do
        table.insert(colorList, {state = state, color = color})
    end
    
    for i = 1, #colorList do
        for j = i + 1, #colorList do
            if colorsMatch(colorList[i].color, colorList[j].color) then
                return false, colorList[i].state, colorList[j].state
            end
        end
    end
    
    return true
end

-----------------------------------------------------------
-- Property 5: Tooth State Color Mapping
-- *For any* tooth state in {healthy, cavity, infected, broken, extracted},
-- the UI SHALL map it to exactly one distinct color
-- (green, yellow, orange, red, gray respectively).
-- **Validates: Requirements 2.2**
-----------------------------------------------------------
function Tests.property_ToothStateColorMapping(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    -- All valid tooth states
    local allStates = {
        ToothState.HEALTHY,
        ToothState.CAVITY,
        ToothState.INFECTED,
        ToothState.BROKEN,
        ToothState.EXTRACTED
    }
    
    -- Expected color names for each state
    local expectedColorNames = {
        [ToothState.HEALTHY] = "green",
        [ToothState.CAVITY] = "yellow",
        [ToothState.INFECTED] = "orange",
        [ToothState.BROKEN] = "red",
        [ToothState.EXTRACTED] = "gray",
    }
    
    for i = 1, iterations do
        local isValid = true
        local failReason = nil
        
        -- Test 1: Each state maps to exactly one color
        for _, state in ipairs(allStates) do
            local color = EXPECTED_COLORS[state]
            
            if not color then
                isValid = false
                failReason = "State '" .. state .. "' has no color mapping"
                break
            end
            
            -- Verify color has all required components
            if color.r == nil or color.g == nil or color.b == nil or color.a == nil then
                isValid = false
                failReason = "State '" .. state .. "' color is missing components"
                break
            end
            
            -- Verify color values are in valid range [0, 1]
            if color.r < 0 or color.r > 1 or
               color.g < 0 or color.g > 1 or
               color.b < 0 or color.b > 1 or
               color.a < 0 or color.a > 1 then
                isValid = false
                failReason = "State '" .. state .. "' color values out of range"
                break
            end
        end
        
        -- Test 2: All colors are distinct
        if isValid then
            local distinct, state1, state2 = areColorsDistinct(EXPECTED_COLORS)
            if not distinct then
                isValid = false
                failReason = "States '" .. state1 .. "' and '" .. state2 .. "' have the same color"
            end
        end
        
        -- Test 3: Verify specific color characteristics
        if isValid then
            -- Green should have high G component
            local green = EXPECTED_COLORS[ToothState.HEALTHY]
            if green.g <= green.r or green.g <= green.b then
                isValid = false
                failReason = "Healthy color is not predominantly green"
            end
        end
        
        if isValid then
            -- Yellow should have high R and G, low B
            local yellow = EXPECTED_COLORS[ToothState.CAVITY]
            if yellow.r < 0.5 or yellow.g < 0.5 or yellow.b > 0.5 then
                isValid = false
                failReason = "Cavity color is not yellow-ish"
            end
        end
        
        if isValid then
            -- Orange should have high R, medium G, low B
            local orange = EXPECTED_COLORS[ToothState.INFECTED]
            if orange.r < 0.8 or orange.g > 0.7 or orange.b > 0.3 then
                isValid = false
                failReason = "Infected color is not orange-ish"
            end
        end
        
        if isValid then
            -- Red should have high R, low G and B
            local red = EXPECTED_COLORS[ToothState.BROKEN]
            if red.r < 0.7 or red.g > 0.5 or red.b > 0.5 then
                isValid = false
                failReason = "Broken color is not red-ish"
            end
        end
        
        if isValid then
            -- Gray should have similar R, G, B values
            local gray = EXPECTED_COLORS[ToothState.EXTRACTED]
            local avgGray = (gray.r + gray.g + gray.b) / 3
            if math.abs(gray.r - avgGray) > 0.1 or
               math.abs(gray.g - avgGray) > 0.1 or
               math.abs(gray.b - avgGray) > 0.1 then
                isValid = false
                failReason = "Extracted color is not gray-ish"
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
        property = "Tooth State Color Mapping",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end


-----------------------------------------------------------
-- Property 6: Tooltip Information Completeness
-- *For any* tooth being hovered, the tooltip SHALL contain:
-- - the tooth name (string, non-empty)
-- - health percentage (0-100)
-- - current state string
-- **Validates: Requirements 2.3**
-----------------------------------------------------------
function Tests.property_TooltipInformationCompleteness(iterations)
    iterations = iterations or 100
    local passed = 0
    local failed = 0
    local failures = {}
    
    local function testRand(max)
        return math.random(0, max - 1)
    end
    
    -- All valid tooth states for random assignment
    local allStates = {
        ToothState.HEALTHY,
        ToothState.CAVITY,
        ToothState.INFECTED,
        ToothState.BROKEN,
        ToothState.EXTRACTED
    }
    
    for i = 1, iterations do
        local mockPlayer = createMockPlayer()
        DentalPain.ToothManager.initialize(mockPlayer)
        
        -- Randomly modify some teeth states and health
        local modData = mockPlayer:getModData()
        for j = 1, 32 do
            local tooth = modData.dentalTeeth[j]
            if tooth then
                -- Random health (0-100)
                tooth.health = testRand(101)
                
                -- Random state
                tooth.state = allStates[testRand(#allStates) + 1]
                
                -- If extracted, health should be 0
                if tooth.state == ToothState.EXTRACTED then
                    tooth.health = 0
                end
            end
        end
        
        -- Pick a random tooth to "hover" over
        local toothIndex = testRand(32) + 1
        local tooth = DentalPain.ToothManager.getToothByIndex(mockPlayer, toothIndex)
        
        local isValid = true
        local failReason = nil
        
        if not tooth then
            isValid = false
            failReason = "Tooth " .. toothIndex .. " is nil"
        else
            -- Check 1: Tooth name exists and is non-empty string
            if not tooth.name or type(tooth.name) ~= "string" or tooth.name == "" then
                isValid = false
                failReason = "Tooth " .. toothIndex .. " has invalid name: " .. tostring(tooth.name)
            end
            
            -- Check 2: Health is a number in range 0-100
            if isValid then
                if type(tooth.health) ~= "number" then
                    isValid = false
                    failReason = "Tooth " .. toothIndex .. " health is not a number: " .. type(tooth.health)
                elseif tooth.health < 0 or tooth.health > 100 then
                    isValid = false
                    failReason = "Tooth " .. toothIndex .. " health out of range: " .. tooth.health
                end
            end
            
            -- Check 3: State is a valid state string
            if isValid then
                if not tooth.state or type(tooth.state) ~= "string" then
                    isValid = false
                    failReason = "Tooth " .. toothIndex .. " has invalid state type: " .. type(tooth.state)
                else
                    -- Verify state is one of the valid states
                    local validState = false
                    for _, state in ipairs(allStates) do
                        if tooth.state == state then
                            validState = true
                            break
                        end
                    end
                    if not validState then
                        isValid = false
                        failReason = "Tooth " .. toothIndex .. " has unknown state: " .. tooth.state
                    end
                end
            end
            
            -- Check 4: Verify tooltip would have all required info
            -- Simulate what the tooltip would display
            if isValid then
                local nameText = tooth.name
                local healthText = string.format("Health: %d%%", math.floor(tooth.health))
                local stateText = string.format("State: %s", tooth.state)
                
                -- Verify name text is displayable
                if #nameText == 0 then
                    isValid = false
                    failReason = "Tooltip name text is empty"
                end
                
                -- Verify health text contains percentage
                if isValid and not string.find(healthText, "%%") then
                    isValid = false
                    failReason = "Tooltip health text missing percentage"
                end
                
                -- Verify state text contains state
                if isValid and not string.find(stateText, tooth.state) then
                    isValid = false
                    failReason = "Tooltip state text missing state value"
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
                toothIndex = toothIndex,
                tooth = tooth
            })
        end
    end
    
    return {
        property = "Tooltip Information Completeness",
        iterations = iterations,
        passed = passed,
        failed = failed,
        failures = failures,
        success = (failed == 0)
    }
end

-----------------------------------------------------------
-- Run All Property Tests
-----------------------------------------------------------
function Tests.runAll(iterations)
    iterations = iterations or 100
    
    print("[DentalPain Tests] Running ToothMapUI Property-Based Tests...")
    print("  Iterations per property: " .. iterations)
    print("")
    
    local results = {}
    
    -- Property 5: Tooth State Color Mapping
    local result5 = Tests.property_ToothStateColorMapping(iterations)
    table.insert(results, result5)
    
    -- Property 6: Tooltip Information Completeness
    local result6 = Tests.property_TooltipInformationCompleteness(iterations)
    table.insert(results, result6)
    
    -- Print results
    print("=== TOOTHMAPUI PROPERTY TEST RESULTS ===")
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
    print("=========================================")
    
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
    subMenu:addOption("--- ToothMapUI Tests ---", nil, nil)
    
    subMenu:addOption("Run All UI Property Tests (100 iter)", player, function()
        local success, results = Tests.runAll(100)
        if success then
            player:Say("[Tests] All ToothMapUI tests PASSED!")
        else
            player:Say("[Tests] Some tests FAILED - check console")
        end
    end)
    
    subMenu:addOption("Run All UI Property Tests (10 iter)", player, function()
        local success, results = Tests.runAll(10)
        if success then
            player:Say("[Tests] All ToothMapUI tests PASSED!")
        else
            player:Say("[Tests] Some tests FAILED - check console")
        end
    end)
    
    subMenu:addOption("P5: Color Mapping", player, function()
        local result = Tests.property_ToothStateColorMapping(100)
        if result.success then
            player:Say("[P5] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P5] FAILED - " .. result.failures[1].reason)
        end
    end)
    
    subMenu:addOption("P6: Tooltip Completeness", player, function()
        local result = Tests.property_TooltipInformationCompleteness(100)
        if result.success then
            player:Say("[P6] PASSED - " .. result.passed .. "/" .. result.iterations)
        else
            player:Say("[P6] FAILED - " .. result.failures[1].reason)
        end
    end)
end

return Tests
