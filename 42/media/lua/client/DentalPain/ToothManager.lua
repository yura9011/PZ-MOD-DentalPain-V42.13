-- DentalPain/ToothManager.lua
-- Manages individual tooth tracking for the 32-tooth system
-- VERSION: LOCAL_DEV_20241226_0100

require "DentalPain/Core"

DentalPain.ToothManager = {}

local ToothManager = DentalPain.ToothManager

-----------------------------------------------------------
-- Initialize
-- Creates 32 tooth records in player's ModData
-- Called when a new game starts or when teeth data is missing
-----------------------------------------------------------
function ToothManager.initialize(player)
    if not player then return false end
    
    local modData = player:getModData()
    if not modData then return false end
    
    -- Create array of 32 teeth
    modData.dentalTeeth = {}
    
    for i = 1, 32 do
        modData.dentalTeeth[i] = DentalPain.createToothRecord(i)
    end
    
    DentalPain.debug("ToothManager: Initialized 32 teeth for player")
    return true
end

-----------------------------------------------------------
-- Ensure Initialized
-- Checks if teeth data exists and is valid, initializes if not
-- Also handles migration from legacy single-value dentalHealth
-----------------------------------------------------------
function ToothManager.ensureInitialized(player)
    if not player then return false end
    
    local modData = player:getModData()
    if not modData then return false end
    
    -- Check if teeth array exists
    if not modData.dentalTeeth then
        -- Check for legacy save data that needs migration
        if modData.dentalHealth ~= nil then
            return ToothManager.migrateFromLegacy(player)
        end
        return ToothManager.initialize(player)
    end
    
    -- Validate teeth array has exactly 32 valid entries
    local validCount = 0
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.index and tooth.state and tooth.health then
            validCount = validCount + 1
        end
    end
    
    if validCount ~= 32 then
        return ToothManager.initialize(player)
    end
    
    return true
end

-----------------------------------------------------------
-- Migrate From Legacy
-- Converts old single-value dentalHealth to 32-tooth system
-- Preserves overall health by distributing it across teeth
-- Requirement: 1.1 (migration support)
-----------------------------------------------------------
function ToothManager.migrateFromLegacy(player)
    if not player then return false end
    
    local modData = player:getModData()
    if not modData then return false end
    
    -- Get legacy values
    local legacyHealth = modData.dentalHealth or 100
    local legacyExtracted = modData.teethExtracted or 0
    local legacyBroken = modData.hasBrokenTooth or false
    
    DentalPain.debug("ToothManager: Migrating legacy save - Health: " .. legacyHealth .. ", Extracted: " .. legacyExtracted .. ", Broken: " .. tostring(legacyBroken))
    
    -- Initialize 32 teeth
    modData.dentalTeeth = {}
    
    for i = 1, 32 do
        modData.dentalTeeth[i] = DentalPain.createToothRecord(i)
    end
    
    -- Apply legacy extracted teeth count
    -- Extract teeth from the back (molars) first, as that's most realistic
    local teethToExtract = math.min(legacyExtracted, 32)
    local extractionOrder = {
        -- Upper right molars (8,7,6), then premolars (5,4), etc.
        8, 7, 6, 5, 4, 3, 2, 1,
        -- Upper left molars
        16, 15, 14, 13, 12, 11, 10, 9,
        -- Lower right molars
        32, 31, 30, 29, 28, 27, 26, 25,
        -- Lower left molars
        24, 23, 22, 21, 20, 19, 18, 17
    }
    
    for i = 1, teethToExtract do
        local toothIndex = extractionOrder[i]
        if toothIndex and modData.dentalTeeth[toothIndex] then
            modData.dentalTeeth[toothIndex].state = DentalPain.ToothState.EXTRACTED
            modData.dentalTeeth[toothIndex].health = 0
        end
    end
    
    -- Distribute legacy health across remaining teeth
    -- If legacy health was 50%, set all remaining teeth to 50% health
    local remainingTeeth = 32 - teethToExtract
    if remainingTeeth > 0 then
        for i = 1, 32 do
            local tooth = modData.dentalTeeth[i]
            if tooth and tooth.state ~= DentalPain.ToothState.EXTRACTED then
                tooth.health = legacyHealth
                
                -- Set state based on health
                if tooth.health <= 0 then
                    tooth.state = DentalPain.ToothState.BROKEN
                    tooth.health = 0
                elseif tooth.health < 30 then
                    tooth.state = DentalPain.ToothState.INFECTED
                elseif tooth.health < 60 then
                    tooth.state = DentalPain.ToothState.CAVITY
                else
                    tooth.state = DentalPain.ToothState.HEALTHY
                end
            end
        end
    end
    
    -- Handle legacy broken tooth flag
    if legacyBroken then
        -- Find a non-extracted tooth and mark it as broken
        for i = 1, 32 do
            local tooth = modData.dentalTeeth[i]
            if tooth and tooth.state ~= DentalPain.ToothState.EXTRACTED then
                tooth.state = DentalPain.ToothState.BROKEN
                tooth.health = 0
                break
            end
        end
    end
    
    DentalPain.debug("ToothManager: Migration complete - Remaining teeth: " .. ToothManager.getRemainingCount(player) .. ", Overall health: " .. math.floor(ToothManager.getOverallHealth(player)) .. "%")
    
    return true
end

-----------------------------------------------------------
-- Get Tooth By Index
-- Returns a single tooth record by index (1-32)
-----------------------------------------------------------
function ToothManager.getToothByIndex(player, index)
    if not player then return nil end
    if index < 1 or index > 32 then return nil end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return nil end
    
    return modData.dentalTeeth[index]
end


-----------------------------------------------------------
-- Get All Teeth
-- Returns the full array of 32 tooth records
-----------------------------------------------------------
function ToothManager.getAllTeeth(player)
    if not player then return nil end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return nil end
    
    return modData.dentalTeeth
end

-----------------------------------------------------------
-- Get Remaining Count
-- Returns the count of non-extracted teeth (0-32)
-----------------------------------------------------------
function ToothManager.getRemainingCount(player)
    if not player then return 0 end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return 0 end
    
    local count = 0
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.state ~= DentalPain.ToothState.EXTRACTED then
            count = count + 1
        end
    end
    
    return count
end

-----------------------------------------------------------
-- Get Overall Health
-- Returns the average health percentage of non-extracted teeth
-- Returns 0 if all teeth are extracted
-----------------------------------------------------------
function ToothManager.getOverallHealth(player)
    if not player then return 0 end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return 0 end
    
    local totalHealth = 0
    local count = 0
    
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.state ~= DentalPain.ToothState.EXTRACTED then
            totalHealth = totalHealth + tooth.health
            count = count + 1
        end
    end
    
    if count == 0 then
        return 0
    end
    
    return totalHealth / count
end

-----------------------------------------------------------
-- Get Random Non-Extracted Tooth
-- Returns a random tooth that is not extracted
-- Returns nil if all teeth are extracted
-----------------------------------------------------------
function ToothManager.getRandomNonExtractedTooth(player)
    if not player then return nil end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return nil end
    
    -- Collect indices of non-extracted teeth
    local validIndices = {}
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.state ~= DentalPain.ToothState.EXTRACTED then
            table.insert(validIndices, i)
        end
    end
    
    if #validIndices == 0 then
        return nil
    end
    
    -- Pick a random index from valid teeth
    local randomIndex = validIndices[ZombRand(#validIndices) + 1]
    return modData.dentalTeeth[randomIndex]
end

-----------------------------------------------------------
-- Has Any Teeth
-- Returns true if player has at least one non-extracted tooth
-----------------------------------------------------------
function ToothManager.hasAnyTeeth(player)
    return ToothManager.getRemainingCount(player) > 0
end

-----------------------------------------------------------
-- Set Tooth State
-- Updates the state of a specific tooth by index
-- Handles state transitions and validation
-----------------------------------------------------------
function ToothManager.setToothState(player, index, state)
    if not player then return false end
    if index < 1 or index > 32 then return false end
    
    -- Validate state is a valid ToothState
    local validStates = {
        [DentalPain.ToothState.HEALTHY] = true,
        [DentalPain.ToothState.CAVITY] = true,
        [DentalPain.ToothState.INFECTED] = true,
        [DentalPain.ToothState.BROKEN] = true,
        [DentalPain.ToothState.EXTRACTED] = true
    }
    
    if not validStates[state] then
        DentalPain.debug("ToothManager: Invalid state '" .. tostring(state) .. "'")
        return false
    end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return false end
    
    local tooth = modData.dentalTeeth[index]
    if not tooth then return false end
    
    -- Cannot change state of extracted tooth (permanence)
    if tooth.state == DentalPain.ToothState.EXTRACTED and state ~= DentalPain.ToothState.EXTRACTED then
        DentalPain.debug("ToothManager: Cannot change state of extracted tooth " .. index)
        return false
    end
    
    local oldState = tooth.state
    tooth.state = state
    
    DentalPain.debug("ToothManager: Tooth " .. index .. " state changed from '" .. oldState .. "' to '" .. state .. "'")
    return true
end

-----------------------------------------------------------
-- Apply Damage
-- Applies damage to a random non-extracted tooth
-- Handles zero-health transition to broken state
-- Returns the affected tooth index, or nil if no teeth available
-----------------------------------------------------------
function ToothManager.applyDamage(player, amount)
    if not player then return nil end
    if not amount or amount <= 0 then return nil end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return nil end
    
    -- Get a random non-extracted tooth
    local tooth = ToothManager.getRandomNonExtractedTooth(player)
    if not tooth then
        DentalPain.debug("ToothManager: No teeth available for damage")
        return nil
    end
    
    local toothIndex = tooth.index
    local oldHealth = tooth.health
    
    -- Apply damage
    tooth.health = math.max(0, tooth.health - amount)
    
    DentalPain.debug("ToothManager: Tooth " .. toothIndex .. " damaged: " .. oldHealth .. " -> " .. tooth.health)
    
    -- Handle zero-health transition to broken state
    if tooth.health <= 0 and tooth.state ~= DentalPain.ToothState.BROKEN and tooth.state ~= DentalPain.ToothState.EXTRACTED then
        tooth.state = DentalPain.ToothState.BROKEN
        DentalPain.debug("ToothManager: Tooth " .. toothIndex .. " broke due to zero health!")
    end
    
    return toothIndex
end

-----------------------------------------------------------
-- Extract Tooth
-- Marks a specific tooth as extracted (permanent)
-- Returns true if extraction was successful
-----------------------------------------------------------
function ToothManager.extractTooth(player, index)
    if not player then return false end
    if index < 1 or index > 32 then return false end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return false end
    
    local tooth = modData.dentalTeeth[index]
    if not tooth then return false end
    
    -- Cannot extract an already extracted tooth
    if tooth.state == DentalPain.ToothState.EXTRACTED then
        DentalPain.debug("ToothManager: Tooth " .. index .. " is already extracted")
        return false
    end
    
    -- Mark as extracted
    tooth.state = DentalPain.ToothState.EXTRACTED
    tooth.health = 0
    
    DentalPain.debug("ToothManager: Tooth " .. index .. " (" .. tooth.name .. ") extracted. Remaining: " .. ToothManager.getRemainingCount(player))
    
    return true
end

-----------------------------------------------------------
-- Get Teeth By State
-- Returns an array of teeth matching the given state
-----------------------------------------------------------
function ToothManager.getTeethByState(player, state)
    if not player then return {} end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return {} end
    
    local result = {}
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.state == state then
            table.insert(result, tooth)
        end
    end
    
    return result
end

-----------------------------------------------------------
-- Get First Broken Tooth
-- Returns the first tooth in broken state, or nil if none
-----------------------------------------------------------
function ToothManager.getFirstBrokenTooth(player)
    if not player then return nil end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return nil end
    
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.state == DentalPain.ToothState.BROKEN then
            return tooth
        end
    end
    
    return nil
end

-----------------------------------------------------------
-- Heal Tooth
-- Increases a specific tooth's health by amount, capped at 100
-- Does NOT heal extracted teeth
-- Returns true if healing was applied
-----------------------------------------------------------
function ToothManager.healTooth(player, index, amount)
    if not player then return false end
    if index < 1 or index > 32 then return false end
    if not amount or amount <= 0 then return false end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return false end
    
    local tooth = modData.dentalTeeth[index]
    if not tooth then return false end
    
    -- Cannot heal extracted teeth
    if tooth.state == DentalPain.ToothState.EXTRACTED then
        DentalPain.debug("ToothManager: Cannot heal extracted tooth " .. index)
        return false
    end
    
    -- Cannot heal if already at max health
    if tooth.health >= 100 then
        return false
    end
    
    local oldHealth = tooth.health
    tooth.health = math.min(100, tooth.health + amount)
    
    -- If tooth was broken and now has significant health, revert to cavity state
    if tooth.state == DentalPain.ToothState.BROKEN and tooth.health >= 20 then
        tooth.state = DentalPain.ToothState.CAVITY
        DentalPain.debug("ToothManager: Tooth " .. index .. " healed from BROKEN to CAVITY")
    end
    
    DentalPain.debug("ToothManager: Tooth " .. index .. " healed: " .. oldHealth .. " -> " .. tooth.health)
    return true
end

-----------------------------------------------------------
-- Get Random Damaged Tooth
-- Returns a random non-extracted tooth with health < 100
-- Returns nil if all teeth are healthy or extracted
-----------------------------------------------------------
function ToothManager.getRandomDamagedTooth(player)
    if not player then return nil end
    
    ToothManager.ensureInitialized(player)
    
    local modData = player:getModData()
    if not modData or not modData.dentalTeeth then return nil end
    
    -- Collect indices of damaged (non-extracted, health < 100) teeth
    local damagedIndices = {}
    for i = 1, 32 do
        local tooth = modData.dentalTeeth[i]
        if tooth and tooth.state ~= DentalPain.ToothState.EXTRACTED and tooth.health < 100 then
            table.insert(damagedIndices, i)
        end
    end
    
    if #damagedIndices == 0 then
        return nil
    end
    
    -- Pick a random index from damaged teeth
    local randomIndex = damagedIndices[ZombRand(#damagedIndices) + 1]
    return modData.dentalTeeth[randomIndex]
end

-----------------------------------------------------------
-- Heal Random Tooth
-- Heals a random damaged tooth by the specified amount
-- Returns the healed tooth index, or nil if no teeth to heal
-----------------------------------------------------------
function ToothManager.healRandomTooth(player, amount)
    if not player then return nil end
    if not amount or amount <= 0 then return nil end
    
    ToothManager.ensureInitialized(player)
    
    -- Get a random damaged tooth
    local tooth = ToothManager.getRandomDamagedTooth(player)
    if not tooth then
        DentalPain.debug("ToothManager: No damaged teeth to heal")
        return nil
    end
    
    local toothIndex = tooth.index
    ToothManager.healTooth(player, toothIndex, amount)
    
    return toothIndex
end

return ToothManager
