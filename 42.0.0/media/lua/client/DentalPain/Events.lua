-- DentalPain/Events.lua
-- Central event registration and handling for DentalPain

local DP = DentalPain or {}

-- 1. Initialization
local function onCreatePlayer(playerNum, player)
    if not player then return end
    local modData = player:getModData()
    if modData.dentalHealth == nil then
        modData.dentalHealth = DP.Config.InitialDentalHealth
        modData.hasBrokenTooth = false
        modData.teethExtracted = 0
        modData.anestheticTimer = 0
        modData.lastEatingState = false
    end
end

-- 2. Hourly Decay & State Updates
local function onEveryHour()
    local player = getPlayer()
    if not player or player:isDead() then return end
    
    -- Anesthetic Timer
    local modData = player:getModData()
    if (modData.anestheticTimer or 0) > 0 then
        modData.anestheticTimer = modData.anestheticTimer - 1
    end
    
    -- Health Decay
    local oldHealth = DP.getDentalHealth(player)
    DP.setDentalHealth(player, oldHealth - DP.Config.DentalHealthDecline)
    
    -- Reaction check (from Dialogue module)
    DP.Dialogue.checkAutoSpeech(player)
    
    -- Pain effects (Medical module)
    if oldHealth < DP.Config.PainThreshold and not DP.isNumbed(player) then
        local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
        head:setAdditionalPain(DP.Config.SeverePainAmount)
    end
    
    -- Dental Abscess Tracking (forms after 24h of severe pain)
    local health = DentalPain.getDentalHealth(player)
    if health < 20 and not modData.hasDentalAbscess then
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
            DentalPain.debug("Dental abscess formed after 24h of severe pain")
        end
    elseif health >= 20 then
        -- Reset counter if health improves
        modData.severePainHours = 0
    end
end

-- 3. Eating Detection (B42 Polling) + Temperature Pain
local function onEveryOneMinute()
    local player = getPlayer()
    if not player or player:isDead() then return end
    
    local modData = player:getModData()
    if not modData then return end
    
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if queue then
        local isEating = queue:indexOfType("ISEatFoodAction") == 1
        if isEating and not modData.lastEatingState then
            local currentAction = queue.queue[1]
            if currentAction and currentAction.item then
                local item = currentAction.item
                local damage = DP.FoodImpact[item:getFullType()] or 1.0
                DP.setDentalHealth(player, DP.getDentalHealth(player) - damage)
                DP.Medical.checkBreak(player)
                
                -- Hot/Cold Food Pain (if vulnerable teeth)
                local dentalHealth = DentalPain.getDentalHealth(player)
                local isVulnerable = modData.hasBrokenTooth or dentalHealth < 30
                
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
                        DentalPain.playPainSound(player)
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
        
        -- Health Info
        local currentHealth = DP.getDentalHealth(player)
        subMenu:addOption("--- Health: " .. math.floor(currentHealth) .. "/100 ---", nil, nil)
        
        -- Health Manipulation
        subMenu:addOption("Set Health: 100 (Perfect)", player, function()
            DP.setDentalHealth(player, 100)
            player:Say("[DEBUG] Health set to 100")
        end)
        subMenu:addOption("Set Health: 50 (Mild Pain)", player, function()
            DP.setDentalHealth(player, 50)
            player:Say("[DEBUG] Health set to 50")
        end)
        subMenu:addOption("Set Health: 20 (Severe Pain)", player, function()
            DP.setDentalHealth(player, 20)
            player:Say("[DEBUG] Health set to 20")
        end)
        subMenu:addOption("Set Health: 5 (Critical)", player, function()
            DP.setDentalHealth(player, 5)
            player:Say("[DEBUG] Health set to 5")
        end)
        
        -- Dialogue Tests
        subMenu:addOption("--- Dialogue Tests ---", nil, nil)
        subMenu:addOption("Say: Severe Pain", player, function() 
            DP.Dialogue.sayRandom(player, "Severe") 
        end)
        subMenu:addOption("Say: Mild Pain", player, function() 
            DP.Dialogue.sayRandom(player, "Mild") 
        end)
        subMenu:addOption("Say: Relief", player, function() 
            DP.Dialogue.sayRandom(player, "Relief") 
        end)
        subMenu:addOption("Say: Numbed", player, function() 
            DP.Dialogue.sayRandom(player, "Numbed") 
        end)
        subMenu:addOption("Say: Tooth Broke", player, function() 
            DP.Dialogue.sayRandom(player, "Extraction", "Broken") 
        end)
        subMenu:addOption("Say: Extract Success", player, function() 
            DP.Dialogue.sayRandom(player, "Extraction", "Success") 
        end)
        subMenu:addOption("Say: Extract Fail", player, function() 
            DP.Dialogue.sayRandom(player, "Extraction", "Fail") 
        end)
        
        -- Action Tests
        subMenu:addOption("--- Action Tests ---", nil, nil)
        subMenu:addOption("Simulate: Brush Teeth", player, function()
            DP.Hygiene.brushTeeth(player, false)
            player:Say("[DEBUG] Brushed!")
        end)
        subMenu:addOption("Simulate: Brush (Homemade)", player, function()
            DP.Hygiene.brushTeeth(player, true)
            player:Say("[DEBUG] Brushed (homemade)!")
        end)
        subMenu:addOption("Simulate: Floss", player, function()
            DP.Hygiene.flossTeeth(player)
            player:Say("[DEBUG] Flossed!")
        end)
        subMenu:addOption("Simulate: Mouthwash", player, function()
            DP.Hygiene.gargle(player)
            player:Say("[DEBUG] Gargled!")
        end)
        subMenu:addOption("Simulate: Take Anesthetic", player, function()
            DP.Medical.takeAnesthetic(player)
            player:Say("[DEBUG] Numbed for " .. DP.Config.AnestheticDuration .. " hours")
        end)
        
        -- State Tests
        subMenu:addOption("--- State Tests ---", nil, nil)
        subMenu:addOption("Toggle: Broken Tooth", player, function()
            modData.hasBrokenTooth = not modData.hasBrokenTooth
            player:Say("[DEBUG] Broken Tooth: " .. tostring(modData.hasBrokenTooth))
        end)
        subMenu:addOption("Info: Teeth Extracted", player, function()
            player:Say("[DEBUG] Teeth Extracted: " .. (modData.teethExtracted or 0) .. "/" .. DP.Config.TeethTotal)
        end)
        subMenu:addOption("Info: Anesthetic Timer", player, function()
            player:Say("[DEBUG] Anesthetic Timer: " .. (modData.anestheticTimer or 0) .. " hours left")
        end)
        
        -- Extraction Simulation
        subMenu:addOption("--- Extraction Tests ---", nil, nil)
        subMenu:addOption("Simulate: Pliers Extract", player, function()
            modData.hasBrokenTooth = true -- Force broken tooth for test
            DP.Medical.performExtraction(player, "pliers")
            player:Say("[DEBUG] Extraction done (pliers)")
        end)
        subMenu:addOption("Simulate: Hammer Extract", player, function()
            modData.hasBrokenTooth = true -- Force broken tooth for test
            DP.Medical.performExtraction(player, "hammer")
            player:Say("[DEBUG] Extraction done (hammer)")
        end)
        
        -- Tick Simulation
        subMenu:addOption("--- Simulation ---", nil, nil)
        subMenu:addOption("Force: Hourly Tick", player, function()
            onEveryHour()
            local h = DP.getDentalHealth(player)
            player:Say("[DEBUG] Tick! Health: " .. math.floor(h))
        end)
        subMenu:addOption("Force: Check Tooth Break", player, function()
            DP.Medical.checkBreak(player)
            player:Say("[DEBUG] Break check done")
        end)
        
        -- NEW: Health System Integration Tests
        subMenu:addOption("--- New Features Tests ---", nil, nil)
        
        -- Test Head Bleeding
        subMenu:addOption("Test: Head Bleeding ON", player, function()
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setBleeding(true)
                head:generateDeepWound()
            end
            player:Say("[DEBUG] Head bleeding enabled - check Health Panel!")
        end)
        subMenu:addOption("Test: Head Bleeding OFF", player, function()
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setBleeding(false)
            end
            player:Say("[DEBUG] Head bleeding disabled")
        end)
        
        -- Test Food Pain
        subMenu:addOption("Test: Cold Food Pain", player, function()
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setAdditionalPain(head:getAdditionalPain() + 40)
            end
            DP.Dialogue.sayRandom(player, "FoodPain")
            DentalPain.playPainSound(player)
            player:Say("[DEBUG] Cold food pain triggered!")
        end)
        subMenu:addOption("Test: Hot Food Pain", player, function()
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setAdditionalPain(head:getAdditionalPain() + 25)
            end
            DP.Dialogue.sayRandom(player, "FoodPain")
            player:Say("[DEBUG] Hot food pain triggered!")
        end)
        
        -- Test Dental Abscess
        subMenu:addOption("Test: Force Abscess", player, function()
            modData.hasDentalAbscess = true
            modData.severePainHours = 24
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setInfectedWound(true)
                head:setAdditionalPain(head:getAdditionalPain() + 30)
            end
            DP.Dialogue.sayRandom(player, "Abscess")
            player:Say("[DEBUG] Abscess forced - check Health Panel for infection!")
        end)
        subMenu:addOption("Test: Clear Abscess", player, function()
            modData.hasDentalAbscess = false
            modData.severePainHours = 0
            local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
            if head then
                head:setInfectedWound(false)
            end
            player:Say("[DEBUG] Abscess cleared")
        end)
        subMenu:addOption("Info: Abscess Status", player, function()
            local hasAbscess = modData.hasDentalAbscess and "YES" or "NO"
            local hours = modData.severePainHours or 0
            player:Say("[DEBUG] Abscess: " .. hasAbscess .. " | Pain Hours: " .. hours .. "/24")
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
