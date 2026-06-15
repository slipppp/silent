--[[
    SILENT AIM COM FOV + AUTO SHOOT PARA MOBILE
    - Silent Aim (mira invisível)
    - FOV configurável na tela
    - Auto Shoot automático
    - Toque na tela para atirar
    - Compatível com R6 e R15
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- ========== CONFIGURAÇÕES ==========
local settings = {
    -- Ativar/Desativar
    Enabled = true,
    
    -- Configurações do FOV (círculo na tela)
    FOVRadius = 150,             -- Raio do FOV em pixels
    FOVColor = Color3.new(1, 0, 0), -- Cor do FOV
    ShowFOV = true,              -- Mostrar círculo na tela
    Transparency = 0.85,         -- Transparência do FOV
    
    -- Configurações do Silent Aim
    AimRadius = 100,             -- Distância máxima em studs
    TargetPart = "Auto",         -- "Auto", "Head", "Torso", "HumanoidRootPart"
    Priority = "FOV",            -- "FOV" ou "Distance"
    VisibleCheck = true,         -- Só mira se estiver visível
    TeamCheck = true,            -- Verifica times
    
    -- Configurações do Auto Shoot (MOBILE)
    AutoShoot = true,            -- Atirar automaticamente
    ShootDelay = 0.12,           -- Delay entre tiros (segundos)
    ShootOnTouch = true,         -- Atirar ao tocar na tela (mobile)
    HoldToShoot = false,         -- Segurar para atirar (disparo contínuo)
    
    -- Debug
    ShowDebug = false,
}

-- ========== VARIÁVEIS ==========
local currentTarget = nil
local currentTargetPart = nil
local lastShootTime = 0
local fovCircle = nil
local isHolding = false
local shootingConnection = nil

-- Referências
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- ========== CRIAR FOV CIRCLE NA TELA ==========
local function createFOVCircle()
    if not settings.ShowFOV then return end
    
    -- Criar ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "SilentAimFOV"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    
    -- Círculo externo
    fovCircle = Instance.new("Frame")
    fovCircle.Name = "FOVCircle"
    fovCircle.Size = UDim2.new(0, settings.FOVRadius * 2, 0, settings.FOVRadius * 2)
    fovCircle.Position = UDim2.new(0.5, -settings.FOVRadius, 0.5, -settings.FOVRadius)
    fovCircle.BackgroundColor3 = settings.FOVColor
    fovCircle.BackgroundTransparency = settings.Transparency
    fovCircle.BorderSizePixel = 2
    fovCircle.BorderColor3 = settings.FOVColor
    fovCircle.ClipsDescendants = true
    fovCircle.Parent = gui
    
    -- Deixar redondo
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = fovCircle
    
    -- Texto "FOV"
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = "⚡ " .. settings.FOVRadius .. "px"
    text.TextColor3 = settings.FOVColor
    text.TextSize = 16
    text.Font = Enum.Font.GothomBold
    text.TextStrokeTransparency = 0.3
    text.Parent = fovCircle
    
    -- Texto "AUTO SHOOT" no canto
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(0, 100, 0, 30)
    statusText.Position = UDim2.new(0, 10, 1, -40)
    statusText.BackgroundTransparency = 0.5
    statusText.BackgroundColor3 = Color3.new(0, 0, 0)
    statusText.Text = "🔫 AUTO"
    statusText.TextColor3 = Color3.new(0, 1, 0)
    statusText.TextSize = 14
    statusText.Font = Enum.Font.GothomBold
    statusText.Parent = gui
    
    print("[Mobile] FOV Circle criado - Raio:", settings.FOVRadius)
end

-- ========== ATUALIZAR FOV ==========
local function updateFOV()
    if fovCircle and settings.ShowFOV then
        fovCircle.Size = UDim2.new(0, settings.FOVRadius * 2, 0, settings.FOVRadius * 2)
        fovCircle.Position = UDim2.new(0.5, -settings.FOVRadius, 0.5, -settings.FOVRadius)
        fovCircle.BackgroundTransparency = settings.Transparency
        
        local text = fovCircle:FindFirstChild("TextLabel")
        if text then
            text.Text = "⚡ " .. settings.FOVRadius .. "px"
        end
    end
end

-- ========== DETECTAR TIPO DE PERSONAGEM ==========
local function getCharacterType(char)
    if not char then return "Unknown" end
    if char:FindFirstChild("UpperTorso") and char:FindFirstChild("LowerTorso") then
        return "R15"
    elseif char:FindFirstChild("Torso") then
        return "R6"
    end
    return "Unknown"
end

-- ========== PEGAR PARTE DO CORPO ==========
local function getTargetPart(character)
    if not character then return nil end
    
    local charType = getCharacterType(character)
    
    if settings.TargetPart == "Head" then
        return character:FindFirstChild("Head")
    elseif settings.TargetPart == "HumanoidRootPart" then
        return character:FindFirstChild("HumanoidRootPart")
    elseif settings.TargetPart == "Torso" then
        if charType == "R15" then
            return character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso")
        else
            return character:FindFirstChild("Torso")
        end
    else -- Auto
        local head = character:FindFirstChild("Head")
        if head then return head end
        
        if charType == "R15" then
            local upperTorso = character:FindFirstChild("UpperTorso")
            if upperTorso then return upperTorso end
        else
            local torso = character:FindFirstChild("Torso")
            if torso then return torso end
        end
        
        return character:FindFirstChild("HumanoidRootPart")
    end
end

-- ========== CALCULAR DISTÂNCIA DO CENTRO DA TELA ==========
local function getDistanceFromCenter(part)
    if not part or not part.Parent then return math.huge end
    
    local vector, onScreen = camera:WorldToScreenPoint(part.Position)
    if not onScreen then return math.huge end
    
    local screenCenter = Vector2.new(mouse.ViewSizeX / 2, mouse.ViewSizeY / 2)
    local screenPos = Vector2.new(vector.X, vector.Y)
    
    return (screenPos - screenCenter).Magnitude
end

-- ========== VERIFICAR VISIBILIDADE ==========
local function canHitTarget(targetPart)
    if not targetPart or not targetPart.Parent then
        return false
    end
    
    if settings.VisibleCheck then
        local origin = camera.CFrame.Position
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {character}
        
        local raycastResult = workspace:Raycast(
            origin,
            (targetPart.Position - origin).Unit * settings.AimRadius,
            raycastParams
        )
        
        if raycastResult and not raycastResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
    end
    
    return true
end

-- ========== ENCONTRAR MELHOR ALVO (BASEADO NO FOV) ==========
local function findBestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local characterPos = character.HumanoidRootPart and character.HumanoidRootPart.Position
    
    if not characterPos then return nil end
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            
            -- Verificar time
            if settings.TeamCheck and player.Team and otherPlayer.Team then
                if player.Team == otherPlayer.Team then
                    goto continue
                end
            end
            
            local otherChar = otherPlayer.Character
            if otherChar then
                local otherHumanoid = otherChar:FindFirstChild("Humanoid")
                if otherHumanoid and otherHumanoid.Health > 0 then
                    
                    local targetPart = getTargetPart(otherChar)
                    if targetPart then
                        -- Verificar distância
                        local distance = (targetPart.Position - characterPos).Magnitude
                        if distance <= settings.AimRadius then
                            
                            -- Verificar se está dentro do FOV
                            local fovDistance = getDistanceFromCenter(targetPart)
                            
                            if fovDistance <= settings.FOVRadius then
                                if canHitTarget(targetPart) then
                                    local score
                                    if settings.Priority == "FOV" then
                                        score = fovDistance
                                    else
                                        score = distance
                                    end
                                    
                                    if score < bestScore then
                                        bestScore = score
                                        bestTarget = targetPart
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        ::continue::
    end
    
    return bestTarget
end

-- ========== SILENT AIM HOOK ==========
local originalRaycast = workspace.Raycast

workspace.Raycast = function(self, origin, direction, raycastParams)
    if settings.Enabled and currentTarget and currentTargetPart then
        local targetPos = currentTargetPart.Position
        local toTarget = targetPos - origin
        local distanceToTarget = (toTarget - direction.Unit * toTarget:Dot(direction.Unit)).Magnitude
        
        -- Se o tiro passar perto do alvo (dentro do raio de tolerância)
        if distanceToTarget <= 15 then
            local newDirection = (targetPos - origin).Unit
            local result = originalRaycast(self, origin, newDirection, raycastParams)
            
            if result and result.Instance:IsDescendantOf(currentTarget.Parent) then
                if settings.ShowDebug then
                    print("[SilentAim] Tiro redirecionado para:", currentTarget.Parent.Name)
                end
                return result
            end
        end
    end
    
    return originalRaycast(self, origin, direction, raycastParams)
end

-- ========== FUNÇÃO PARA ATIRAR ==========
local function shoot()
    if not settings.Enabled then return end
    if not currentTarget or not currentTarget.Parent then return end
    
    local targetHumanoid = currentTarget.Parent:FindFirstChild("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        currentTarget = nil
        currentTargetPart = nil
        return
    end
    
    local currentTime = tick()
    if currentTime - lastShootTime >= settings.ShootDelay then
        lastShootTime = currentTime
        
        -- Encontrar a ferramenta atual
        local tool = character:FindFirstChildWhichIsA("Tool")
        
        if tool then
            -- Método 1: Evento remoto
            local shootEvent = tool:FindFirstChild("ShootEvent") or 
                              tool:FindFirstChild("Fire") or
                              tool:FindFirstChild("Activate")
            
            if shootEvent then
                if shootEvent:IsA("RemoteEvent") then
                    shootEvent:FireServer(currentTarget.Position, currentTargetPart)
                elseif shootEvent:IsA("BindableEvent") then
                    shootEvent:Fire()
                end
            end
            
            -- Método 2: Simular clique do mouse (para ferramentas normais)
            local handle = tool:FindFirstChild("Handle")
            if handle then
                -- Efeito visual de tiro
                local muzzleFlash = Instance.new("Part")
                muzzleFlash.Size = Vector3.new(0.2, 0.2, 0.5)
                muzzleFlash.BrickColor = BrickColor.new("Bright yellow")
                muzzleFlash.Material = Enum.Material.Neon
                muzzleFlash.CFrame = handle.CFrame * CFrame.new(0, 0, -1.5)
                muzzleFlash.Parent = workspace
                game:GetService("Debris"):AddItem(muzzleFlash, 0.1)
                
                -- Som do tiro
                local shootSound = Instance.new("Sound")
                shootSound.SoundId = "rbxassetid://9120388458"
                shootSound.Volume = 0.3
                shootSound.Parent = handle
                shootSound:Play()
                game:GetService("Debris"):AddItem(shootSound, 1)
            end
            
            if settings.ShowDebug then
                print("[AutoShoot] Tiro disparado para:", currentTarget.Parent.Name)
            end
        end
    end
end

-- ========== LOOP DE SHOOT CONTÍNUO (HOLD TO SHOOT) ==========
local function startHoldShoot()
    if shootingConnection then return end
    shootingConnection = RunService.RenderStepped:Connect(function()
        if isHolding and settings.HoldToShoot then
            shoot()
        end
    end)
end

local function stopHoldShoot()
    if shootingConnection then
        shootingConnection:Disconnect()
        shootingConnection = nil
    end
end

-- ========== CONFIGURAR TOQUES DA TELA (MOBILE) ==========
local function setupMobileControls()
    if not settings.ShootOnTouch then return end
    
    -- Detectar toque na tela
    UserInputService.TouchTap:Connect(function(touch, processed)
        if processed then return end
        if not settings.AutoShoot then -- Se auto shoot estiver desligado, atira no toque
            shoot()
        end
    end)
    
    -- Segurar para atirar (disparo contínuo)
    if settings.HoldToShoot then
        UserInputService.TouchLongPress:Connect(function(touch, processed)
            if processed then return end
            isHolding = true
            startHoldShoot()
        end)
        
        UserInputService.InputEnded:Connect(function(input, processed)
            if input.UserInputType == Enum.UserInputType.Touch then
                isHolding = false
                stopHoldShoot()
            end
        end)
    end
    
    print("[Mobile] Controles mobile configurados")
end

-- ========== VERIFICAR SE ALVO MORREU ==========
local function checkTargetDeath()
    if currentTarget and currentTarget.Parent then
        local targetHumanoid = currentTarget.Parent:FindFirstChild("Humanoid")
        if not targetHumanoid or targetHumanoid.Health <= 0 then
            if settings.ShowDebug then
                print("[SilentAim] Alvo morto:", currentTarget.Parent.Name)
            end
            currentTarget = nil
            currentTargetPart = nil
            return true
        end
    elseif currentTarget then
        currentTarget = nil
        currentTargetPart = nil
        return true
    end
    
    return false
end

-- ========== LOOP PRINCIPAL ==========
RunService.RenderStepped:Connect(function()
    if not settings.Enabled then return end
    
    -- Verificar personagem
    if not character or not character.Parent then
        character = player.Character
        if character then
            humanoid = character:WaitForChild("Humanoid")
        end
        return
    end
    
    if humanoid and humanoid.Health > 0 then
        -- Verificar se alvo morreu
        checkTargetDeath()
        
        -- Procurar novo alvo
        if not currentTarget then
            local newTarget = findBestTarget()
            if newTarget then
                currentTarget = newTarget
                currentTargetPart = newTarget
                
                if settings.ShowDebug then
                    local charType = getCharacterType(currentTarget.Parent)
                    print("[SilentAim] Alvo travado:", currentTarget.Parent.Name, "- Tipo:", charType)
                end
            end
        end
        
        -- Auto Shoot (atirar automaticamente)
        if settings.AutoShoot and currentTarget then
            shoot()
        end
    end
end)

-- ========== EVENTOS ==========
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    currentTarget = nil
    currentTargetPart = nil
    lastShootTime = 0
    
    if settings.ShowDebug then
        local charType = getCharacterType(character)
        print("[Sistema] Personagem renasceu - Tipo:", charType)
    end
end)

-- ========== INICIALIZAR ==========
local function initialize()
    createFOVCircle()
    setupMobileControls()
    
    -- Mostrar status
    local charType = getCharacterType(character)
    print("═══════════════════════════════════════")
    print("   SILENT AIM + FOV + MOBILE")
    print("   ✅ Tipo:", charType)
    print("   ✅ FOV:", settings.FOVRadius .. "px")
    print("   ✅ Auto Shoot:", settings.AutoShoot)
    print("   ✅ Toque na tela:", settings.ShootOnTouch)
    print("   ✅ Hold to Shoot:", settings.HoldToShoot)
    print("═══════════════════════════════════════")
end

initialize()

-- ========== COMANDOS RÁPIDOS (DIGITE NO CHAT) ==========
-- [[
-- /fov 100 - muda o FOV para 100
-- /autoshoot on/off - liga/desliga auto shoot
-- /toggle - liga/desliga o silent aim
-- ]]

local function onChatMessage(message)
    local msg = message:lower()
    if msg:sub(1, 4) == "/fov" then
        local newRadius = tonumber(msg:sub(5))
        if newRadius and newRadius > 0 and newRadius <= 500 then
            settings.FOVRadius = newRadius
            updateFOV()
            print("[FOV] Raio alterado para:", newRadius)
        end
    elseif msg == "/autoshoot on" then
        settings.AutoShoot = true
        print("[AutoShoot] Ativado")
    elseif msg == "/autoshoot off" then
        settings.AutoShoot = false
        print("[AutoShoot] Desativado")
    elseif msg == "/toggle" then
        settings.Enabled = not settings.Enabled
        print("[SilentAim]", settings.Enabled and "Ativado" or "Desativado")
        if fovCircle then
            fovCircle.Visible = settings.Enabled
        end
    end
end

game:GetService("Players").LocalPlayer.Chatted:Connect(onChatMessage)
