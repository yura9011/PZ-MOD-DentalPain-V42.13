-- DentalPain Visual Integration for MoodlesInLua (MIL)
-- Forcefully injects the custom moodle into MIL's rendering loop.

local patchApplied = false
local lastVisibleMoodles = -1
local cachedYOffset = 0

local function MyDentalPainRender(milInstance)
    -- Get player and mod data
    local player = getPlayer()
    if not player then return end
    local md = player:getModData()
    if not md then return end
    
    local health = md.dentalHealth or 100
    
    -- Determine Level (0=Hidden, 1=Discomfort, 2=Toothache, 3=Severe, 4=Agony)
    -- Levels based on health: 70-50=1, 50-30=2, 30-10=3, <10=4
    local isBad = false
    local level = 0
    
    if health < 70 then
        isBad = true
        if health >= 50 then level = 1      -- Dental Discomfort
        elseif health >= 30 then level = 2  -- Toothache
        elseif health >= 10 then level = 3  -- Severe Pain
        else level = 4 end                   -- Agony
    end
    
    -- Broken tooth always shows max level
    if md.hasBrokenTooth then
        isBad = true
        level = 4
    end
    
    if level == 0 then return end
    
    -- Prepare drawing variables
    local self = milInstance
    local moodleSize = self:getMoodleSize()
    
    local screenW = getPlayerScreenWidth(self.playerNum)
    local screenH = getPlayerScreenHeight(self.playerNum)
    
    -- Use standard moodle positioning logic
    local x = getPlayerScreenLeft(self.playerNum) + screenW - 10 - moodleSize
    local y = getPlayerScreenTop(self.playerNum) + 120
    
    x = x + self.options.moodleOffsetX
    y = y + self.options.moodleOffsetY
    
    local moodles = player:getMoodles()
    local moodlesValuesForType = Registries.MOODLE_TYPE:values()
    local numMoodles = moodlesValuesForType:size()
    
    -- Optimized Y calculation: Check how many moodles are visible
    local visibleCount = 0
    for moodleId = 0, numMoodles - 1 do
        if moodles:getMoodleLevel(moodlesValuesForType:get(moodleId)) > 0 then
            visibleCount = visibleCount + 1
        end
    end
    
    -- If the count changed, update the cached offset
    if visibleCount ~= lastVisibleMoodles then
        lastVisibleMoodles = visibleCount
        cachedYOffset = visibleCount * (self.options.moodlesDistance + moodleSize)
    end
    
    y = y + cachedYOffset
    
    -- Draw DentalPain moodle at the end of the list
    local goodBadNeutralId = isBad and 2 or 1
    
    local borderTexturePath = self:getBorderTexturePath(goodBadNeutralId, level)
    local borderTexture = self:getTexture(borderTexturePath)
    
    -- Choose icon based on condition
    local iconPath = "media/ui/DentalPain.png" -- Default: normal pain
    
    if md.hasBrokenTooth then
        iconPath = "media/ui/DentalPain_Alt.png" -- Broken tooth: caries icon
    elseif md.hasDentalAbscess then
        iconPath = "media/ui/DentalPain_Legacy.png" -- Infection: legacy icon
    end
    
    local iconTexture = getTexture(iconPath)
    
    if borderTexture and iconTexture then
         UIManager.DrawTexture(borderTexture, x, y, moodleSize, moodleSize, self.options.moodleAlpha)
         UIManager.DrawTexture(iconTexture, x, y, moodleSize, moodleSize, self.options.moodleAlpha)
         
         -- Draw Tooltip on Hover
         local mouseX, mouseY = getMouseX(), getMouseY()
         if mouseX >= x and mouseX <= x + moodleSize and mouseY >= y and mouseY <= y + moodleSize then
            local title = getText("IGUI_Moodle_DentalPain") or "Dental Pain"
            local description = getText("IGUI_Moodle_DentalPain_Agony") or "AGONY!"
            if level == 1 then description = getText("IGUI_Moodle_DentalPain_Discomfort") or "Dental discomfort."
            elseif level == 2 then description = getText("IGUI_Moodle_DentalPain_Toothache") or "Toothache."
            elseif level == 3 then description = getText("IGUI_Moodle_DentalPain_Severe") or "Severe pain!"
            elseif level == 4 then description = getText("IGUI_Moodle_DentalPain_Agony") or "AGONY!" end
            
            if md.hasBrokenTooth then description = getText("IGUI_Moodle_DentalPain_Broken") or "BROKEN TOOTH!" end

            -- Tooltip rendering
            local textPadding = 10
            local titleLength = getTextManager():MeasureStringX(UIFont.Small, title) + textPadding
            local descriptionLength = getTextManager():MeasureStringX(UIFont.Small, description) + textPadding
            local textLength = math.max(titleLength, descriptionLength)
            local titleHeight = getTextManager():MeasureStringY(UIFont.Small, title)
            local descriptionHeight = getTextManager():MeasureStringY(UIFont.Small, description)
            local rectHeight = titleHeight + descriptionHeight + 10
            
            self:drawRect(x - textLength - 15, y, textLength + 10, rectHeight, 0.6, 0, 0, 0)
            self:drawTextRight(title, x - 15, y + 5, 1, 1, 1, 1)
            self:drawTextRight(description, x - 15, y + titleHeight + 5, 1, 1, 1, 0.7)
         end
    end
end

local function applyPatch()
    if patchApplied then return end
    if not ISMoodlesInLua then return end
    
    local original_render = ISMoodlesInLua.render
    
    ISMoodlesInLua.render = function(self)
        original_render(self)
        pcall(MyDentalPainRender, self)
    end
    
    patchApplied = true
end

Events.OnGameStart.Add(applyPatch)
