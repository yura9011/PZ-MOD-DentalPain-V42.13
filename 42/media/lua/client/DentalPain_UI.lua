-- DentalPain UI - Visual Status Bar
-- Uses deferred initialization to avoid breaking other mods

require "DentalPain/Core"

-- Storage
local dentalBars = {}
local toothMapUIs = {}
local DentalPainUI = nil

-- Configuration (default values)
local Config = {
    width = 120,
    height = 20,
    x = 20,
    y = 200,
    backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7},
    showText = true,
}

-- File-based position persistence
local POSITION_FILE = "DentalPain_UIPosition.ini"

local function savePosition(x, y)
    local writer = getFileWriter(POSITION_FILE, true, false)
    if writer then
        writer:write("x=" .. tostring(math.floor(x)) .. "\n")
        writer:write("y=" .. tostring(math.floor(y)) .. "\n")
        writer:close()
    end
end

local function loadPosition()
    local reader = getFileReader(POSITION_FILE, true)
    if not reader then return nil, nil end
    
    local savedX, savedY = nil, nil
    local line = reader:readLine()
    while line do
        local key, value = string.match(line, "(%w+)=(%d+)")
        if key == "x" then savedX = tonumber(value) end
        if key == "y" then savedY = tonumber(value) end
        line = reader:readLine()
    end
    reader:close()
    return savedX, savedY
end

-- Initialize the UI class (called once when game is ready)
local function initUI()
    if DentalPainUI then return true end
    
    if not ISPanel then
        return false
    end
    
    DentalPainUI = ISPanel:derive("DentalPainUI")
    
    function DentalPainUI:getHealthColor(health)
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

    -- Save position when mouse released after dragging
    function DentalPainUI:onMouseUp(x, y)
        ISPanel.onMouseUp(self, x, y)
        -- Save position to file for persistence between sessions
        savePosition(self:getX(), self:getY())
    end

    function DentalPainUI:prerender()
        ISPanel.prerender(self)
        
        if not self.player or self.player:isDead() then
            return
        end
        
        local modData = self.player:getModData()
        local health = 100
        if modData and modData.dentalHealth then
            health = modData.dentalHealth
        end
        
        local hasBrokenTooth = modData and modData.hasBrokenTooth
        local teethExtracted = (modData and modData.teethExtracted) or 0
        
        health = health < 0 and 0 or (health > 100 and 100 or health)
        
        local bg = self.backgroundColor
        self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
        
        if hasBrokenTooth then
            self:drawRectBorder(0, 0, self.width, self.height, 1.0, 1.0, 0.0, 0.0)
        else
            self:drawRectBorder(0, 0, self.width, self.height, 0.8, 0.3, 0.3, 0.3)
        end
        
        local barWidth = ((self.width - 4) * health) / 100
        local color = hasBrokenTooth and {r=1, g=0, b=0} or self:getHealthColor(health)
        self:drawRect(2, 2, barWidth, self.height - 4, 0.8, color.r, color.g, color.b)
        
        if Config.showText then
            local text
            if hasBrokenTooth then
                text = "BROKEN TOOTH!"
            elseif teethExtracted > 0 then
                text = "Teeth: " .. math.floor(health) .. "% (-" .. teethExtracted .. ")"
            else
                text = "Teeth: " .. math.floor(health) .. "%"
            end
            local textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
            local textX = (self.width - textWidth) / 2
            
            if hasBrokenTooth then
                self:drawText(text, textX, 3, 1, 0.2, 0.2, 1, UIFont.Small)
            else
                self:drawText(text, textX, 3, 1, 1, 1, 1, UIFont.Small)
            end
        end
        
        -- Draw hint for right-click (small text at bottom when hovered)
        if self.isMouseOver then
            -- Get skill level
            local skillLevel = 0
            if DentalPain.SkillManager then
                skillLevel = DentalPain.SkillManager.getLevel(self.player)
            end
            
            local hint = "Dental Skill: Lv" .. skillLevel .. " | Right-click: Tooth Map"
            local hintWidth = getTextManager():MeasureStringX(UIFont.Small, hint)
            self:drawText(hint, (self.width - hintWidth) / 2, self.height + 2, 0.7, 0.7, 0.7, 0.8, UIFont.Small)
        end
    end
    
    function DentalPainUI:onMouseMove(dx, dy)
        ISPanel.onMouseMove(self, dx, dy)
        self.isMouseOver = true
    end
    
    function DentalPainUI:onMouseMoveOutside(dx, dy)
        ISPanel.onMouseMoveOutside(self, dx, dy)
        self.isMouseOver = false
    end
    
    -- Override onMouseDown to prevent 'Object true did not have __call' error
    function DentalPainUI:onMouseDown(x, y)
        if not self:getIsVisible() then
            return
        end
        -- Note: Don't call self:isMouseOver() - it can return true directly
        -- Just handle the drag logic
        if self.moveWithMouse then
            self.downX = x
            self.downY = y
            self.moving = true
            self:bringToTop()
        end
        -- Don't return anything
    end

    function DentalPainUI:new(player, savedX, savedY)
        local x = savedX or Config.x
        local y = savedY or Config.y
        local o = ISPanel:new(x, y, Config.width, Config.height)
        setmetatable(o, self)
        self.__index = self
        
        o.player = player
        o.backgroundColor = Config.backgroundColor
        o.moveWithMouse = true
        
        return o
    end
    
    -- Handle right-click to show tooth map
    function DentalPainUI:onRightMouseUp(x, y)
        if self.player and not self.player:isDead() then
            self:showToothMap()
        end
        return true
    end
    
    -- Show the tooth map UI
    function DentalPainUI:showToothMap()
        local playerNum = self.player:getPlayerNum()
        
        -- Close existing tooth map if open
        if toothMapUIs[playerNum] then
            pcall(function()
                toothMapUIs[playerNum]:removeFromUIManager()
            end)
            toothMapUIs[playerNum] = nil
        end
        
        -- Create and show new tooth map
        if DentalPain.UI and DentalPain.UI.ToothMapUI then
            local toothMap = DentalPain.UI.ToothMapUI.show(self.player)
            if toothMap then
                toothMapUIs[playerNum] = toothMap
            end
        end
    end
    
    return true
end

-- Create UI on player spawn
local function onCreatePlayer(playerNum, player)
    if not player then return end
    
    if not initUI() then
        return
    end
    
    -- Remove existing bar if any
    if dentalBars[playerNum] then
        pcall(function()
            dentalBars[playerNum]:removeFromUIManager()
        end)
        dentalBars[playerNum] = nil
    end
    
    -- Load saved position from file
    local savedX, savedY = loadPosition()
    
    -- Create new bar with saved position
    local success, err = pcall(function()
        local bar = DentalPainUI:new(player, savedX, savedY)
        bar:initialise()
        bar:addToUIManager()
        dentalBars[playerNum] = bar
    end)
    
    if not success then
        print("DentalPain: Error creating UI: " .. tostring(err))
    end
end

-- Remove UI on player death
local function onPlayerDeath(player)
    if not player then return end
    local playerNum = player:getPlayerNum()
    
    if dentalBars[playerNum] then
        pcall(function()
            dentalBars[playerNum]:removeFromUIManager()
        end)
        dentalBars[playerNum] = nil
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnPlayerDeath.Add(onPlayerDeath)
