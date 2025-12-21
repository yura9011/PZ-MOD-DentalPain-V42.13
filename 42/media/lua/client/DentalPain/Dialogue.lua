-- DentalPain/Dialogue.lua
-- Enhanced character dialogue system for DentalPain

local DP = DentalPain or {}

DP.Dialogue = {
    -- Expanded phrase system - more variety per category
    Categories = {
        Severe = {
            "IGUI_DentalPain_Severe1",
            "IGUI_DentalPain_Severe2",
            "IGUI_DentalPain_Severe3",
            "IGUI_DentalPain_Severe4",
            "IGUI_DentalPain_Severe5",
            "IGUI_DentalPain_Severe6",
            "IGUI_DentalPain_Severe7",
            "IGUI_DentalPain_Severe8",
        },
        Mild = {
            "IGUI_DentalPain_Mild1",
            "IGUI_DentalPain_Mild2",
            "IGUI_DentalPain_Mild3",
            "IGUI_DentalPain_Mild4",
            "IGUI_DentalPain_Mild5",
            "IGUI_DentalPain_Mild6",
        },
        Relief = {
            "IGUI_DentalPain_Relief1",
            "IGUI_DentalPain_Relief2",
            "IGUI_DentalPain_Relief3",
            "IGUI_DentalPain_Relief4",
            "IGUI_DentalPain_Relief5",
        },
        Numbed = {
            "IGUI_DentalPain_Numbed1",
            "IGUI_DentalPain_Numbed2",
            "IGUI_DentalPain_Numbed3",
            "IGUI_DentalPain_Numbed4",
        },
        Extraction = {
            Success = "IGUI_DentalPain_ExtractSuccess",
            Fail = "IGUI_DentalPain_ExtractFail",
            Broken = "IGUI_DentalPain_ToothBroke"
        },
        FoodPain = {
            "IGUI_DentalPain_FoodPain1",
            "IGUI_DentalPain_FoodPain2",
            "IGUI_DentalPain_FoodPain3",
            "IGUI_DentalPain_FoodPain4",
        },
        Abscess = {
            "IGUI_DentalPain_Abscess1",
            "IGUI_DentalPain_Abscess2",
        }
    }
}

-- Phrases Pool (Internal logic for picking)
function DP.Dialogue.sayRandom(player, category, subCategory)
    if not player then return end
    
    local pool = DP.Dialogue.Categories[category]
    if not pool then return end
    
    -- Handle sub-categories (e.g. Extraction.Success)
    if subCategory and type(pool) == "table" then
        pool = pool[subCategory]
    end
    
    if not pool then return end
    
    local key
    if type(pool) == "table" then
        key = pool[ZombRand(#pool) + 1]
    else
        key = pool
    end
    
    if not key then return end
    
    local text = getText(key)
    if text then
        -- Log to console for debugging
        if DP.Config.DebugMode then
            print("[DentalPain] Text Triggered: " .. text)
        end
        
        -- Use standard speech bubble
        player:Say(text)
        
        -- Optional: Also use HaloText for visibility if preferred
        -- if HaloTextHelper then
        --     HaloTextHelper.addText(player, text, 255, 255, 255)
        -- end
    else
        print("[DentalPain] Missing translation for key: " .. key)
        -- Fallback to key if translation missing (Debug)
        if DP.Config.DebugMode then
            player:Say(key)
        end
    end
end

-- React based on state
function DP.Dialogue.checkAutoSpeech(player)
    local health = DP.getDentalHealth(player)
    
    if DP.isNumbed(player) then
        -- 5% chance to comment on being numbed
        if ZombRand(100) < 5 then
            DP.Dialogue.sayRandom(player, "Numbed")
        end
        return
    end

    if health < DP.Config.PainThreshold then
        -- 15% chance to complain about severe pain
        if ZombRand(100) < 15 then
            DP.Dialogue.sayRandom(player, "Severe")
            DentalPain.playPainSound(player)
        end
    elseif health < DP.Config.MildThreshold then
        -- 5% chance to complain about mild discomfort
        if ZombRand(100) < 5 then
            DP.Dialogue.sayRandom(player, "Mild")
        end
    end
end

return DP
