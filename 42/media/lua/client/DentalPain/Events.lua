-- DentalPain/Events.lua
-- Central event registration and handling for DentalPain
-- VERSION: LOCAL_DEV_20241226_INTEGRATION

require "DentalPain/ToothManager"
require "DentalPain/SkillManager"
require "DentalPain/FormulaCalculator"

local DP = DentalPain or {}

-- 1. Initialization
-- Now uses ToothManager for 32-tooth system (Requirement 1.1)
-- Includes migration support for existing saves
local function onCreatePlayer(playerNum, player)
    if not player then return end
    local modData = player:getModData()
    
    -- Initialize/migrate 32-tooth system via ToothManager
    -- This handles both new games and legacy save migration
    DP.ToothManager.ensureInitialized(player)
    
    -- Initialize legacy fields for backwards compatibility
    if modData.dentalHealth == nil then
        modData.dentalHealth = DP.Config.InitialDentalHealth
    end
    if modData.hasBrokenTooth == nil then
        modData.hasBrokenTooth = false
    end
    if modData.teethExtracted == nil then
        modData.teethExtracted = 0
    end
    if modData.anestheticTimer == nil then
        modData.anestheticTimer = 0
    end
    if modData.lastEatingState == nil then
        modData.lastEatingState = false
    end
    
    -- Lifestyle mod compatibility: track last brush time
    -- false = never brushed, number = hours survived when last brushed
    if modData.lastBrushTeeth == nil then
        modData.lastBrushTeeth = false
    end
    
    -- Sync legacy dentalHealth with ToothManager overall health
    modData.dentalHealth = DP.ToothManager.getOverallHealth(player)
    
    -- Sync legacy teethExtracted count
    modData.teethExtracted = 32 - DP.ToothManager.getRemainingCount(player)
    
    -- Sync legacy hasBrokenTooth flag
    modData.hasBrokenTooth = DP.ToothManager.getFirstBrokenTooth(player) ~= nil
    
    DP.debug("Player initialized with 32-tooth system - Teeth: " .. DP.ToothManager.getRemainingCount(player) .. "/32, Health: " .. math.floor(modData.dentalHealth) .. "%")
end

-- 2. Hourly Decay & State Updates
-- Now uses ToothManager for individual tooth damage distribution (Requirement 1.2)
local function onEveryHour()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    
    -- Ensure tooth system is initialized
    DP.ToothManager.ensureInitialized(player)
    
    -- Anesthetic Timer
    local modData = player:getModData()
    if (modData.anestheticTimer or 0) > 0 then
        modData.anestheticTimer = modData.anestheticTimer - 1
    end
    
    -- Check if player has any teeth left
    if not DP.ToothManager.hasAnyTeeth(player) then
        -- No teeth remaining - disable dental pain mechanics (Requirement 1.5)
        DP.debug("No teeth remaining - dental mechanics disabled")
        return
    end
    
    -- Health Decay - Apply damage to individual teeth via ToothManager
    -- Small hourly decay distributed to random tooth
    local decayAmount = DP.Config.DentalHealthDecline * 4 -- Scale for individual tooth
    DP.ToothManager.applyDamage(player, decayAmount)
    
    -- Update legacy dentalHealth to match overall tooth health
    local overallHealth = DP.ToothManager.getOverallHealth(player)
    modData.dentalHealth = overallHealth
    
    -- Reaction check (from Dialogue module)
    DP.Dialogue.checkAutoSpeech(player)
    
    -- Pain effects (Medical module)
    if overallHealth < DP.Config.PainThreshold and not DP.isNumbed(player) then
        local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
        head:setAdditionalPain(DP.Config.SeverePainAmount)
    end
    
    -- Dental Abscess Tracking (forms after 24h of severe pain)
    if overallHealth < 20 and not modData.hasDentalAbscess then
        modData.severePainHours = (modData.severePainHours or 0) + 1
        
        if modData.severePainHours >= 24 then
            -- Abscess forms - wound infection on head
            modData.hasDentalAbscess = true
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setInfectedWound(true)
                head:setAdditionalPain(head:getAdditionalPain() + 30)
            end
            DP.Dialogue.sayRandom(player, "Abscess")
            DP.debug("Dental abscess formed after 24h of severe pain")
        end
    elseif overallHealth >= 20 then
        -- Reset counter if health improves
        modData.severePainHours = 0
    end
end

-- 3. Eating Detection (B42 Polling) + Temperature Pain
-- Now uses ToothManager for damage distribution (Requirement 1.2)
local function onEveryOneMinute()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    
    local modData = player:getModData()
    if not modData then return end
    
    -- Ensure tooth system is initialized
    DP.ToothManager.ensureInitialized(player)
    
    -- Check if player has any teeth left
    if not DP.ToothManager.hasAnyTeeth(player) then
        return -- No teeth, no dental damage from eating
    end
    
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if queue then
        local isEating = queue:indexOfType("ISEatFoodAction") == 1
        if isEating and not modData.lastEatingState then
            local currentAction = queue.queue[1]
            if currentAction and currentAction.item then
                local item = currentAction.item
                local damage = DP.FoodImpact[item:getFullType()] or 1.0
                
                -- Apply damage to individual tooth via ToothManager
                DP.ToothManager.applyDamage(player, damage)
                
                -- Update legacy dentalHealth to match overall tooth health
                modData.dentalHealth = DP.ToothManager.getOverallHealth(player)
                
                -- Check for tooth break
                DP.Medical.checkBreak(player)
                
                -- Hot/Cold Food Pain (if vulnerable teeth)
                local overallHealth = DP.ToothManager.getOverallHealth(player)
                local hasBrokenTooth = DP.ToothManager.getFirstBrokenTooth(player) ~= nil
                local isVulnerable = hasBrokenTooth or overallHealth < 30
                
                if isVulnerable and item.IsFood and item:IsFood() then
                    local heat = item:getHeat() or 0.5
                    local isFrozen = item.isFrozen and item:isFrozen()
                    
                    -- Cold food (frozen or very cold)
                    if isFrozen or heat < 0.2 then
                        local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
                        if head then
                            head:setAdditionalPain(head:getAdditionalPain() + 40)
                        end
                        DP.Dialogue.sayRandom(player, "FoodPain")
                        DP.playPainSound(player)
                    -- Hot food
                    elseif heat > 0.8 then
                        local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
                        if head then
                            head:setAdditionalPain(head:getAdditionalPain() + 25)
                        end
                        DP.Dialogue.sayRandom(player, "FoodPain")
                    end
                end
            end
        end
        modData.lastEatingState = isEating
    end
end

-- 4. Context Menu Integration
local function onFillInventoryObjectContextMenu(playerNum, context, items)
    DP.Hygiene.onFillInventoryObjectContextMenu(playerNum, context, items)
    DP.Medical.onFillInventoryObjectContextMenu(playerNum, context, items)
    
    -- Debug Menu
    if DP.Config.DebugMode then
        local player = getSpecificPlayer(playerNum)
        local modData = player:getModData()
        local option = context:addOption("[DEBUG] DentalPain", nil, nil)
        local subMenu = context:getNew(context)
        context:addSubMenu(option, subMenu)
        
        -- Quick Status Display
        local health = math.floor(DP.ToothManager.getOverallHealth(player))
        local teeth = DP.ToothManager.getRemainingCount(player)
        local level = DP.SkillManager.getLevel(player)
        local xp = DP.SkillManager.getXP(player)
        subMenu:addOption("--- Status: " .. teeth .. "/32 teeth, " .. health .. "% HP, Lv" .. level .. " (" .. xp .. " XP) ---", nil, nil)
        
        -- 1. Show Tooth Map
        subMenu:addOption("1. Show Tooth Map", player, function()
            DentalPain.UI.ToothMapUI.show(player)
        end)
        
        -- 2. Damage a tooth
        subMenu:addOption("2. Damage Random Tooth (-20)", player, function()
            local idx = DP.ToothManager.applyDamage(player, 20)
            if idx then
                local tooth = DP.ToothManager.getToothByIndex(player, idx)
                player:Say("Damaged " .. tooth.name .. " -> " .. math.floor(tooth.health) .. "%")
            end
        end)
        
        -- 3. Heal a tooth
        subMenu:addOption("3. Heal Random Tooth (+20)", player, function()
            local idx = DP.ToothManager.healRandomTooth(player, 20)
            if idx then
                local tooth = DP.ToothManager.getToothByIndex(player, idx)
                player:Say("Healed " .. tooth.name .. " -> " .. math.floor(tooth.health) .. "%")
            end
        end)
        
        -- 4. Set tooth broken
        subMenu:addOption("4. Set Random Tooth BROKEN", player, function()
            local tooth = DP.ToothManager.getRandomNonExtractedTooth(player)
            if tooth then
                DP.ToothManager.setToothState(player, tooth.index, DentalPain.ToothState.BROKEN)
                player:Say(tooth.name .. " is now BROKEN")
            end
        end)
        
        -- 5. Extract tooth
        subMenu:addOption("5. Simulate Pliers Extraction", player, function()
            modData.hasBrokenTooth = true
            DP.Medical.performExtraction(player, "pliers")
        end)
        
        -- 6. Award XP
        subMenu:addOption("6. Award 50 XP (Extraction)", player, function()
            DP.SkillManager.awardXP(player, "SELF_EXTRACTION_SUCCESS")
            local xp = DP.SkillManager.getXP(player)
            local lv = DP.SkillManager.getLevel(player)
            player:Say("Now: Lv" .. lv .. " (" .. xp .. " XP)")
        end)
        
        -- 7. Brush (heals tooth)
        subMenu:addOption("7. Brush Teeth (heals)", player, function()
            DP.Hygiene.brushTeeth(player, false)
            player:Say("Brushed! Health: " .. math.floor(DP.ToothManager.getOverallHealth(player)) .. "%")
        end)
        
        -- 8. Legacy Migration Test
        subMenu:addOption("8. Test Legacy Migration", player, function()
            modData.dentalTeeth = nil
            modData.dentalHealth = 45
            modData.teethExtracted = 3
            DP.ToothManager.ensureInitialized(player)
            local remaining = DP.ToothManager.getRemainingCount(player)
            local health = DP.ToothManager.getOverallHealth(player)
            player:Say("Migrated: " .. remaining .. " teeth, " .. math.floor(health) .. "% HP")
        end)
        
        -- 9. Reset All
        subMenu:addOption("9. RESET: Full 32 Teeth", player, function()
            DP.ToothManager.initialize(player)
            modData.dentalCareXP = 0
            player:Say("Reset! 32 teeth, 100% HP, 0 XP")
        end)
        
        -- === LIFESTYLE COMPATIBILITY TESTS ===
        subMenu:addOption("--- Lifestyle Compat ---", nil, nil)
        
        -- 10. Show lastBrushTeeth status
        subMenu:addOption("10. Check lastBrushTeeth", player, function()
            local lastBrush = modData.lastBrushTeeth
            local hoursSince = DP.Hygiene.getHoursSinceLastBrush(player)
            local currentHours = getGameTime():getWorldAgeHours()
            
            if lastBrush == false then
                player:Say("lastBrushTeeth = FALSE (never brushed)")
            else
                player:Say("lastBrushTeeth = " .. string.format("%.1f", lastBrush) .. " | Hours since: " .. string.format("%.1f", hoursSince or 0))
            end
            print("[DentalPain] lastBrushTeeth = " .. tostring(lastBrush) .. " | Current hours: " .. string.format("%.1f", currentHours))
        end)
        
        -- 11. Reset lastBrushTeeth to false (simulate never brushed)
        subMenu:addOption("11. Reset lastBrushTeeth = false", player, function()
            modData.lastBrushTeeth = false
            player:Say("lastBrushTeeth reset to FALSE")
            print("[DentalPain] lastBrushTeeth reset to false")
        end)
        
        -- 12. Simulate brush (updates lastBrushTeeth)
        subMenu:addOption("12. Brush + Check timestamp", player, function()
            local beforeBrush = modData.lastBrushTeeth
            DP.Hygiene.brushTeeth(player, false)
            local afterBrush = modData.lastBrushTeeth
            player:Say("Before: " .. tostring(beforeBrush) .. " | After: " .. string.format("%.1f", afterBrush))
            print("[DentalPain] Brush test - Before: " .. tostring(beforeBrush) .. " | After: " .. tostring(afterBrush))
        end)
    end

end

-- 5. Registration
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.EveryHours.Add(onEveryHour)
Events.EveryOneMinute.Add(onEveryOneMinute)
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

DP.debug("Modular Events Registered.")

return DP
