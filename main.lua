print("STARTING LA-AROX V1...")

-- IMPORTANT!!! THE DEFAULT CONFIGURATIONS WORKS FINE FOR THE AROX SCRIPT, BUT YOU CAN CHANGE THE CONFIGURATIONS TO YOUR NEEDS.
-- ONLY CHANGE THE CONFIGURATIONS IF YOU KNOW WHAT YOU ARE DOING.

-- THE 2 ONLY THINGS YOU NEED TO CHANGE ARE THE KEY AND THE DISCORD WEBHOOK.

-- KEY FOR THE AROX SCRIPT
-- IMPORTANT, IN AROX, ENABLE THE VOID MOBS, AUTO LOOT (CONFIGURE THIS) AND NO CLIP
-- IMPORTANT, IN AROX DISABLE THE AUTO EXECUTE
getgenv().script_key = "YOUR_AROX_KEY_HERE"

-- DISCORD WEBHOOK FOR THE AROX SCRIPT
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"

-- MINIMUM VITAL STATS FOR THE SCRIPT TO WORK
local MIN_STOMACH = 30
local MIN_WATER = 30
local MIN_BLOOD = 30

-- TIMEOUT FOR THE AROX SCRIPT TO EXECUTE
local TIMEOUT_AROX_EXECUTION = 15

-- LEAVE TIMER FOR RETURN TO LOBBY IN CASE OF AROX SCRIPT FAILURE
local LEAVE_TIMER = 120

-- WAIT TIME FOR THE TELEPORTATION TO THE TITUS PORTAL
local WAIT_TIME_TELEPORT = 15

-- WAIT TIME BETWEEN AUTO PRESS KEYS WHEN NOT IN LOBBY
local AUTO_PRESS_INTERVAL = 20

-- DISTANCE FOR LEAVE WHEN DETECT A PLAYER
local DETECTOR_DISTANCE_LEAVE = 500


-- ============================================================
-- SERVICES AND GLOBAL VARIABLES
-- ============================================================
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Aguarda LocalPlayer existir antes de continuar
local LocalPlayer = Players.LocalPlayer
repeat
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
until LocalPlayer ~= nil

print("✅ LocalPlayer encontrado: " .. LocalPlayer.Name)

local gethuiFunc = rawget(_G, "gethui")
local parentUi = (typeof(gethuiFunc) == "function" and gethuiFunc()) or game:FindFirstChildOfClass("CoreGui")

-- States
local joinEnabled = true
local autoEnabled = true
local leaveTimerEnabled = true 
local detectorEnabled = true
local modDetectorEnabled = true
local vitalsMonitorEnabled = true
local scriptEncerrado = false -- Flag to stop everything 
local vitalsTriggered = false

-- General Configs
local GUI_NAME = "TopbarGui"
local CONTAINER_NAME = "Container"
local BUTTON_NAME = "MenuLabel"

-- ============================================================
-- GLOBAL UTILITY FUNCTIONS
-- ============================================================

local function clickMenuLabel()
    print("🚨 EXIT ACTION TRIGGERED!")
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    local topbar = pGui:FindFirstChild(GUI_NAME)
    local container = topbar and topbar:FindFirstChild(CONTAINER_NAME)
    local button = container and container:FindFirstChild(BUTTON_NAME)

    if button and button.Visible then
        local absPos = button.AbsolutePosition
        local absSize = button.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        
        local centerX = absPos.X + (absSize.X / 2)
        local centerY = absPos.Y + (absSize.Y / 2) + inset.Y

        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
        print("🖱️ Click performed on MenuLabel.")
    end
end

local function simulateClick(guiObject)
    if not guiObject then return end
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2) + inset.Y
    
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
end

local function getOverlay()
    local success, pg = pcall(function()
        if not LocalPlayer then return nil end
        return LocalPlayer:FindFirstChild("PlayerGui")
    end)
    if not success or not pg then return nil end
    
    local loading = pg:FindFirstChild("LoadingGui")
    if not loading then return nil end
    
    return loading:FindFirstChild("Overlay")
end

-- MOVED THIS FUNCTION HERE TO BE USED AT THE START
local function verificarLobby()
    local overlay = getOverlay()
    local options = overlay and overlay:FindFirstChild("Options")
    local btnContinue = options and options:FindFirstChild("Option")
    return btnContinue ~= nil
end

local function verificarBotaoSair()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return false end
    
    local topbar = pGui:FindFirstChild(GUI_NAME)
    local container = topbar and topbar:FindFirstChild(CONTAINER_NAME)
    local button = container and container:FindFirstChild(BUTTON_NAME)
    
    return button ~= nil and button.Visible
end

local function findElementByText(textToFind)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil, nil end
    for _, obj in pairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
            if string.find(string.lower(obj.Text), string.lower(textToFind)) then
                local caminho = obj:GetFullName()
                return obj, caminho
            end
        end
    end
    return nil, nil
end

local function extrairLetraSlot(caminho)
    if not caminho then return nil end
    -- Searches for "Slots." followed by a letter and then "."
    local letra = string.match(caminho, "Slots%.([A-Z])%.")
    return letra
end

local function pegarTextoRealm(elemento)
    if not elemento then return nil end
    -- Navigates to the Realm element inside SlotPick
    -- Path: ...Slots.A.SlotPick.Realm
    local parent = elemento.Parent
    while parent do
        if parent.Name == "SlotPick" then
            local realm = parent:FindFirstChild("Realm")
            if realm and (realm:IsA("TextLabel") or realm:IsA("TextButton")) then
                return realm.Text
            end
        end
        parent = parent.Parent
    end
    return nil
end

local function mostrarPopupErro(mensagem, tempo)
    tempo = tempo or 5
    local popupGui = Instance.new("ScreenGui")
    popupGui.Name = "ErroPopup"
    popupGui.ResetOnSpawn = false
    popupGui.Parent = parentUi
    
    local popupFrame = Instance.new("Frame")
    popupFrame.Size = UDim2.new(0, 400, 0, 120)
    popupFrame.Position = UDim2.new(0.5, -200, 0.5, -60)
    popupFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    popupFrame.BorderSizePixel = 0
    Instance.new("UICorner", popupFrame).CornerRadius = UDim.new(0, 10)
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = popupFrame
    uiStroke.Color = Color3.fromRGB(255, 50, 50)
    uiStroke.Thickness = 3
    
    local popupLabel = Instance.new("TextLabel")
    popupLabel.Size = UDim2.new(1, -40, 1, -40)
    popupLabel.Position = UDim2.new(0, 20, 0, 20)
    popupLabel.BackgroundTransparency = 1
    popupLabel.Font = Enum.Font.GothamBold
    popupLabel.TextSize = 18
    popupLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    popupLabel.TextWrapped = true
    popupLabel.Text = mensagem
    popupLabel.Parent = popupFrame
    
    popupFrame.Parent = popupGui
    
    -- Removes after the specified time
    task.spawn(function()
        task.wait(tempo)
        popupGui:Destroy()
    end)
end

local function verificarTitleEasternLuminant()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    
    local mapGui = pg:FindFirstChild("MapGui")
    if not mapGui then return nil end
    
    local mainFrame = mapGui:FindFirstChild("MainFrame")
    if not mainFrame then return nil end
    
    local scroll = mainFrame:FindFirstChild("Scroll")
    if not scroll then return nil end
    
    local mapClip = scroll:FindFirstChild("MapClip")
    if not mapClip then return nil end
    
    local mapContainer = mapClip:FindFirstChild("MapContainer")
    if not mapContainer then return nil end
    
    local title = mapContainer:FindFirstChild("Title")
    if not title then return nil end
    
    if title:IsA("TextLabel") or title:IsA("TextButton") then
        local textoUpper = string.upper(title.Text)
        print("Title text: " .. textoUpper)
        return textoUpper
    else
        print("❌ Title is not a TextLabel or TextButton")
        return nil
    end
end

local function verificarDetainmentCore()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, obj in pairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Visible then
            if string.find(string.lower(obj.Text), string.lower("DetainmentCore")) then
                return true
            end
        end
    end
    return false
end

local function encerrarTudo()
    scriptEncerrado = true
    
    -- Disables all functions
    joinEnabled = false
    autoEnabled = false
    leaveTimerEnabled = false
    detectorEnabled = false
    modDetectorEnabled = false
    
    -- Destroys all GUIs from StatusGui
    task.spawn(function()
        task.wait(0.1) -- Waits a bit to ensure StatusGui was created
        local statusGui = parentUi:FindFirstChild("StatusOverlay")
        if statusGui then
            statusGui:Destroy()
        end
    end)
    
    print("🛑 Script stopped - All functions disabled")
end

local function getWorkspaceStatPercent(statName)
    if not LocalPlayer or not LocalPlayer.Name then return nil end
    local liveFolder = workspace:FindFirstChild("Live")
    if not liveFolder then return nil end

    local playerModel = liveFolder:FindFirstChild(LocalPlayer.Name)
    local statObj = playerModel and playerModel:FindFirstChild(statName)
    if statObj and statObj:IsA("ValueBase") then
        local ok, value = pcall(function()
            return statObj.Value
        end)
        if ok and typeof(value) == "number" then
            return math.floor(value)
        end
    end
    return nil
end

local function startInfiniteExitClicks()
    task.spawn(function()
        while true do
            pcall(function()
                clickMenuLabel()
            end)
            task.wait(1)
        end
    end)
end


local function buildInventoryEmbed(data)
    local embed = {
        title = data.title or "LA-AROX V1",
        color = 0x2A3BFF,
        footer = {
            text = string.format("LA-AROX SYSTEM • Hoje às %s", os.date("%H:%M"))
        }
    }

    if data.description then
        embed.description = data.description
        return embed
    end

    local vitalText = string.format("• Stomach: %d%%\n• Water: %d%%\n• Blood: %d%%", data.vitals.stomach, data.vitals.water, data.vitals.blood)

    embed.fields = {
        {
            name = "Player:",
            value = string.format("`%s`", data.player or "Unknown"),
            inline = false
        },
        {
            name = "✨ Relics:",
            value = data.relicText,
            inline = false
        },
        {
            name = "🍎 Food:",
            value = data.foodText,
            inline = false
        },
        {
            name = "💚 Vital Stats:",
            value = vitalText,
            inline = false
        }
    }

    return embed
end

local function sendWebhookAlert(message)
    local webhookUrl = DISCORD_WEBHOOK
    if type(webhookUrl) ~= "string" or webhookUrl == "" then
        warn("Discord webhook not configured.")
        return
    end

    if typeof(http_request) ~= "function" then
        warn("http_request function is not available in this environment.")
        return
    end

    local embedPayload
    if typeof(message) == "table" and message.__inventoryEmbed then
        embedPayload = {
            embeds = { buildInventoryEmbed(message) }
        }
    else
        embedPayload = {
            embeds = {
                {
                    description = tostring(message),
                    color = 0x2A3BFF
                }
            }
        }
    end

    local payload = HttpService:JSONEncode(embedPayload)

    task.spawn(function()
        local success, response = pcall(function()
            return http_request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = payload
            })
        end)

        if not success then
            warn("Failed to send webhook:", response)
            return
        end

        local statusCode = response and (response.StatusCode or response.Status or response.status_code)
        if statusCode and statusCode >= 200 and statusCode < 300 then
            print("Discord webhook sent successfully.")
            return
        end

        warn("Discord webhook returned unexpected response:", statusCode, response and (response.Body or response.body or response.StatusMessage))
    end)
end

local function checkVitalStats()
    if vitalsTriggered or scriptEncerrado then return end
    if verificarLobby() then return end

    local lowReasons = {}
    local stomach = getWorkspaceStatPercent("Stomach")
    local water = getWorkspaceStatPercent("Water")
    local blood = getWorkspaceStatPercent("Blood")

    if stomach and stomach < MIN_STOMACH then
        table.insert(lowReasons, string.format("Stomach %d%% < %d%%", stomach, MIN_STOMACH))
    end
    if water and water < MIN_WATER then
        table.insert(lowReasons, string.format("Water %d%% < %d%%", water, MIN_WATER))
    end
    if blood and blood < MIN_BLOOD then
        table.insert(lowReasons, string.format("Blood %d%% < %d%%", blood, MIN_BLOOD))
    end

    if #lowReasons == 0 then
        return
    end

    vitalsTriggered = true
    local message = "Player "..LocalPlayer.Name.." vital stats are low:\n- " .. table.concat(lowReasons, "\n- ")
    warn("[Vitals] "..message)
    mostrarPopupErro("Vital stats too low:\n"..table.concat(lowReasons, "\n"), 8)
    sendWebhookAlert(message)
    encerrarTudo()
    task.wait(5)
    startInfiniteExitClicks()
end

--------------------------------------------------------
-- 1. TIMEOUT CONFIG (SCRIPT LOADER)
--------------------------------------------------------
local url = "https://raw.githubusercontent.com/AroxYv5/Arox-Whitelist-System/refs/heads/main/Whitelist"

local cancelled = false
local scriptExecutado = false
local botaoSairEncontrado = false -- Flag para indicar que o botão de sair foi encontrado

local TimeoutGui = Instance.new("ScreenGui")
TimeoutGui.Name = "TimeoutGUI"
TimeoutGui.ResetOnSpawn = false
TimeoutGui.Parent = parentUi
TimeoutGui.Enabled = false -- Starts disabled

local TimeoutFrame = Instance.new("Frame", TimeoutGui)
TimeoutFrame.Size = UDim2.new(0, 300, 0, 80)
TimeoutFrame.Position = UDim2.new(0.5, -150, 0, 50)
TimeoutFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TimeoutFrame.BorderSizePixel = 0
Instance.new("UICorner", TimeoutFrame).CornerRadius = UDim.new(0, 10)

local TimeoutLabel = Instance.new("TextLabel", TimeoutFrame)
TimeoutLabel.Size = UDim2.new(1, -10, 1, -10)
TimeoutLabel.Position = UDim2.new(0, 5, 0, 5)
TimeoutLabel.BackgroundTransparency = 1
TimeoutLabel.TextColor3 = Color3.fromRGB(255,255,255)
TimeoutLabel.Font = Enum.Font.GothamBold
TimeoutLabel.TextScaled = true
TimeoutLabel.TextWrapped = true
TimeoutLabel.Text = "Waiting for exit button..."

-- Cancellation Listener
task.spawn(function()
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.RightControl then
            if not cancelled and not scriptExecutado then
                -- Cancels execution
            cancelled = true
                
                -- Destroys timeout GUI
            pcall(function()
                    local gui = parentUi:FindFirstChild("TimeoutGUI")
                    if gui then
                        gui:Destroy()
                    end
                    encerrarTudo()
                end)
                
                -- Shows cancellation popup
                mostrarPopupErro("Execution cancelled", 5)
                print("❌ Execution cancelled by user")
            end
        end
    end)
end)

-- Automatic Loop - Waits for exit button before counting
task.spawn(function()
    -- Checks lobby once before starting
    if verificarLobby() then
        cancelled = true
        print("⛔ Lobby detected at start. Waiting to leave lobby...")
        -- Doesn't show anything, just waits to leave lobby
        while verificarLobby() do
            task.wait(1)
        end
        -- When leaving lobby, destroys GUI and returns (doesn't execute script)
        pcall(function()
            local gui = parentUi:FindFirstChild("TimeoutGUI")
            if gui then
                gui:Destroy()
            end
        end)
        return
    end

    -- If not lobby, enables GUI and shows
    TimeoutGui.Enabled = true
    TimeoutLabel.Text = "Waiting for exit button..."
    
    -- WAITS FOR EXIT BUTTON TO APPEAR
    print("🔍 Waiting for exit button to appear...")
    local botaoEncontrado = false
    local tentativas = 0
    
    while not botaoEncontrado and not cancelled and not scriptExecutado do
        -- Checks lobby during wait
        if verificarLobby() then
            cancelled = true
            print("⛔ Lobby detected during wait. Waiting to leave lobby...")
            -- Hides GUI
            TimeoutGui.Enabled = false
            -- Doesn't show anything, just waits to leave lobby
            while verificarLobby() do
                task.wait(1)
            end
            -- When leaving lobby, destroys GUI and returns
            pcall(function()
                local gui = parentUi:FindFirstChild("TimeoutGUI")
                if gui then
                    gui:Destroy()
                end
            end)
            return
        end
        
        -- Checks if exit button exists
        if verificarBotaoSair() then
            botaoEncontrado = true
            botaoSairEncontrado = true -- Sinaliza que o botão foi encontrado
            print("✅ Exit button found! Verifying Title...")
            TimeoutLabel.Text = "Verifying Title..."
            task.wait(0.5)
            
            -- Title verification loop
            while true do
                local textoTitle = nil
                local sucesso, resultado = pcall(function()
                    return verificarTitleEasternLuminant()
                end)
                
                if sucesso then
                    textoTitle = resultado
                else
                    print("⚠️ Error verifying Title: " .. tostring(resultado))
                    textoTitle = nil
                end
                
                if textoTitle == "EASTERN LUMINANT" then
                    print("✅ Title is EASTERN LUMINANT! Starting countdown...")
                    TimeoutLabel.Text = "Button found! Starting..."
                    task.wait(0.5)
                    break
                elseif textoTitle == "THE ETREAN LUMINANT" then
                    print("⏳ Title is THE ETREAN LUMINANT. Waiting 1s and verifying again...")
                    TimeoutLabel.Text = "Waiting to load..."
                    task.wait(1)
                    -- Continues loop to verify again
                elseif textoTitle == "DUNGEON" then
                    print("🏰 Title is DUNGEON. Verifying DetainmentCore...")
                    TimeoutLabel.Text = "Verifying DetainmentCore..."
                    task.wait(0.5)
                    
                    local temDetainmentCore = false
                    local sucesso, resultado = pcall(function()
                        return verificarDetainmentCore()
                    end)
                    
                    if sucesso and resultado then
                        temDetainmentCore = true
                    end
                    
                    if temDetainmentCore then
                        print("✅ DetainmentCore found! Starting countdown...")
                        TimeoutLabel.Text = "Button found! Starting..."
                        task.wait(0.5)
                        break
                    else
                        print("❌ DetainmentCore not found in dungeon")
                        -- Stops everything
                        encerrarTudo()
                        -- Shows 10 second popup
                        mostrarPopupErro("AUTO TITUS slot must be in the correct dungeon", 10)
                        local message = "Player "..LocalPlayer.Name.." AUTO TITUS slot must be in the correct dungeon"
                        sendWebhookAlert(message)
                        
                        -- Keeps clicking exit button infinitely
                        task.wait(5)
                        task.spawn(function()
                            while true do
                                pcall(function()
                                    clickMenuLabel()
                                end)
                                task.wait(1)
                            end
                        end)
                        
                        -- Destroys timeout GUI
                        pcall(function()
                            local gui = parentUi:FindFirstChild("TimeoutGUI")
                            if gui then
                                gui:Destroy()
                            end
                        end)
                        return
                    end
                else
                    -- Not EASTERN LUMINANT nor THE ETREAN LUMINANT nor DUNGEON
                    print("❌ Title is not valid: " .. (textoTitle or "nil"))
                    -- Stops everything
                    encerrarTudo()
                    -- Shows 10 second popup
                    mostrarPopupErro("AUTO TITUS slot must be in Eastern Luminant", 10)
                    local message = "Player "..LocalPlayer.Name.." AUTO TITUS slot must be in Eastern Luminant"
                    sendWebhookAlert(message)
                    -- Keeps clicking exit button infinitely
                    task.wait(5)
                    task.spawn(function()
                        while true do
                            pcall(function()
                                clickMenuLabel()
                            end)
                            task.wait(1)
                        end
                    end)
                    
                    -- Destroys timeout GUI
                    pcall(function()
                        local gui = parentUi:FindFirstChild("TimeoutGUI")
                        if gui then
                            gui:Destroy()
                        end
                    end)
                    return
                end
            end
            
            -- If reached here, it's EASTERN LUMINANT, exits outer loop
            break
        end
        
        tentativas = tentativas + 1
        task.wait(1)
    end
    
    -- If cancelled or already executed, exits
    if cancelled or scriptExecutado then return end
    
    -- STARTS COUNTDOWN
    for i = TIMEOUT_AROX_EXECUTION, 1, -1 do
        if cancelled or scriptExecutado then return end
        
        -- Checks Lobby DURING countdown too
        if verificarLobby() then
            cancelled = true
            print("⛔ Lobby detected during countdown. Waiting to leave lobby...")
            -- Hides GUI
            TimeoutGui.Enabled = false
            -- Doesn't show anything, just waits to leave lobby
            while verificarLobby() do
                task.wait(1)
            end
            -- When leaving lobby, destroys GUI and returns
            pcall(function()
                local gui = parentUi:FindFirstChild("TimeoutGUI")
                if gui then
                    gui:Destroy()
                end
            end)
            return
        end

        TimeoutLabel.Text = "Executing in "..i.."s (RightCtrl to cancel)"
        task.wait(1)
    end

    if not cancelled and not scriptExecutado then
        TimeoutLabel.Text = "Injecting Script..."
        task.wait(0.4)
        task.spawn(function() loadstring(game:HttpGet(url))() end)
        scriptExecutado = true
        print("✅ Script executed! (Automatic)")
        task.wait(0.5)
        pcall(function()
            local gui = parentUi:FindFirstChild("TimeoutGUI")
            if gui then
                gui:Destroy()
            end
        end)
    end
end)

--------------------------------------------------------
-- GENERAL GUIS
--------------------------------------------------------
local StatusGui = Instance.new("ScreenGui")
StatusGui.Name = "StatusOverlay"
StatusGui.ResetOnSpawn = false
StatusGui.Parent = parentUi

--------------------------------------------------------
-- 2. PLAYER DETECTOR (RIGHT - INSERT)
--------------------------------------------------------
local DetectorFrame = Instance.new("Frame", StatusGui)
DetectorFrame.Size = UDim2.new(0, 200, 0, 60)
DetectorFrame.Position = UDim2.new(1, -220, 0, 90)
DetectorFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
DetectorFrame.BorderSizePixel = 0
DetectorFrame.Visible = false -- Starts hidden
Instance.new("UICorner", DetectorFrame).CornerRadius = UDim.new(0, 8)

local DetectorTitle = Instance.new("TextLabel", DetectorFrame)
DetectorTitle.Size = UDim2.new(1,0,0.4,0)
DetectorTitle.BackgroundTransparency = 1
DetectorTitle.Font = Enum.Font.GothamBold
DetectorTitle.TextColor3 = Color3.fromRGB(255,255,255)
DetectorTitle.TextSize = 12
DetectorTitle.Text = "[INSERT] Detector: OFF"

local DetectorInfo = Instance.new("TextLabel", DetectorFrame)
DetectorInfo.Size = UDim2.new(1,0,0.6,0)
DetectorInfo.Position = UDim2.new(0,0,0.4,0)
DetectorInfo.BackgroundTransparency = 1
DetectorInfo.Font = Enum.Font.GothamBold
DetectorInfo.TextColor3 = Color3.fromRGB(255, 120, 120)
DetectorInfo.TextSize = 13
DetectorInfo.TextWrapped = true
DetectorInfo.Text = "Safe"

local function updateDetectorGui(status, playerPerto, distancia)
    -- Updates visibility based on lobby
    local noLobby = verificarLobby()
    DetectorFrame.Visible = not noLobby
    
    if status then
        DetectorFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60) 
        DetectorTitle.Text = "[INSERT] Detector: ON"
    else
        DetectorFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
        DetectorTitle.Text = "[INSERT] Detector: OFF"
    end

    if playerPerto then
        DetectorInfo.Text = "⚠️ " .. playerPerto.Name .. "\n📏 " .. math.floor(distancia) .. "m"
        DetectorInfo.TextColor3 = Color3.fromRGB(255, 80, 80)
    else
        DetectorInfo.Text = "No one nearby (<"..DETECTOR_DISTANCE_LEAVE.."m)"
        DetectorInfo.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end
updateDetectorGui(detectorEnabled, nil, 0)

local detectorClicando = false
local detectorClickLoop = nil

task.spawn(function()
    while true do
        if scriptEncerrado then break end
        
        -- Checks lobby and updates visibility
        local noLobby = verificarLobby()
        DetectorFrame.Visible = not noLobby
        
        -- Doesn't work in lobby
        if not noLobby then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local closestDist = math.huge
                local closestPlayer = nil
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
                        if otherRoot then
                            local dist = (myRoot.Position - otherRoot.Position).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestPlayer = player
                            end
                        end
                    end
                end
                updateDetectorGui(detectorEnabled, closestPlayer, closestDist)
                
                -- If detected someone nearby and is enabled, starts infinite click loop
                if detectorEnabled and closestDist < DETECTOR_DISTANCE_LEAVE then
                    if not detectorClicando then
                        detectorClicando = true
                        -- Starts infinite click loop
                        detectorClickLoop = task.spawn(function()
                            while detectorClicando and not scriptEncerrado do
                                clickMenuLabel()
                                task.wait(1)
                            end
                        end)
                    end
                else
                    -- If no one nearby, stops click loop
                    if detectorClicando then
                        detectorClicando = false
                        if detectorClickLoop then
                            detectorClickLoop = nil
                        end
                    end
                end
            end
        else
            -- If in lobby, stops click loop if active
            if detectorClicando then
                detectorClicando = false
                if detectorClickLoop then
                    detectorClickLoop = nil
                end
            end
        end
        task.wait(0.5)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        detectorEnabled = not detectorEnabled
        -- If disabled, stops click loop
        if not detectorEnabled then
            detectorClicando = false
            if detectorClickLoop then
                detectorClickLoop = nil
            end
        end
        updateDetectorGui(detectorEnabled, nil, 0)
    end
end)

--------------------------------------------------------
-- 2.5. AUTO MOD DETECTOR (RIGHT - PAGE UP)
--------------------------------------------------------
local ModDetectorFrame = Instance.new("Frame", StatusGui)
ModDetectorFrame.Size = UDim2.new(0, 200, 0, 60)
ModDetectorFrame.Position = UDim2.new(1, -220, 0, 160)
ModDetectorFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
ModDetectorFrame.BorderSizePixel = 0
ModDetectorFrame.Visible = false -- Starts hidden
Instance.new("UICorner", ModDetectorFrame).CornerRadius = UDim.new(0, 8)

local ModDetectorTitle = Instance.new("TextLabel", ModDetectorFrame)
ModDetectorTitle.Size = UDim2.new(1,0,0.4,0)
ModDetectorTitle.BackgroundTransparency = 1
ModDetectorTitle.Font = Enum.Font.GothamBold
ModDetectorTitle.TextColor3 = Color3.fromRGB(255,255,255)
ModDetectorTitle.TextSize = 12
ModDetectorTitle.Text = "[PAGE UP] Auto Mod: OFF"

local ModDetectorInfo = Instance.new("TextLabel", ModDetectorFrame)
ModDetectorInfo.Size = UDim2.new(1,0,0.6,0)
ModDetectorInfo.Position = UDim2.new(0,0,0.4,0)
ModDetectorInfo.BackgroundTransparency = 1
ModDetectorInfo.Font = Enum.Font.GothamBold
ModDetectorInfo.TextColor3 = Color3.fromRGB(255, 120, 120)
ModDetectorInfo.TextSize = 13
ModDetectorInfo.TextWrapped = true
ModDetectorInfo.Text = "Safe"

local function updateModDetectorGui(status, moderadorDetectado)
    -- ALWAYS checks lobby first - never shows in lobby
    local noLobby = verificarLobby()
    
    -- If in lobby, always hides and returns immediately
    if noLobby then
        ModDetectorFrame.Visible = false
        return
    end
    
    -- If not in lobby, shows and updates state
    ModDetectorFrame.Visible = true
    
    if status then
        ModDetectorFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60) 
        ModDetectorTitle.Text = "[PAGE UP] Auto Mod: ON"
    else
        ModDetectorFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
        ModDetectorTitle.Text = "[PAGE UP] Auto Mod: OFF"
    end

    if moderadorDetectado then
        ModDetectorInfo.Text = "⚠️ Moderator: " .. moderadorDetectado.Name
        ModDetectorInfo.TextColor3 = Color3.fromRGB(255, 80, 80)
    else
        ModDetectorInfo.Text = "No moderators"
        ModDetectorInfo.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end
updateModDetectorGui(modDetectorEnabled, nil)

local modDetectorClicando = false
local modDetectorClickLoop = nil
local moderadoresAtuais = {}

-- Function to verify moderators
local function verificarModeradores()
    if scriptEncerrado or not modDetectorEnabled then return end
    
    local noLobby = verificarLobby()
    if noLobby then return end
    
    local moderadorDetectado = nil
    
    -- Checks all players
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            local success, rank = pcall(function()
                return Player:GetRankInGroup(5212858)
            end)
            
            if success and rank and rank > 0 then
                moderadorDetectado = Player
                -- If it's a new moderator, starts clicking
                if not moderadoresAtuais[Player.UserId] then
                    moderadoresAtuais[Player.UserId] = true
                    if not modDetectorClicando then
                        modDetectorClicando = true
                        -- Starts infinite click loop
                        modDetectorClickLoop = task.spawn(function()
                            while modDetectorClicando and not scriptEncerrado do
                                clickMenuLabel()
                                task.wait(1)
                            end
                        end)
                    end
                end
            end
        end
    end
    
    -- Removes moderators that left
    for userId, _ in pairs(moderadoresAtuais) do
        local aindaNoServidor = false
        for _, Player in pairs(Players:GetPlayers()) do
            if Player.UserId == userId then
                aindaNoServidor = true
                break
            end
        end
        if not aindaNoServidor then
            moderadoresAtuais[userId] = nil
        end
    end
    
    -- If no more moderators, stops clicking
    if not moderadorDetectado and modDetectorClicando then
        if next(moderadoresAtuais) == nil then
            modDetectorClicando = false
            if modDetectorClickLoop then
                modDetectorClickLoop = nil
            end
        end
    end
    
    -- Checks lobby again before updating GUI
    if not verificarLobby() then
        updateModDetectorGui(modDetectorEnabled, moderadorDetectado)
    else
        ModDetectorFrame.Visible = false
    end
end

-- Checks when a player joins
Players.PlayerAdded:Connect(function(Player)
    if scriptEncerrado or not modDetectorEnabled then return end
    task.wait(1) -- Waits a bit for player to load
    verificarModeradores()
end)

-- Checks when a player leaves
Players.PlayerRemoving:Connect(function(Player)
    if scriptEncerrado or not modDetectorEnabled then return end
    moderadoresAtuais[Player.UserId] = nil
    verificarModeradores()
end)

-- Loop to update visibility and verify periodically
task.spawn(function()
    while true do
        if scriptEncerrado then break end
        
        -- Checks lobby FIRST - more frequent check
        local noLobby = verificarLobby()
        
        -- If in lobby, ALWAYS hides GUI and doesn't execute anything
        if noLobby then
            ModDetectorFrame.Visible = false
            -- Stops click loop if active
            if modDetectorClicando then
                modDetectorClicando = false
                if modDetectorClickLoop then
                    modDetectorClickLoop = nil
                end
            end
            moderadoresAtuais = {}
            task.wait(1) -- Checks more frequently when in lobby
        else
            -- If not in lobby, checks lobby again before showing
            if not verificarLobby() then
                -- Verifies moderators periodically (backup in case events don't work)
                if modDetectorEnabled then
                    verificarModeradores()
                else
                    ModDetectorFrame.Visible = false
                end
            else
                -- If entered lobby during execution, hides
                ModDetectorFrame.Visible = false
            end
            task.wait(10) -- Checks every 10 seconds (backup only)
        end
    end
end)

-- Initial verification
task.spawn(function()
    task.wait(2) -- Waits for game to load
    verificarModeradores()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.PageUp then
        -- Only allows activation if not in lobby
        local noLobby = verificarLobby()
        if not noLobby then
            modDetectorEnabled = not modDetectorEnabled
            -- If disabled, stops click loop
            if not modDetectorEnabled then
                modDetectorClicando = false
                if modDetectorClickLoop then
                    modDetectorClickLoop = nil
                end
            end
            -- Checks lobby again before updating GUI
            if not verificarLobby() then
                updateModDetectorGui(modDetectorEnabled, nil)
            else
                ModDetectorFrame.Visible = false
            end
        else
            -- Ensures it's hidden if in lobby
            ModDetectorFrame.Visible = false
        end
    end
end)

--------------------------------------------------------
-- 2.6. VITALS MONITOR (RIGHT - PAGE DOWN)
--------------------------------------------------------
local VitalsFrame = Instance.new("Frame", StatusGui)
VitalsFrame.Size = UDim2.new(0, 200, 0, 60)
VitalsFrame.Position = UDim2.new(1, -220, 0, 230)
VitalsFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
VitalsFrame.BorderSizePixel = 0
VitalsFrame.Visible = false
Instance.new("UICorner", VitalsFrame).CornerRadius = UDim.new(0, 8)

local VitalsTitle = Instance.new("TextLabel", VitalsFrame)
VitalsTitle.Size = UDim2.new(1,0,0.4,0)
VitalsTitle.BackgroundTransparency = 1
VitalsTitle.Font = Enum.Font.GothamBold
VitalsTitle.TextColor3 = Color3.fromRGB(255,255,255)
VitalsTitle.TextSize = 12
VitalsTitle.Text = "[PG DN] Vitals: ON"

local VitalsInfo = Instance.new("TextLabel", VitalsFrame)
VitalsInfo.Size = UDim2.new(1,0,0.6,0)
VitalsInfo.Position = UDim2.new(0,0,0.4,0)
VitalsInfo.BackgroundTransparency = 1
VitalsInfo.Font = Enum.Font.GothamBold
VitalsInfo.TextColor3 = Color3.fromRGB(200,200,200)
VitalsInfo.TextSize = 11
VitalsInfo.Text = "Next check in 60s"

local function updateVitalsGui(nextRun)
    local noLobby = verificarLobby()
    VitalsFrame.Visible = not noLobby

    if vitalsMonitorEnabled then
        VitalsFrame.BackgroundColor3 = Color3.fromRGB(30,160,60)
        VitalsTitle.Text = "[PG DN] Vitals: ON"
        if nextRun then
            VitalsInfo.Text = string.format("Next check in %ds", nextRun)
        else
            VitalsInfo.Text = "Monitoring..."
        end
    else
        VitalsFrame.BackgroundColor3 = Color3.fromRGB(160,40,40)
        VitalsTitle.Text = "[PG DN] Vitals: OFF"
        VitalsInfo.Text = "Monitoring paused"
    end
end

task.spawn(function()
    local interval = 30
    local remaining = interval
    updateVitalsGui(remaining)
    while true do
        if scriptEncerrado then break end
        updateVitalsGui(remaining)
        if remaining <= 0 then
            if vitalsMonitorEnabled and not vitalsTriggered and not verificarLobby() then
                checkVitalStats()
            end
            remaining = interval
        end
        remaining -= 1
        if remaining < 0 then remaining = 0 end
        task.wait(1)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.PageDown then
        vitalsMonitorEnabled = not vitalsMonitorEnabled
        updateVitalsGui()
    end
end)

--------------------------------------------------------
-- 3. AUTO LEAVE BY TIME (LEFT - ALT GR)
--------------------------------------------------------
local LEAVE_TOGGLE_KEY = Enum.KeyCode.RightAlt

local LeaveFrame = Instance.new("Frame", StatusGui)
LeaveFrame.Size = UDim2.new(0, 200, 0, 40)
LeaveFrame.Position = UDim2.new(0, 20, 0, 90) 
LeaveFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
LeaveFrame.BorderSizePixel = 0
LeaveFrame.Visible = false -- Starts hidden
Instance.new("UICorner", LeaveFrame).CornerRadius = UDim.new(0, 8)

local LeaveLabel = Instance.new("TextLabel", LeaveFrame)
LeaveLabel.Size = UDim2.new(1, -10, 1, -10)
LeaveLabel.Position = UDim2.new(0, 5, 0, 5)
LeaveLabel.BackgroundTransparency = 1
LeaveLabel.Font = Enum.Font.GothamBold
LeaveLabel.TextScaled = true
LeaveLabel.TextWrapped = true
LeaveLabel.TextColor3 = Color3.fromRGB(255,255,255)
LeaveLabel.Text = "[ALT GR] Timer Leave: "..LEAVE_TIMER.."s"

local function updateLeaveGui()
    -- Updates visibility based on lobby
    local noLobby = verificarLobby()
    LeaveFrame.Visible = not noLobby
    
    if leaveTimerEnabled then
        if LEAVE_TIMER > 0 then
            LeaveFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
            LeaveLabel.Text = "[ALT GR] Timer Leave: "..LEAVE_TIMER.."s"
        else
            -- Timer reached 0, is clicking continuously
            LeaveFrame.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
            LeaveLabel.Text = "[ALT GR] Timer Leave: CLICKING..."
        end
    else
        LeaveFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        LeaveLabel.Text = "[ALT GR] Timer Leave: OFF"
    end
end
updateLeaveGui()

task.spawn(function()
    while true do
        if scriptEncerrado then break end
        
        -- Checks lobby and updates visibility
        local noLobby = verificarLobby()
        LeaveFrame.Visible = not noLobby
        
        if not noLobby and leaveTimerEnabled then
            if LEAVE_TIMER > 0 then
                LEAVE_TIMER = LEAVE_TIMER - 1
                updateLeaveGui()
            else
                -- Timer reached 0, keeps clicking continuously
                clickMenuLabel()
                updateLeaveGui() -- Updates to show it's clicking
            end
        end
        task.wait(1)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == LEAVE_TOGGLE_KEY then
        -- Only allows activation if not in lobby
        if not verificarLobby() then
            leaveTimerEnabled = not leaveTimerEnabled
            if leaveTimerEnabled then LEAVE_TIMER = 120 end
            updateLeaveGui()
        end
    end
end)

--------------------------------------------------------
-- 4. AUTO PRESS 1 (LEFT - END)
--------------------------------------------------------
local AutoFrame = Instance.new("Frame", StatusGui)
AutoFrame.Size = UDim2.new(0, 200, 0, 40)
AutoFrame.Position = UDim2.new(0, 20, 0, 140) 
AutoFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
AutoFrame.BorderSizePixel = 0
AutoFrame.Visible = false -- Starts hidden
Instance.new("UICorner", AutoFrame).CornerRadius = UDim.new(0, 8)

local AutoLabel = Instance.new("TextLabel", AutoFrame)
AutoLabel.Size = UDim2.new(1,0,1,0)
AutoLabel.BackgroundTransparency = 1
AutoLabel.Font = Enum.Font.GothamBold
AutoLabel.TextSize = 14
AutoLabel.TextColor3 = Color3.fromRGB(255,255,255)
AutoLabel.Text = "[END] AutoPress 1: OFF"

local function updateAutoGui()
    -- Updates visibility based on lobby
    local noLobby = verificarLobby()
    AutoFrame.Visible = not noLobby
    
    if autoEnabled then
        AutoFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60) 
        AutoLabel.Text = "[END] AutoPress 1: ON"
    else
        AutoFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
        AutoLabel.Text = "[END] AutoPress 1: OFF"
    end
end
updateAutoGui()

task.spawn(function()
    while true do
        if scriptEncerrado then break end
        
        -- Checks lobby and updates visibility
        local noLobby = verificarLobby()
        AutoFrame.Visible = not noLobby
        
        -- Doesn't work in lobby
        if not noLobby then
            if autoEnabled then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            end
            task.wait(AUTO_PRESS_INTERVAL) -- Wait AUTO_PRESS_INTERVAL between key presses when not in lobby
        else
            task.wait(0.5) -- Check more frequently when in lobby
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.End then
        -- Only allows activation if not in lobby
        if not verificarLobby() then
            autoEnabled = not autoEnabled
            updateAutoGui()
        end
    end
end)

--------------------------------------------------------
-- 5. AUTO QUICK JOIN (LEFT - HOME)
--------------------------------------------------------
local JoinFrame = Instance.new("Frame", StatusGui)
JoinFrame.Size = UDim2.new(0, 200, 0, 40)
JoinFrame.Position = UDim2.new(0, 20, 0, 190) 
JoinFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) 
JoinFrame.BorderSizePixel = 0
Instance.new("UICorner", JoinFrame).CornerRadius = UDim.new(0, 8)

local JoinLabel = Instance.new("TextLabel", JoinFrame)
JoinLabel.Size = UDim2.new(1,0,1,0)
JoinLabel.BackgroundTransparency = 1
JoinLabel.Font = Enum.Font.GothamBold
JoinLabel.TextSize = 14
JoinLabel.TextColor3 = Color3.fromRGB(255,255,255)
JoinLabel.Text = "[HOME] Auto Join: OFF"

local function updateJoinGui()
    if joinEnabled then
        JoinFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
        JoinLabel.Text = "[HOME] Auto Join: ON"
    else
        JoinFrame.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        JoinLabel.Text = "[HOME] Auto Join: OFF"
    end
end
updateJoinGui()

task.spawn(function()
    while true do
        if scriptEncerrado then break end
        if joinEnabled then
            local overlay = getOverlay()
            local options = overlay and overlay:FindFirstChild("Options")
            local btnContinue = options and options:FindFirstChild("Option")
            
            if btnContinue then
                simulateClick(btnContinue)
                task.wait(2)
            end
            
            -- Only checks AUTO TITUS if in lobby
            if joinEnabled and verificarLobby() then 
                local slotBtn, caminho = findElementByText("AUTO TITUS")
                if slotBtn then
                    print("Element found: " .. caminho)
                    print("Full path: " .. caminho)
                    local letraSlot = extrairLetraSlot(caminho)
                    if letraSlot then
                        print("Slot letter: " .. letraSlot)
                    end
                    
                    -- Gets Realm text
                    local textoRealm = pegarTextoRealm(slotBtn)
                    if textoRealm then
                        print("Realm text: " .. textoRealm)
                        
                        -- Checks if contains "Eastern Luminant"
                        if string.find(string.lower(textoRealm), string.lower("Eastern Luminant")) then
                    simulateClick(slotBtn)
                            task.wait(2.5)
                        else
                            print("❌ Does NOT contain 'Eastern Luminant'")
                            -- Stops everything
                            encerrarTudo()
                            mostrarPopupErro("AUTO TITUS slot must be in Eastern Luminant")
                            local message = "Player "..LocalPlayer.Name.." AUTO TITUS slot must be in Eastern Luminant"
                            sendWebhookAlert(message)
                            return -- Stops loop
                        end
                    else
                        print("Realm not found or has no text")
                        -- Stops everything
                        encerrarTudo()
                        mostrarPopupErro("AUTO TITUS slot must be in Eastern Luminant")
                        local message = "Player "..LocalPlayer.Name.." AUTO TITUS slot must be in Eastern Luminant"
                        sendWebhookAlert(message)
                        return -- Stops loop
                    end
                else
                    -- Didn't find AUTO TITUS
                    print("❌ Slot 'AUTO TITUS' not found")
                    encerrarTudo()
                    mostrarPopupErro("Slot named AUTO TITUS not found")
                    local message = "Player "..LocalPlayer.Name.." AUTO TITUS slot not found"
                    sendWebhookAlert(message)
                    return -- Stops loop
                end
            end

            if joinEnabled then
                local ov = getOverlay()
                local servFrame = ov and ov:FindFirstChild("ServerFrame")
                local jOpts = servFrame and servFrame:FindFirstChild("JoinOptions")
                local qJoin = jOpts and jOpts:FindFirstChild("QuickJoin")
                if qJoin then simulateClick(qJoin) end
            end
        end
        task.wait(10)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Home then
        joinEnabled = not joinEnabled
        updateJoinGui()
    end
end)

--------------------------------------------------------
-- 6. AUTOMATIC TELEPORT (WITH LOBBY PROTECTION)
--------------------------------------------------------
local DESTINO_TELEPORTE = Vector3.new(-6881, 336, 2829)
local ALCANCE_MAXIMO = 100
local VELOCIDADE_SLIDE = 50

local TeleportFrame = Instance.new("Frame", StatusGui)
TeleportFrame.Size = UDim2.new(0, 200, 0, 40)
TeleportFrame.Position = UDim2.new(0, 20, 0, 235) 
TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TeleportFrame.BorderSizePixel = 0
Instance.new("UICorner", TeleportFrame).CornerRadius = UDim.new(0, 8)

local TeleportLabel = Instance.new("TextLabel", TeleportFrame)
TeleportLabel.Size = UDim2.new(1, 0, 1, 0)
TeleportLabel.BackgroundTransparency = 1
TeleportLabel.Font = Enum.Font.GothamBold
TeleportLabel.TextSize = 13
TeleportLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportLabel.TextWrapped = true
TeleportLabel.Text = "Waiting for script..."
if verificarLobby() then
    TeleportLabel.Text = "Lobby detected. TP Cancelled."
    return
end

local function executarTeleporte()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then 
        TeleportLabel.Text = "Character not found"
        return 
    end
    
    local distancia = (rootPart.Position - DESTINO_TELEPORTE).Magnitude
    
    if distancia > ALCANCE_MAXIMO then
        -- Shows error popup
        mostrarPopupErro("Script must be executed near TITUS portal", 5)

        local message = "Player "..LocalPlayer.Name.." must be near TITUS portal"
        sendWebhookAlert(message)
        -- Stops everything and closes all GUIs
        encerrarTudo()
        
        -- Keeps clicking exit button infinitely
        task.spawn(function()
            while true do
                clickMenuLabel()
                task.wait(1)
            end
        end)
        
        return
    end
    
    TeleportLabel.Text = "Teleporting..."
    TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 100, 200)
    
    local tempo = distancia / VELOCIDADE_SLIDE
    local lesteLookAt = DESTINO_TELEPORTE + Vector3.new(100, 0, 0)
    local targetCFrame = CFrame.lookAt(DESTINO_TELEPORTE, lesteLookAt)
    
    local tweenInfo = TweenInfo.new(tempo, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    
    local noclipConnection
    noclipConnection = RunService.Stepped:Connect(function()
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
    
    tween:Play()
    
    tween.Completed:Connect(function()
        if noclipConnection then noclipConnection:Disconnect() end
        rootPart.Velocity = Vector3.new(0, 0, 0)
        TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
        TeleportLabel.Text = "Teleported successfully!"
        task.wait(3)
    end)
end

task.spawn(function()
    print("⏳ Waiting for script to execute...")
    while not scriptExecutado do
        task.wait(0.5)
    end
    
    print("✅ Script executed. Verifying environment...")
    TeleportLabel.Text = "Checking environment..."
    TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    task.wait(1)

    -- 1. CHECKS IF IN LOBBY
    if verificarLobby() then
        print("⚠️ Lobby detected. TP Cancelled.")
        TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
        TeleportLabel.Text = "Lobby detected. TP Cancelled."
        task.wait(4)
        return -- Cancels here
    end
    
    -- 2. CHECKS IF ALREADY AT LOCATION (DetainmentCore)
    if verificarDetainmentCore() then
        TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
        TeleportLabel.Text = "DetainmentCore detected. TP Cancelled."
        task.wait(4)
        return -- Cancels here
    end
    
    -- 3. STARTS COUNTDOWN
    TeleportFrame.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
    for i = WAIT_TIME_TELEPORT, 1, -1 do
        TeleportLabel.Text = "Teleporting in "..i.." seconds"
        TeleportFrame.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
        task.wait(1)
    end
    
    executarTeleporte()
end)

--------------------------------------------------------
-- 7. INVENTORY WEBHOOK (FOOD & RELICS)
--------------------------------------------------------
local function obterCategoriaItem(tool)
    if tool:FindFirstChild("Relic") then
        return "Relic"
    elseif tool:FindFirstChild("Food") then
        return "Food"
    elseif tool:FindFirstChild("Consumable") then
        return "Food"
    elseif tool:FindFirstChild("Item") then
        -- Verifica se é comida pelo nome ou atributos
        local nomeLower = tool.Name:lower()
        if nomeLower:find("food") or nomeLower:find("meal") or nomeLower:find("soup") or 
           nomeLower:find("bread") or nomeLower:find("meat") or nomeLower:find("fish") then
            return "Food"
        end
    end
    return nil
end

local function obterQuantity(tool)
    local quantityObj = tool:FindFirstChild("Quantity")
    if quantityObj and quantityObj:IsA("IntValue") then
        return quantityObj.Value
    end
    return 1 -- Se não tiver Quantity, assume 1
end

local function coletarFoodERelics()
    local foodItems = {}
    local relicItems = {}
    
    local function adicionarItem(tool)
        local categoria = obterCategoriaItem(tool)
        if not categoria then return end
        
        local nome = tool:GetAttribute("DisplayName") or tool.Name
        local chave = nome
        
        if categoria == "Food" then
            local quantidade = obterQuantity(tool)
            if foodItems[chave] then
                foodItems[chave].quantidade = foodItems[chave].quantidade + quantidade
            else
                foodItems[chave] = {nome = nome, quantidade = quantidade}
            end
        elseif categoria == "Relic" then
            local quantidade = obterQuantity(tool)
            if relicItems[chave] then
                relicItems[chave].quantidade = relicItems[chave].quantidade + quantidade
            else
                relicItems[chave] = {nome = nome, quantidade = quantidade}
            end
        end
    end
    
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                adicionarItem(tool)
            end
        end
    end
    
    local character = LocalPlayer.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                adicionarItem(tool)
            end
        end
    end
    
    return foodItems, relicItems
end

local function formatarListaInventario(foodItems, relicItems)
    local function appendSection(lines, header, items, emptyText)
        table.insert(lines, header)

        if next(items) then
            local keys = {}
            for key in pairs(items) do
                table.insert(keys, key)
            end

            table.sort(keys, function(a, b)
                return tostring(a):lower() < tostring(b):lower()
            end)

            for _, key in ipairs(keys) do
                local dados = items[key]
                table.insert(lines, string.format("- %s (x%d)", dados.nome, dados.quantidade))
            end
        else
            table.insert(lines, emptyText)
        end

        table.insert(lines, "")
    end

    local stomach = getWorkspaceStatPercent("Stomach")
    local water = getWorkspaceStatPercent("Water")
    local blood = getWorkspaceStatPercent("Blood")

    if not stomach or not water or not blood then
        return nil
    end

    local linhas = {}
    table.insert(linhas, string.format("**Player:** %s", LocalPlayer.Name))
    table.insert(linhas, "")

    appendSection(linhas, "**✨ Relics:**", relicItems, "- (nenhuma relíquia encontrada)")
    appendSection(linhas, "**🍎 Food:**", foodItems, "- (nenhuma comida encontrada)")

    table.insert(linhas, "**💚 Vital Stats:**")
    table.insert(linhas, string.format("- Stomach: %d%%", stomach))
    table.insert(linhas, string.format("- Water: %d%%", water))
    table.insert(linhas, string.format("- Blood: %d%%", blood))

    local description = table.concat(linhas, "\n")

    return {
        __inventoryEmbed = true,
        title = "LA-AROX V1",
        description = description
    }
end

local inventoryWebhookEnviado = false

task.spawn(function()
    -- Espera o personagem carregar
    repeat
        task.wait(1)
    until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    -- Espera o botão de sair ser encontrado antes de começar
    print("🔍 Waiting for exit button to be found before starting inventory check...")
    while not botaoSairEncontrado do
        if scriptEncerrado then return end
        task.wait(1)
    end
    
    print("🔍 Exit button found! Starting inventory check for Food & Relics...")
    
    while not inventoryWebhookEnviado do
        if scriptEncerrado then break end
        
        -- Verifica se não está no lobby
        if verificarLobby() then
            task.wait(5)
            continue
        end
        
        -- Verifica se tem DetainmentCore (se tiver, não envia)
        if verificarDetainmentCore() then
            print("✅ DetainmentCore detected. Skipping inventory webhook.")
            break
        end
        
        -- Verifica se as informações vitais estão disponíveis
        local stomach = getWorkspaceStatPercent("Stomach")
        local water = getWorkspaceStatPercent("Water")
        local blood = getWorkspaceStatPercent("Blood")
        
        if not stomach or not water or not blood then
            print("⏳ Waiting for vital stats to load (Stomach, Water, Blood)...")
            task.wait(5)
            continue
        end
        
        -- Coleta Food e Relics
        local foodItems, relicItems = coletarFoodERelics()
        
        -- Formata e envia (só será enviado se as informações vitais estiverem disponíveis)
        local mensagem = formatarListaInventario(foodItems, relicItems)
        if mensagem then
            print("📦 All data ready! Sending inventory webhook...")
            sendWebhookAlert(mensagem)
            inventoryWebhookEnviado = true
            print("✅ Inventory webhook sent successfully!")
            break
        else
            print("⏳ Waiting for all data to be available. Checking again in 5 seconds...")
        end
        
        task.wait(5)
    end
end)