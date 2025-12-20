-- DentalPain Integration for SimpleStatus / MersSimpleStatus
-- Adds a "Teeth" stat bar to the SimpleStatus UI

local function initSimpleStatusIntegration()
    -- Check if SimpleStatus is loaded
    if not SimpleStatus then 
        return 
    end
    
    -- Define the teeth stat (name matches IGUI_SS_BARTITLE_MOD_DENTALHEALTH)
    local teeth = {}
    teeth.name = "mod_dentalhealth"
    teeth.type = "custom"
    teeth.shown = true
    
    -- Value function: returns current dental health (0-100)
    teeth.valueFn = function(player)
        if not player then return 100 end
        local modData = player:getModData()
        if modData and modData.dentalHealth then
            return math.floor(modData.dentalHealth)
        end
        return 100
    end
    
    -- Percent function: returns 0-1 for bar fill
    teeth.percentFn = function(player)
        local value = teeth.valueFn(player)
        return value / 100
    end
    
    -- Color function: returns {r, g, b} as array (SimpleStatus format)
    teeth.colorFn = function(player)
        local value = teeth.valueFn(player)
        local modData = player:getModData()
        
        -- Red if broken tooth
        if modData and modData.hasBrokenTooth then
            return { 1, 0, 0 }  -- Red
        end
        
        if value > 75 then
            return { 0.2, 0.8, 0.2 }   -- Green
        elseif value > 50 then
            return { 0.8, 0.8, 0.2 }   -- Yellow
        elseif value > 25 then
            return { 0.9, 0.5, 0.1 }   -- Orange
        else
            return { 0.8, 0.2, 0.2 }   -- Red
        end
    end
    
    -- Text function: displays value with status
    teeth.textFn = function(player)
        local value = teeth.valueFn(player)
        local modData = player:getModData()
        
        if modData and modData.hasBrokenTooth then
            return "BROKEN!"
        end
        
        local teethExtracted = (modData and modData.teethExtracted) or 0
        if teethExtracted > 0 then
            return tostring(value) .. " (-" .. teethExtracted .. ")"
        end
        
        return tostring(value) .. " / 100"
    end
    
    -- Register the stat with SimpleStatus
    SimpleStatus:addStat("mod_dentalhealth", teeth, nil)
    
    print("[DentalPain] SimpleStatus integration loaded")
end

-- Initialize on game start (SimpleStatus should be loaded by then)
Events.OnGameStart.Add(initSimpleStatusIntegration)

