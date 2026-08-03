--[[
    Projeto Delta - Script de Estudo (ESP + Aimbot + Trigger Bot + Silent Aim + GUI + Whitelist)
    Insert = mostra/esconde o menu.
    Master (na GUI) = liga/desliga tudo.
    Silent Aim: tiros sempre acertam o alvo (mesmo mirando para o lado).
]]

-- ==================== WHITELIST ====================
local WHITELIST = {
    Users = {
        "gustavopcgamer204",
        "gustavodelicia01",
        "peaky",   -- adicionado
    }
}

-- ==================== SERVIÇOS ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==================== VERIFICAÇÃO DE WHITELIST ====================
local function isWhitelisted(player)
    for _, entry in ipairs(WHITELIST.Users) do
        if type(entry) == "string" and player.Name == entry then
            return true
        elseif type(entry) == "number" and player.UserId == entry then
            return true
        end
    end
    return false
end

if not isWhitelisted(localPlayer) then
    local msg = Instance.new("Message", workspace)
    msg.Text = "Você não está na whitelist do Projeto Delta!"
    task.wait(3)
    msg:Destroy()
    return
end

-- ==================== CONFIGURAÇÕES ====================
local CONFIG = {
    ESP = {
        Enabled = true,
        MaxDistance = 1200,
        TeamCheck = false,
        SkeletonThickness = 2,
        ShowNames = true,
        FontSize = 10,
        Colors = {
            Enemy   = Color3.fromRGB(255, 0, 0),
            Ally    = Color3.fromRGB(0, 255, 0),
            Neutral = Color3.fromRGB(255, 255, 0),
            NPC     = Color3.fromRGB(255, 200, 0)
        }
    },
    Aimbot = {
        Enabled = true,
        AimPart = "Head",
        FOV = 150,
        Smoothness = 0.3,
        MaxDistance = 1000,
        TeamCheck = false,
        AimKey = Enum.UserInputType.MouseButton2
    },
    TriggerBot = {
        Enabled = false,
        FOV = 20,
        Delay = 0.15,
        MaxDistance = 1000,
        TeamCheck = false
    },
    SilentAim = {
        Enabled = true,
        FOV = 180,
        MaxDistance = 1000,
        TeamCheck = false,
        AimPart = "Head",
        AutoEnable = true
    }
}

-- ==================== ESTADO GLOBAL ====================
local scriptEnabled = true
local playerESP = {}
local npcESP = {}
local guiControls = {}
local mainGui = nil
local lastShotTime = 0

-- ==================== UTILITÁRIOS ====================
local function isValidTarget(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function getTargetColor(target)
    if typeof(target) == "Instance" then
        return CONFIG.ESP.Colors.NPC
    else
        if CONFIG.ESP.TeamCheck and target.Team == localPlayer.Team then
            return CONFIG.ESP.Colors.Ally
        else
            return CONFIG.ESP.Colors.Enemy
        end
    end
end

local function isInFov(worldPos, radius)
    local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
    if not onScreen then return false end
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    return (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude <= radius
end

-- ==================== MAPEAMENTO DO ESQUELETO ====================
local R15_CONNECTIONS = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

local R6_CONNECTIONS = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Left Arm", "LeftHand"},
    {"Torso", "Right Arm"}, {"Right Arm", "RightHand"},
    {"Torso", "Left Leg"}, {"Left Leg", "LeftFoot"},
    {"Torso", "Right Leg"}, {"Right Leg", "RightFoot"},
}

local function getPartPositions(character, rigType)
    local pos = {}
    local function tryAdd(name)
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then pos[name] = part.Position end
    end
    if rigType == Enum.HumanoidRigType.R15 then
        tryAdd("Head"); tryAdd("UpperTorso"); tryAdd("LowerTorso")
        tryAdd("LeftUpperArm"); tryAdd("LeftLowerArm"); tryAdd("LeftHand")
        tryAdd("RightUpperArm"); tryAdd("RightLowerArm"); tryAdd("RightHand")
        tryAdd("LeftUpperLeg"); tryAdd("LeftLowerLeg"); tryAdd("LeftFoot")
        tryAdd("RightUpperLeg"); tryAdd("RightLowerLeg"); tryAdd("RightFoot")
        return pos, R15_CONNECTIONS
    else
        tryAdd("Head"); tryAdd("Torso"); tryAdd("Left Arm"); tryAdd("Right Arm")
        tryAdd("Left Leg"); tryAdd("Right Leg")
        tryAdd("LeftHand"); tryAdd("RightHand"); tryAdd("LeftFoot"); tryAdd("RightFoot")
        return pos, R6_CONNECTIONS
    end
end

-- ==================== CRIAÇÃO E REMOÇÃO DE ESP ====================
local function createESP(character, displayName, color)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local rigType = humanoid.RigType
    local connections = (rigType == Enum.HumanoidRigType.R15) and R15_CONNECTIONS or R6_CONNECTIONS
    local lines = {}

    for _ = 1, #connections do
        local ok, line = pcall(function() return Drawing.new("Line") end)
        if ok and line then
            line.Visible = false
            line.Thickness = CONFIG.ESP.SkeletonThickness
            line.Color = color
            line.Transparency = 1
            table.insert(lines, line)
        end
    end

    local nameText = nil
    if CONFIG.ESP.ShowNames then
        local ok, text = pcall(function() return Drawing.new("Text") end)
        if ok and text then
            text.Visible = false
            text.Text = displayName
            text.Color = color
            text.Size = CONFIG.ESP.FontSize
            text.Center = true
            text.Outline = true
            text.Font = Drawing.Fonts.Monospace
            nameText = text
        end
    end

    return { Lines = lines, Text = nameText, Name = displayName, Color = color }
end

local function removeESP(target, storage)
    local data = storage[target]
    if data then
        for _, line in ipairs(data.Lines) do
            pcall(function() line:Remove() end)
        end
        if data.Text then
            pcall(function() data.Text:Remove() end)
        end
        storage[target] = nil
    end
end

local function clearAllESP()
    for k in pairs(playerESP) do removeESP(k, playerESP) end
    for k in pairs(npcESP) do removeESP(k, npcESP) end
    print("[Delta] Todos os ESPs foram limpos.")
end

-- ==================== ATUALIZAÇÃO DO ESP ====================
local function updateESPForTarget(character, data, colorOverride)
    if not character or not character.Parent then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    local rootPart = humanoid.RootPart or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not rootPart then return false end

    local myChar = localPlayer.Character
    if not myChar then return false end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end

    local dist = (rootPart.Position - myRoot.Position).Magnitude
    local visible = (dist <= CONFIG.ESP.MaxDistance)
    local color = colorOverride or data.Color

    local positions, connections = getPartPositions(character, humanoid.RigType)
    for i, conn in ipairs(connections) do
        local line = data.Lines[i]
        if line then
            if visible and positions[conn[1]] and positions[conn[2]] then
                local a, onA = camera:WorldToViewportPoint(positions[conn[1]])
                local b, onB = camera:WorldToViewportPoint(positions[conn[2]])
                if onA and onB then
                    line.From = Vector2.new(a.X, a.Y)
                    line.To   = Vector2.new(b.X, b.Y)
                    line.Color = color
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
    end

    if data.Text then
        local head = character:FindFirstChild("Head")
        if head and visible then
            local hp, onScreen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
            if onScreen then
                data.Text.Position = Vector2.new(hp.X, hp.Y)
                data.Text.Visible = true
            else
                data.Text.Visible = false
            end
        else
            data.Text.Visible = false
        end
    end

    return true
end

local function updateAllESP()
    local myChar = localPlayer.Character
    if not myChar then
        clearAllESP()
        return
    end
    if not myChar:FindFirstChild("HumanoidRootPart") then
        return
    end

    for player, data in pairs(playerESP) do
        local char = player.Character
        if char and isValidTarget(char) then
            if not updateESPForTarget(char, data, getTargetColor(player)) then
                removeESP(player, playerESP)
            end
        else
            removeESP(player, playerESP)
        end
    end

    for npc, data in pairs(npcESP) do
        if isValidTarget(npc) then
            if not updateESPForTarget(npc, data) then
                removeESP(npc, npcESP)
            end
        else
            removeESP(npc, npcESP)
        end
    end
end

-- ==================== DETECÇÃO DE NPCs ====================
local function isNPC(character)
    if not character:IsA("Model") then return false end
    if character.Name == "" or character.Name == "Model" then return false end
    if not character:FindFirstChildOfClass("Humanoid") then return false end
    if not (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("Head")) then
        return false
    end
    if character == localPlayer.Character then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == character then return false end
    end
    return true
end

local function tryAddNPC(model)
    if not isNPC(model) or npcESP[model] then return end
    local name = "[NPC] " .. model.Name
    local espData = createESP(model, name, CONFIG.ESP.Colors.NPC)
    if espData then
        npcESP[model] = espData
        print("[Delta] NPC adicionado: " .. name)
    end
end

workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
        tryAddNPC(desc)
    end
end)

workspace.DescendantRemoving:Connect(function(desc)
    if npcESP[desc] then
        removeESP(desc, npcESP)
        print("[Delta] NPC removido: " .. desc.Name)
    end
end)

for _, obj in ipairs(workspace:GetDescendants()) do
    tryAddNPC(obj)
end

-- ==================== AIMBOT ====================
local aimbotActive = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == CONFIG.Aimbot.AimKey then
        aimbotActive = true
    end
    if input.KeyCode == Enum.KeyCode.Insert then
        if mainGui then
            mainGui.Enabled = not mainGui.Enabled
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == CONFIG.Aimbot.AimKey then aimbotActive = false end
end)

local function getBestTarget()
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local best, bestDist = nil, math.huge
    local camPos = camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == localPlayer then continue end
        if not isValidTarget(plr.Character) then continue end
        if CONFIG.Aimbot.TeamCheck and plr.Team == localPlayer.Team then continue end

        local aimPart = nil
        if CONFIG.Aimbot.AimPart == "Head" then
            aimPart = plr.Character:FindFirstChild("Head")
        end
        if not aimPart then
            aimPart = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso")
        end
        if not aimPart then continue end

        local d = (aimPart.Position - camPos).Magnitude
        if d <= CONFIG.Aimbot.MaxDistance and isInFov(aimPart.Position, CONFIG.Aimbot.FOV) then
            if d < bestDist then
                bestDist = d
                best = plr
            end
        end
    end
    return best
end

local function runAimbot()
    if not scriptEnabled or not CONFIG.Aimbot.Enabled or not aimbotActive then return end
    local target = getBestTarget()
    if target and target.Character then
        local aimPart = nil
        if CONFIG.Aimbot.AimPart == "Head" then
            aimPart = target.Character:FindFirstChild("Head")
        end
        if not aimPart then
            aimPart = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso")
        end
        if aimPart then
            local dir = (aimPart.Position - camera.CFrame.Position).Unit
            local targetCF = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + dir)
            camera.CFrame = camera.CFrame:Lerp(targetCF, math.clamp(CONFIG.Aimbot.Smoothness, 0.001, 1))
        end
    end
end

-- ==================== TRIGGER BOT ====================
local function shoot()
    local character = localPlayer.Character
    if not character then return end
    local tool = character:FindFirstChildOfClass("Tool")
    if tool and tool:IsA("Tool") then
        tool:Activate()
        return
    end
    pcall(function()
        local inputService = game:GetService("VirtualInputManager")
        inputService:SendMouseButtonEvent(camera.ViewportSize.X/2, camera.ViewportSize.Y/2, 0, true, game, 1)
        task.wait(0.05)
        inputService:SendMouseButtonEvent(camera.ViewportSize.X/2, camera.ViewportSize.Y/2, 0, false, game, 1)
    end)
end

local function getTriggerTarget()
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local camPos = camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == localPlayer then continue end
        if not isValidTarget(plr.Character) then continue end
        if CONFIG.TriggerBot.TeamCheck and plr.Team == localPlayer.Team then continue end

        local aimPart = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso")
        if not aimPart then continue end

        local d = (aimPart.Position - camPos).Magnitude
        if d <= CONFIG.TriggerBot.MaxDistance and isInFov(aimPart.Position, CONFIG.TriggerBot.FOV) then
            return plr
        end
    end
    for npc, _ in pairs(npcESP) do
        if not isValidTarget(npc) then continue end
        local aimPart = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
        if not aimPart then continue end
        local d = (aimPart.Position - camPos).Magnitude
        if d <= CONFIG.TriggerBot.MaxDistance and isInFov(aimPart.Position, CONFIG.TriggerBot.FOV) then
            return npc
        end
    end
    return nil
end

local function runTriggerBot()
    if not scriptEnabled or not CONFIG.TriggerBot.Enabled then return end
    local now = tick()
    if now - lastShotTime < CONFIG.TriggerBot.Delay then return end
    local target = getTriggerTarget()
    if target then
        shoot()
        lastShotTime = now
        print("[Delta] Trigger disparado!")
    end
end

-- ==================== SILENT AIM (MAGIC BULLET) ====================
local function getSilentAimTarget()
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local best, bestDist = nil, math.huge
    local camPos = camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == localPlayer then continue end
        if not isValidTarget(plr.Character) then continue end
        if CONFIG.SilentAim.TeamCheck and plr.Team == localPlayer.Team then continue end

        local aimPart = nil
        if CONFIG.SilentAim.AimPart == "Head" then
            aimPart = plr.Character:FindFirstChild("Head")
        end
        if not aimPart then
            aimPart = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso")
        end
        if not aimPart then continue end

        local d = (aimPart.Position - camPos).Magnitude
        if d <= CONFIG.SilentAim.MaxDistance and isInFov(aimPart.Position, CONFIG.SilentAim.FOV) then
            if d < bestDist then
                bestDist = d
                best = aimPart
            end
        end
    end
    for npc, _ in pairs(npcESP) do
        if not isValidTarget(npc) then continue end
        local aimPart = npc:FindFirstChild(CONFIG.SilentAim.AimPart) or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
        if not aimPart then continue end
        local d = (aimPart.Position - camPos).Magnitude
        if d <= CONFIG.SilentAim.MaxDistance and isInFov(aimPart.Position, CONFIG.SilentAim.FOV) then
            if d < bestDist then
                bestDist = d
                best = aimPart
            end
        end
    end
    return best
end

local silentAimHooked = false
local function enableSilentAim()
    if silentAimHooked then return end
    silentAimHooked = true
    local function hookTool(tool)
        if tool:IsA("Tool") then
            local remote = tool:FindFirstChild("RemoteEvent") or tool:FindFirstChildOfClass("RemoteEvent")
            if remote and not remote:GetAttribute("DeltaHooked") then
                remote:SetAttribute("DeltaHooked", true)
                local oldFireServer = remote.FireServer
                remote.FireServer = function(self, ...)
                    if scriptEnabled and CONFIG.SilentAim.Enabled then
                        local targetPart = getSilentAimTarget()
                        if targetPart then
                            local args = {...}
                            if #args >= 1 and typeof(args[1]) == "Vector3" then
                                args[1] = targetPart.Position
                            elseif #args >= 1 and typeof(args[1]) == "CFrame" then
                                args[1] = CFrame.new(targetPart.Position)
                            end
                            print("[Delta] Silent Aim redirecionou para " .. targetPart.Name)
                            return oldFireServer(self, unpack(args))
                        end
                    end
                    return oldFireServer(self, ...)
                end
            end
        end
    end

    local char = localPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            hookTool(tool)
        end
    end
    localPlayer.CharacterAdded:Connect(function(newChar)
        newChar.ChildAdded:Connect(function(child)
            task.wait(0.2)
            hookTool(child)
        end)
        for _, tool in ipairs(newChar:GetChildren()) do
            hookTool(tool)
        end
    end)
    if char then
        char.ChildAdded:Connect(function(child)
            task.wait(0.2)
            hookTool(child)
        end)
    end
    print("[Delta] Silent Aim ativado.")
end

local function disableSilentAim()
    silentAimHooked = false
    print("[Delta] Silent Aim desativado (hooks mantidos, mas não redirecionam).")
end

local function updateSilentAimState()
    if CONFIG.SilentAim.AutoEnable then
        local shouldEnable = (CONFIG.Aimbot.Enabled and aimbotActive) or CONFIG.TriggerBot.Enabled
        if shouldEnable and not CONFIG.SilentAim.Enabled then
            CONFIG.SilentAim.Enabled = true
            if guiControls.silentCheck then
                guiControls.silentCheck.setState(true)
            end
        end
    end
end

-- ==================== GUI COM CHECKBOXES ====================
local function createCheckbox(parent, text, initialState, position, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.Position = position
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 20, 0, 20)
    box.Position = UDim2.new(0, 5, 0, 5)
    box.BackgroundColor3 = initialState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    box.Text = initialState and "✓" or ""
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.SourceSansBold
    box.TextSize = 14
    box.BorderSizePixel = 0
    box.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 1, 0)
    label.Position = UDim2.new(0, 30, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local state = initialState
    local function updateVisual()
        box.BackgroundColor3 = state and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        box.Text = state and "✓" or ""
    end

    box.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        callback(state)
    end)

    return {
        frame = frame,
        setState = function(newState)
            state = newState
            updateVisual()
        end
    }
end

local function createGUI()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("ProjetoDeltaGUI") then
        playerGui.ProjetoDeltaGUI:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ProjetoDeltaGUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = true

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, 240, 0, 270)
    main.Position = UDim2.new(0.5, -120, 0.1, 0)
    main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    main.BorderSizePixel = 0
    main.BackgroundTransparency = 0.2
    main.Active = true
    main.Draggable = true

    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "Projeto Delta"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16

    -- Checkbox ESP
    local espCheck = createCheckbox(main, "ESP Skeleton", CONFIG.ESP.Enabled, UDim2.new(0, 0, 0, 30), function(state)
        CONFIG.ESP.Enabled = state
        print("[Delta] ESP " .. (state and "ativado" or "desativado"))
        if state then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= localPlayer and plr.Character then
                    local esp = createESP(plr.Character, plr.Name, getTargetColor(plr))
                    if esp then playerESP[plr] = esp end
                end
            end
            for _, obj in ipairs(workspace:GetDescendants()) do tryAddNPC(obj) end
        else
            clearAllESP()
        end
    end)

    -- Checkbox Aimbot
    local aimCheck = createCheckbox(main, "Aimbot", CONFIG.Aimbot.Enabled, UDim2.new(0, 0, 0, 65), function(state)
        CONFIG.Aimbot.Enabled = state
        print("[Delta] Aimbot " .. (state and "ativado" or "desativado"))
        updateSilentAimState()
    end)

    -- Checkbox Trigger Bot
    local triggerCheck = createCheckbox(main, "Trigger Bot", CONFIG.TriggerBot.Enabled, UDim2.new(0, 0, 0, 100), function(state)
        CONFIG.TriggerBot.Enabled = state
        print("[Delta] Trigger Bot " .. (state and "ativado" or "desativado"))
        updateSilentAimState()
    end)

    -- Checkbox Silent Aim
    local silentCheck = createCheckbox(main, "Silent Aim", CONFIG.SilentAim.Enabled, UDim2.new(0, 0, 0, 135), function(state)
        CONFIG.SilentAim.Enabled = state
        print("[Delta] Silent Aim " .. (state and "ativado" or "desativado"))
        if state then
            enableSilentAim()
        else
            disableSilentAim()
        end
    end)

    -- Distância do ESP
    local distFrame = Instance.new("Frame", main)
    distFrame.Size = UDim2.new(1, 0, 0, 30)
    distFrame.Position = UDim2.new(0, 0, 0, 175)
    distFrame.BackgroundTransparency = 1

    local distLabel = Instance.new("TextLabel", distFrame)
    distLabel.Size = UDim2.new(0, 80, 1, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "Distância:"
    distLabel.TextColor3 = Color3.new(1, 1, 1)
    distLabel.Font = Enum.Font.SourceSansBold
    distLabel.TextSize = 14
    distLabel.TextXAlignment = Enum.TextXAlignment.Left

    local distInput = Instance.new("TextBox", distFrame)
    distInput.Size = UDim2.new(0, 60, 0, 24)
    distInput.Position = UDim2.new(0, 85, 0, 3)
    distInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    distInput.TextColor3 = Color3.new(1, 1, 1)
    distInput.Font = Enum.Font.SourceSans
    distInput.TextSize = 14
    distInput.Text = tostring(CONFIG.ESP.MaxDistance)
    distInput.PlaceholderText = "1200"

    local applyButton = Instance.new("TextButton", distFrame)
    applyButton.Size = UDim2.new(0, 50, 0, 24)
    applyButton.Position = UDim2.new(0, 150, 0, 3)
    applyButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    applyButton.Text = "Aplicar"
    applyButton.TextColor3 = Color3.new(1, 1, 1)
    applyButton.Font = Enum.Font.SourceSansBold
    applyButton.TextSize = 12

    applyButton.MouseButton1Click:Connect(function()
        local num = tonumber(distInput.Text)
        if num and num > 0 then
            CONFIG.ESP.MaxDistance = num
            print("[Delta] Distância do ESP alterada para: " .. num)
        else
            distInput.Text = tostring(CONFIG.ESP.MaxDistance)
        end
    end)

    -- Botão Master
    local masterFrame = Instance.new("Frame", main)
    masterFrame.Size = UDim2.new(1, 0, 0, 30)
    masterFrame.Position = UDim2.new(0, 0, 0, 215)
    masterFrame.BackgroundTransparency = 1

    local masterLabel = Instance.new("TextButton", masterFrame)
    masterLabel.Size = UDim2.new(1, 0, 1, 0)
    masterLabel.BackgroundTransparency = 1
    masterLabel.Text = "Master: " .. (scriptEnabled and "ON" or "OFF")
    masterLabel.TextColor3 = scriptEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    masterLabel.Font = Enum.Font.SourceSansBold
    masterLabel.TextSize = 14

    masterLabel.MouseButton1Click:Connect(function()
        scriptEnabled = not scriptEnabled
        masterLabel.Text = "Master: " .. (scriptEnabled and "ON" or "OFF")
        masterLabel.TextColor3 = scriptEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        print("[Delta] Script " .. (scriptEnabled and "ligado" or "desligado"))
        if not scriptEnabled then
            clearAllESP()
            aimbotActive = false
        else
            if CONFIG.ESP.Enabled then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= localPlayer and plr.Character then
                        local esp = createESP(plr.Character, plr.Name, getTargetColor(plr))
                        if esp then playerESP[plr] = esp end
                    end
                end
                for _, obj in ipairs(workspace:GetDescendants()) do tryAddNPC(obj) end
            end
        end
    end)

    gui.Parent = playerGui
    mainGui = gui
    guiControls.espCheck = espCheck
    guiControls.aimCheck = aimCheck
    guiControls.triggerCheck = triggerCheck
    guiControls.silentCheck = silentCheck
    guiControls.masterText = masterLabel
    guiControls.distInput = distInput

    if CONFIG.SilentAim.Enabled then
        enableSilentAim()
    end
end

-- ==================== INICIALIZAÇÃO ====================
local function onPlayerAdded(plr)
    if plr == localPlayer then return end
    local function onChar(char)
        local head = char:WaitForChild("Head", 5)
        if not head then return end
        if scriptEnabled and CONFIG.ESP.Enabled then
            local esp = createESP(char, plr.Name, getTargetColor(plr))
            if esp then playerESP[plr] = esp end
        end
    end
    if plr.Character then
        onChar(plr.Character)
    end
    plr.CharacterAdded:Connect(onChar)
end

for _, plr in ipairs(Players:GetPlayers()) do onPlayerAdded(plr) end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(plr) removeESP(plr, playerESP) end)

localPlayer.CharacterAdded:Connect(function(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    print("[Delta] Jogador local renasceu. Recriando ESP...")
    clearAllESP()
    if scriptEnabled and CONFIG.ESP.Enabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= localPlayer and plr.Character then
                local esp = createESP(plr.Character, plr.Name, getTargetColor(plr))
                if esp then playerESP[plr] = esp end
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do tryAddNPC(obj) end
    end
end)

createGUI()

-- ==================== LOOP PRINCIPAL ====================
RunService.Heartbeat:Connect(function()
    updateSilentAimState()
    if scriptEnabled and CONFIG.ESP.Enabled then updateAllESP() end
    runAimbot()
    runTriggerBot()
end)

print("[Projeto Delta] Carregado! Pressione INSERT para mostrar/esconder o menu.")