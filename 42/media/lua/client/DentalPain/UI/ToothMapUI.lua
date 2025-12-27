-- DentalPain/UI/ToothMapUI.lua
-- Visual tooth map showing all 32 teeth with their states
-- VERSION: LOCAL_DEV_20241226_0200
--
-- **Feature: dental-skill-system**
-- **Validates: Requirements 2.1, 2.2, 2.3, 2.5**

require "DentalPain/Core"
require "DentalPain/ToothManager"

-- Create UI namespace
DentalPain.UI = DentalPain.UI or {}

-- ToothMapUI class definition
ToothMapUI = ISPanel:derive("ToothMapUI")

-----------------------------------------------------------
-- UI Constants
-----------------------------------------------------------
ToothMapUI.WIDTH = 320
ToothMapUI.HEIGHT = 240
ToothMapUI.TOOTH_SIZE = 14
ToothMapUI.TOOTH_SPACING = 2
ToothMapUI.JAW_PADDING = 20
ToothMapUI.HEADER_HEIGHT = 30
ToothMapUI.FOOTER_HEIGHT = 40

-----------------------------------------------------------
-- Color Mapping for Tooth States
-- Property 5: Each state maps to exactly one distinct color
-----------------------------------------------------------
ToothMapUI.COLORS = {
    healthy = {r=0.2, g=0.8, b=0.2, a=1.0},    -- Green
    cavity = {r=0.9, g=0.9, b=0.2, a=1.0},     -- Yellow
    infected = {r=1.0, g=0.5, b=0.0, a=1.0},   -- Orange
    broken = {r=0.9, g=0.2, b=0.2, a=1.0},     -- Red
    extracted = {r=0.4, g=0.4, b=0.4, a=0.5},  -- Gray (semi-transparent)
}

-- Border colors
ToothMapUI.BORDER_COLOR = {r=0.5, g=0.5, b=0.5, a=1.0}
ToothMapUI.HOVER_BORDER_COLOR = {r=1.0, g=1.0, b=1.0, a=1.0}
ToothMapUI.BACKGROUND_COLOR = {r=0.1, g=0.1, b=0.1, a=0.9}
ToothMapUI.JAW_LINE_COLOR = {r=0.3, g=0.3, b=0.3, a=1.0}

-----------------------------------------------------------
-- Tooth Positions
-- Defines x, y offsets for each of 32 teeth
-- Upper jaw: teeth 1-16 (right 1-8, left 9-16)
-- Lower jaw: teeth 17-32 (left 17-24, right 25-32)
-----------------------------------------------------------
function ToothMapUI:calculateToothPositions()
    local positions = {}
    local toothSize = self.TOOTH_SIZE
    local spacing = self.TOOTH_SPACING
    local centerX = self.width / 2
    local upperY = self.HEADER_HEIGHT + 30
    local lowerY = self.HEADER_HEIGHT + 100
    
    -- Calculate total width for 8 teeth
    local rowWidth = 8 * (toothSize + spacing) - spacing
    
    -- Upper jaw - Right side (teeth 1-8, from center going right)
    for i = 1, 8 do
        local x = centerX + (i - 1) * (toothSize + spacing)
        positions[i] = {x = x, y = upperY}
    end
    
    -- Upper jaw - Left side (teeth 9-16, from center going left)
    for i = 9, 16 do
        local offset = i - 8
        local x = centerX - offset * (toothSize + spacing)
        positions[i] = {x = x, y = upperY}
    end
    
    -- Lower jaw - Left side (teeth 17-24, from center going left)
    for i = 17, 24 do
        local offset = i - 16
        local x = centerX - offset * (toothSize + spacing)
        positions[i] = {x = x, y = lowerY}
    end
    
    -- Lower jaw - Right side (teeth 25-32, from center going right)
    for i = 25, 32 do
        local offset = i - 24
        local x = centerX + (offset - 1) * (toothSize + spacing)
        positions[i] = {x = x, y = lowerY}
    end
    
    return positions
end

-----------------------------------------------------------
-- Get Color for Tooth State
-- Returns the color table for a given tooth state
-----------------------------------------------------------
function ToothMapUI:getColorForState(state)
    return self.COLORS[state] or self.COLORS.healthy
end

-----------------------------------------------------------
-- Get Tooth At Position (Hit Detection)
-- Returns tooth index if mouse is over a tooth, nil otherwise
-----------------------------------------------------------
function ToothMapUI:getToothAtPosition(x, y)
    if not self.toothPositions then return nil end
    
    local toothSize = self.TOOTH_SIZE
    
    for i = 1, 32 do
        local pos = self.toothPositions[i]
        if pos then
            if x >= pos.x and x <= pos.x + toothSize and
               y >= pos.y and y <= pos.y + toothSize then
                return i
            end
        end
    end
    
    return nil
end

-----------------------------------------------------------
-- Constructor
-----------------------------------------------------------
function ToothMapUI:new(x, y, player)
    local o = ISPanel:new(x, y, ToothMapUI.WIDTH, ToothMapUI.HEIGHT)
    setmetatable(o, self)
    self.__index = self
    
    o.player = player
    o.backgroundColor = ToothMapUI.BACKGROUND_COLOR
    o.borderColor = ToothMapUI.BORDER_COLOR
    o.moveWithMouse = true
    o.hoveredTooth = nil
    o.toothPositions = nil
    
    return o
end

-----------------------------------------------------------
-- Initialise
-----------------------------------------------------------
function ToothMapUI:initialise()
    ISPanel.initialise(self)
    self.toothPositions = self:calculateToothPositions()
end

-----------------------------------------------------------
-- Create Children (for close button, etc.)
-----------------------------------------------------------
function ToothMapUI:createChildren()
    ISPanel.createChildren(self)
    
    -- Close button
    local btnSize = 20
    local this = self -- capture self for closure
    self.closeButton = ISButton:new(
        self.width - btnSize - 5, 5,
        btnSize, btnSize,
        "X", self, function() this:onClose() end
    )
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
    self:addChild(self.closeButton)
end

-----------------------------------------------------------
-- Close Button Handler
-----------------------------------------------------------
function ToothMapUI:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
end

-----------------------------------------------------------
-- Override onMouseDown to prevent returning true
-- ISPanel.onMouseDown returns true when moveWithMouse is false
-- which causes "Object true did not have __call" errors
-----------------------------------------------------------
function ToothMapUI:onMouseDown(x, y)
    if not self:getIsVisible() then
        return
    end
    -- Note: Don't call self:isMouseOver() - it can return true directly in B42
    -- Just handle the drag logic
    if self.moveWithMouse then
        self.downX = x
        self.downY = y
        self.moving = true
        self:bringToTop()
    end
    -- Don't return anything (especially not true)
end


-----------------------------------------------------------
-- Prerender - Draw background and static elements
-----------------------------------------------------------
function ToothMapUI:prerender()
    ISPanel.prerender(self)
    
    local bg = self.backgroundColor
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1.0, 0.4, 0.4, 0.4)
    
    -- Draw title
    local title = getText("IGUI_ToothMap_Title") or "Tooth Map"
    local titleWidth = getTextManager():MeasureStringX(UIFont.Medium, title)
    self:drawText(title, (self.width - titleWidth) / 2, 8, 1, 1, 1, 1, UIFont.Medium)
end

-----------------------------------------------------------
-- Render - Draw teeth and dynamic elements
-----------------------------------------------------------
function ToothMapUI:render()
    ISPanel.render(self)
    
    if not self.player or self.player:isDead() then
        return
    end
    
    -- Ensure ToothManager is initialized
    DentalPain.ToothManager.ensureInitialized(self.player)
    
    -- Draw jaw outlines
    self:drawJawOutlines()
    
    -- Draw all 32 teeth
    self:drawTeeth()
    
    -- Draw summary (overall health and teeth count)
    self:drawSummary()
    
    -- Draw tooltip if hovering over a tooth
    if self.hoveredTooth then
        self:drawToothTooltip(self.hoveredTooth)
    end
end

-----------------------------------------------------------
-- Draw Jaw Outlines
-----------------------------------------------------------
function ToothMapUI:drawJawOutlines()
    local lineColor = self.JAW_LINE_COLOR
    local centerX = self.width / 2
    local upperY = self.HEADER_HEIGHT + 30
    local lowerY = self.HEADER_HEIGHT + 100
    local toothSize = self.TOOTH_SIZE
    local spacing = self.TOOTH_SPACING
    local rowWidth = 8 * (toothSize + spacing)
    
    -- Upper jaw label
    local upperLabel = getText("IGUI_ToothMap_UpperJaw") or "Upper Jaw"
    local upperLabelWidth = getTextManager():MeasureStringX(UIFont.Small, upperLabel)
    self:drawText(upperLabel, (self.width - upperLabelWidth) / 2, upperY - 18, 0.7, 0.7, 0.7, 1, UIFont.Small)
    
    -- Lower jaw label
    local lowerLabel = getText("IGUI_ToothMap_LowerJaw") or "Lower Jaw"
    local lowerLabelWidth = getTextManager():MeasureStringX(UIFont.Small, lowerLabel)
    self:drawText(lowerLabel, (self.width - lowerLabelWidth) / 2, lowerY - 18, 0.7, 0.7, 0.7, 1, UIFont.Small)
    
    -- Draw center line (dividing left/right)
    self:drawRect(centerX - 1, upperY - 5, 2, toothSize + 10, 0.3, lineColor.r, lineColor.g, lineColor.b)
    self:drawRect(centerX - 1, lowerY - 5, 2, toothSize + 10, 0.3, lineColor.r, lineColor.g, lineColor.b)
    
    -- Side labels
    local leftLabel = "L"
    local rightLabel = "R"
    self:drawText(leftLabel, centerX - rowWidth - 15, upperY + 2, 0.5, 0.5, 0.5, 1, UIFont.Small)
    self:drawText(rightLabel, centerX + rowWidth + 5, upperY + 2, 0.5, 0.5, 0.5, 1, UIFont.Small)
    self:drawText(leftLabel, centerX - rowWidth - 15, lowerY + 2, 0.5, 0.5, 0.5, 1, UIFont.Small)
    self:drawText(rightLabel, centerX + rowWidth + 5, lowerY + 2, 0.5, 0.5, 0.5, 1, UIFont.Small)
end

-----------------------------------------------------------
-- Draw All Teeth
-----------------------------------------------------------
function ToothMapUI:drawTeeth()
    if not self.toothPositions then return end
    
    local teeth = DentalPain.ToothManager.getAllTeeth(self.player)
    if not teeth then return end
    
    local toothSize = self.TOOTH_SIZE
    
    for i = 1, 32 do
        local pos = self.toothPositions[i]
        local tooth = teeth[i]
        
        if pos and tooth then
            local color = self:getColorForState(tooth.state)
            local isHovered = (self.hoveredTooth == i)
            
            -- Draw tooth fill
            self:drawRect(pos.x, pos.y, toothSize, toothSize, color.a, color.r, color.g, color.b)
            
            -- Draw border (highlighted if hovered)
            if isHovered then
                local hc = self.HOVER_BORDER_COLOR
                self:drawRectBorder(pos.x - 1, pos.y - 1, toothSize + 2, toothSize + 2, hc.a, hc.r, hc.g, hc.b)
            else
                local bc = self.BORDER_COLOR
                self:drawRectBorder(pos.x, pos.y, toothSize, toothSize, bc.a, bc.r, bc.g, bc.b)
            end
            
            -- Draw health indicator (small bar at bottom for non-extracted teeth)
            if tooth.state ~= DentalPain.ToothState.EXTRACTED and tooth.health < 100 then
                local healthWidth = (toothSize - 2) * (tooth.health / 100)
                self:drawRect(pos.x + 1, pos.y + toothSize - 3, healthWidth, 2, 0.8, 0.2, 0.8, 0.2)
            end
        end
    end
end

-----------------------------------------------------------
-- Draw Summary (Overall Health and Teeth Count)
-- Validates: Requirements 2.5
-----------------------------------------------------------
function ToothMapUI:drawSummary()
    local footerY = self.height - self.FOOTER_HEIGHT + 5
    
    -- Get stats from ToothManager
    local overallHealth = DentalPain.ToothManager.getOverallHealth(self.player)
    local remainingCount = DentalPain.ToothManager.getRemainingCount(self.player)
    
    -- Format health percentage
    local healthText = string.format("%s: %.0f%%", 
        getText("IGUI_ToothMap_OverallHealth") or "Overall Health", 
        overallHealth)
    
    -- Format teeth count
    local countText = string.format("%s: %d/32", 
        getText("IGUI_ToothMap_TeethRemaining") or "Teeth Remaining", 
        remainingCount)
    
    -- Draw health bar background
    local barX = 20
    local barY = footerY
    local barWidth = self.width - 40
    local barHeight = 12
    
    self:drawRect(barX, barY, barWidth, barHeight, 0.5, 0.2, 0.2, 0.2)
    
    -- Draw health bar fill
    local fillWidth = barWidth * (overallHealth / 100)
    local healthColor = self:getHealthBarColor(overallHealth)
    self:drawRect(barX, barY, fillWidth, barHeight, 0.8, healthColor.r, healthColor.g, healthColor.b)
    
    -- Draw health bar border
    self:drawRectBorder(barX, barY, barWidth, barHeight, 0.8, 0.4, 0.4, 0.4)
    
    -- Draw text labels
    self:drawText(healthText, barX, barY + barHeight + 3, 1, 1, 1, 1, UIFont.Small)
    
    local countWidth = getTextManager():MeasureStringX(UIFont.Small, countText)
    self:drawText(countText, self.width - barX - countWidth, barY + barHeight + 3, 1, 1, 1, 1, UIFont.Small)
end

-----------------------------------------------------------
-- Get Health Bar Color based on percentage
-----------------------------------------------------------
function ToothMapUI:getHealthBarColor(health)
    if health > 75 then
        return {r=0.2, g=0.8, b=0.2}
    elseif health > 50 then
        return {r=0.8, g=0.8, b=0.2}
    elseif health > 25 then
        return {r=0.8, g=0.5, b=0.2}
    else
        return {r=0.8, g=0.2, b=0.2}
    end
end

-----------------------------------------------------------
-- Draw Tooth Tooltip
-- Property 6: Tooltip contains tooth name, health %, state
-- Validates: Requirements 2.3
-----------------------------------------------------------
function ToothMapUI:drawToothTooltip(toothIndex)
    local tooth = DentalPain.ToothManager.getToothByIndex(self.player, toothIndex)
    if not tooth then return end
    
    -- Build tooltip text
    local nameText = tooth.name
    local healthText = string.format("%s: %d%%", 
        getText("IGUI_ToothMap_Health") or "Health", 
        math.floor(tooth.health))
    local stateText = string.format("%s: %s", 
        getText("IGUI_ToothMap_State") or "State", 
        self:getStateDisplayName(tooth.state))
    
    -- Calculate tooltip dimensions
    local padding = 8
    local lineHeight = 16
    local tooltipWidth = math.max(
        getTextManager():MeasureStringX(UIFont.Small, nameText),
        getTextManager():MeasureStringX(UIFont.Small, healthText),
        getTextManager():MeasureStringX(UIFont.Small, stateText)
    ) + padding * 2
    local tooltipHeight = lineHeight * 3 + padding * 2
    
    -- Position tooltip near mouse but within panel bounds
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local tooltipX = mouseX + 15
    local tooltipY = mouseY + 15
    
    -- Keep tooltip within panel bounds
    if tooltipX + tooltipWidth > self.width then
        tooltipX = mouseX - tooltipWidth - 5
    end
    if tooltipY + tooltipHeight > self.height then
        tooltipY = mouseY - tooltipHeight - 5
    end
    
    -- Draw tooltip background
    self:drawRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 0.95, 0.15, 0.15, 0.15)
    self:drawRectBorder(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 1.0, 0.5, 0.5, 0.5)
    
    -- Draw tooltip text
    local textX = tooltipX + padding
    local textY = tooltipY + padding
    
    -- Tooth name (bold/highlighted)
    self:drawText(nameText, textX, textY, 1, 1, 0.8, 1, UIFont.Small)
    textY = textY + lineHeight
    
    -- Health percentage
    local healthColor = self:getHealthBarColor(tooth.health)
    self:drawText(healthText, textX, textY, healthColor.r, healthColor.g, healthColor.b, 1, UIFont.Small)
    textY = textY + lineHeight
    
    -- State
    local stateColor = self:getColorForState(tooth.state)
    self:drawText(stateText, textX, textY, stateColor.r, stateColor.g, stateColor.b, 1, UIFont.Small)
end

-----------------------------------------------------------
-- Get Display Name for Tooth State
-----------------------------------------------------------
function ToothMapUI:getStateDisplayName(state)
    local stateNames = {
        healthy = getText("IGUI_ToothState_Healthy") or "Healthy",
        cavity = getText("IGUI_ToothState_Cavity") or "Cavity",
        infected = getText("IGUI_ToothState_Infected") or "Infected",
        broken = getText("IGUI_ToothState_Broken") or "Broken",
        extracted = getText("IGUI_ToothState_Extracted") or "Extracted",
    }
    return stateNames[state] or state
end

-----------------------------------------------------------
-- Mouse Move Handler - Detect hover over teeth
-- Validates: Requirements 2.3
-----------------------------------------------------------
function ToothMapUI:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)
    
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    
    self.hoveredTooth = self:getToothAtPosition(mouseX, mouseY)
end

-----------------------------------------------------------
-- Mouse Move Outside Handler
-----------------------------------------------------------
function ToothMapUI:onMouseMoveOutside(dx, dy)
    ISPanel.onMouseMoveOutside(self, dx, dy)
    self.hoveredTooth = nil
end

-----------------------------------------------------------
-- Update function (called each frame)
-----------------------------------------------------------
function ToothMapUI:update()
    ISPanel.update(self)
    
    -- Close if player is dead
    if not self.player or self.player:isDead() then
        self:onClose()
    end
end

-----------------------------------------------------------
-- Static: Create and show the tooth map UI
-----------------------------------------------------------
function ToothMapUI.show(player)
    if not player then return nil end
    
    -- Calculate center position
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = (screenW - ToothMapUI.WIDTH) / 2
    local y = (screenH - ToothMapUI.HEIGHT) / 2
    
    local ui = ToothMapUI:new(x, y, player)
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    
    return ui
end

-- Store reference in DentalPain namespace
DentalPain.UI.ToothMapUI = ToothMapUI

return ToothMapUI
