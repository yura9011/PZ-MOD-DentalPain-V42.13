-- DentalPain Item Distribution
-- Makes dental items spawn in appropriate locations

require 'Items/ProceduralDistributions'

local function addItemToContainer(containerName, itemName, weight)
    if ProceduralDistributions.list[containerName] and ProceduralDistributions.list[containerName].items then
        table.insert(ProceduralDistributions.list[containerName].items, itemName)
        table.insert(ProceduralDistributions.list[containerName].items, weight)
    end
end

Events.OnGameBoot.Add(function()
    -- Toothpaste in bathroom counters
    addItemToContainer("BathroomCounter", "Base.Toothpaste", 20)
    
    -- Toothbrush in bathroom counters
    addItemToContainer("BathroomCounter", "Base.Toothbrush", 15)
    
    -- Toothpaste also in bathroom cabinets
    addItemToContainer("BathroomCabinet", "Base.Toothpaste", 15)
    
    -- Toothbrush in bathroom cabinets
    addItemToContainer("BathroomCabinet", "Base.Toothbrush", 10)
end)
