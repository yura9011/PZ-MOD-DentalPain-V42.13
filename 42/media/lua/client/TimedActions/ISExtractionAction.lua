-- ISExtractionAction.lua
-- Timed action for tooth extraction
require "TimedActions/ISBaseTimedAction"

ISExtractionAction = ISBaseTimedAction:derive("ISExtractionAction")

function ISExtractionAction:isValid()
    local md = self.character:getModData()
    if not md.hasBrokenTooth then return false end
    
    local inv = self.character:getInventory()
    if self.method == "pliers" then
        return inv:contains("Base.Pliers")
    elseif self.method == "hammer" then
        return inv:contains("Base.Hammer") or inv:contains("Base.HammerStone") or inv:contains("Base.BallPeenHammer")
    end
    return false
end

function ISExtractionAction:update()
end

function ISExtractionAction:start()
    self:setActionAnim("Loot")
    self.character:reportEvent("Pain")
end

function ISExtractionAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISExtractionAction:perform()
    DentalPain.Medical.performExtraction(self.character, self.method)
    ISBaseTimedAction.perform(self)
end

function ISExtractionAction:new(character, method, time)
    local o = ISBaseTimedAction.new(self, character)
    o.method = method
    o.maxTime = time or 400
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end
