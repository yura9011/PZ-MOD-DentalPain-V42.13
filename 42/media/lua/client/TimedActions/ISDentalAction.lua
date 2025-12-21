-- ISDentalAction.lua
-- Generic timed action for all dental hygiene actions
require "TimedActions/ISBaseTimedAction"

ISDentalAction = ISBaseTimedAction:derive("ISDentalAction")

function ISDentalAction:isValid()
    local inv = self.character:getInventory()
    if self.actionType == "brush" then
        return inv:contains("Base.Toothbrush") and inv:contains("Base.Toothpaste")
    elseif self.actionType == "brushHomemade" then
        return inv:contains("DentalPain.HomemadeToothbrush") and inv:contains("DentalPain.HomemadeToothpaste")
    elseif self.actionType == "floss" then
        return inv:contains("DentalPain.DentalFloss")
    elseif self.actionType == "gargle" then
        return inv:contains("DentalPain.Mouthwash")
    end
    return false
end

function ISDentalAction:update()
end

function ISDentalAction:start()
    self:setActionAnim("WashFace")
end

function ISDentalAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISDentalAction:perform()
    local inv = self.character:getInventory()
    
    if self.actionType == "brush" then
        DentalPain.Hygiene.brushTeeth(self.character, false)
        local item = inv:getFirstType("Base.Toothpaste")
        if item and instanceof(item, "DrainableComboItem") then item:Use() end
        
    elseif self.actionType == "brushHomemade" then
        DentalPain.Hygiene.brushTeeth(self.character, true)
        local item = inv:getFirstType("DentalPain.HomemadeToothpaste")
        if item and instanceof(item, "DrainableComboItem") then item:Use() end
        
    elseif self.actionType == "floss" then
        DentalPain.Hygiene.flossTeeth(self.character)
        local item = inv:getFirstType("DentalPain.DentalFloss")
        if item then inv:Remove(item) end
        
    elseif self.actionType == "gargle" then
        DentalPain.Hygiene.gargle(self.character)
        local item = inv:getFirstType("DentalPain.Mouthwash")
        if item and instanceof(item, "DrainableComboItem") then item:Use() end
    end
    
    ISBaseTimedAction.perform(self)
end

function ISDentalAction:new(character, actionType, time)
    local o = ISBaseTimedAction.new(self, character)
    o.actionType = actionType
    o.maxTime = time or 200
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end
