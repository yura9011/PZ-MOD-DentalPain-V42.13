-- ISZombiePracticeAction.lua
-- Timed action for practicing tooth extraction on zombie corpses
-- Requirements: 4.1, 4.5

require "TimedActions/ISBaseTimedAction"
require "DentalPain/ZombiePractice"

ISZombiePracticeAction = ISBaseTimedAction:derive("ISZombiePracticeAction")

function ISZombiePracticeAction:isValid()
    -- Check player has pliers
    local inv = self.character:getInventory()
    if not inv:contains("Base.Pliers") then return false end
    
    -- Check zombie corpse still exists and has teeth
    if not self.zombie then return false end
    if not DentalPain.ZombiePractice.canPractice(self.zombie) then return false end
    
    return true
end

function ISZombiePracticeAction:update()
end

function ISZombiePracticeAction:start()
    self:setActionAnim("Loot")
end

function ISZombiePracticeAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISZombiePracticeAction:perform()
    -- Perform the practice extraction
    -- Note: No damage to player regardless of outcome (Requirement 4.5)
    DentalPain.ZombiePractice.performExtraction(self.character, self.zombie)
    ISBaseTimedAction.perform(self)
end

function ISZombiePracticeAction:new(character, zombie, time)
    local o = ISBaseTimedAction.new(self, character)
    o.zombie = zombie
    o.maxTime = time or 300
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end
