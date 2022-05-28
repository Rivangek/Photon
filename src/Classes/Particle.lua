local Particle = {}
Particle.__index = Particle

--

local Libraries = script.Parent.Parent.Libraries

local Signal = require(Libraries.FastSignal)
local Util = require(Libraries.Util)

local DefaultConstructor: Constructor = {
    Emission = {
        Rate = 5,
        Shape = "Sphere",
        Style = "Uniform",
        Directions = {
            Enum.NormalId.Top
        },
        SpawnTime = 1,
        Lifetime = NumberRange.new(0.5, 1),
    },

    Physics = {
        HitboxSize = Vector3.new(0.05, 0.05, 0.05),
        CollisionType = "None",
        CollisionGroup = "Default",
        InteractType = "None"
    },

    Billboard = {
        BillboardType = "Particle",
        Size = NumberSequence.new(1),
        Texture = "rbxassetid://1946917526",
        Color = Color3.new(1, 1, 1)
    },

    Motion = {
        Speed = NumberSequence.new(1),
        Velocity = Vector3.new(0, 0, 0),
        LocalVelocity = Vector3.new(0, 0, -40),
    },

    Trail = {
        Enabled = false,
        Color3 = Color3.fromRGB(255, 255, 255),
        Transparency = NumberSequence.new(0.5),
        Width = NumberSequence.new(0.5),
        Lifetime = 2
    },

    Spritesheet = {
        Rows = 0,
        Columns = 0,
        Framerate = 0,
        
        Type = "None",
    }
}

--

export type Constructor = {
    Emission: {
        Rate: number?, -- How many particles to spawn per second
        Shape: string?, -- Sphere or Box
        Style: string?, -- Burst or Uniform.
        Directions: { Enum.NormalId }?, -- Particle emission direction.
        Origin: BasePart,
        Lifetime: NumberRange?,
        SpawnTime: number?, -- How much particles are spawned per this time. Uniform will spawn this amount during the seconds.
    }?,

    Physics: {
        HitboxSize: Vector3?, -- Size of the collision hitbox.
        CollisionGroup: string?,
        CollisionType: string?,
        InteractType: string?,
    }?,

    Motion: {
        Speed: NumberSequence?, -- Speed of the particle.
        Velocity: Vector3?, -- Acceleration equivalent or LinearVelocity if InteractType is set to "OnSpawn"
        LocalVelocity: Vector3?, -- Velocity in Local Space from Origin.
        Spread: Vector3?,
    }?,

    Trail: {
        Enabled: boolean?,
        Color3: Color3?,
        Width: NumberSequence?,
        Texture: string?,
        Transparency: NumberSequence?,
        Lifetime: number?,
    }?,

    Billboard: {
        BillboardType: string?,
        Texture: string?, -- Texture of the billboard.
        Size: NumberSequence?, -- Size of the billboard.
        Color: Color3?, -- Color of the billboard.
        Transparency: number?, -- Transparency of the billboard.
        Rotation: number?, -- Rotation of the billboard.
        RotationSpeed: number?, -- Rotation speed of the billboard.
    }?,

    Spritesheet: {
        Columns: number?,
        Rows: number?,
        Framerate: number?,

        Type: string?,
    }?
}

--

function Particle:Initialize(Constructor: Constructor)
    for Actor, ActorValues in pairs(DefaultConstructor) do
        if not Constructor[Actor] then
            Constructor[Actor] = {}
        end

        for Key, Value in pairs(ActorValues) do
            if Constructor[Actor][Key] == nil then
                Constructor[Actor][Key] = Value
            end
        end
    end

    self.Constructor = Constructor

    self.ActiveParts = {}
    self.ComputedParts = {}

    self.Collides = Signal.new()
    self.Destroyed = Signal.new()
    self.Spawned = Signal.new()
end

function Particle:Spawn()
    local Origin = self.Constructor.Emission.Origin
    local Position = Origin.CFrame:PointToWorldSpace(Util:SquareUniformRandomPosition(Origin.Size))

    local Part = Instance.new("Part", workspace.Terrain)
    Part.Name = "Particle"
    Part.Size = self.Constructor.Physics.HitboxSize
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanQuery = false
    Part.Transparency = 1
    Part.CFrame = CFrame.new(Position)
    Part.CustomPhysicalProperties = PhysicalProperties.new(100, 0, 0, 0, 100)

    local NoCollisionConstraint = Instance.new("NoCollisionConstraint", Part)
    NoCollisionConstraint.Part0 = Part
    NoCollisionConstraint.Part1 = Origin

    if self.Constructor.Physics.InteractType == "None" then
        Part.CanTouch = false
    elseif self.Constructor.Physics.InteractType == "OnSpawn" then
        Part.CanCollide = true
        Part.Anchored = false
        Part.CanQuery = true
        Part.CanTouch = true

        local LocalVelocity = Origin.CFrame:VectorToWorldSpace(self.Constructor.Motion.LocalVelocity)
        local Spread = Origin.CFrame:VectorToWorldSpace(Util:SquareUniformRandomPosition(self.Constructor.Motion.Spread))

        Part.AssemblyLinearVelocity = self.Constructor.Motion.Velocity + LocalVelocity + Spread
    end

    -- Trail

    local Attachment0 = Instance.new("Attachment", Part)
    Attachment0.Position = Vector3.new(0, -0.05, 0)

    local Attachment1 = Instance.new("Attachment", Part)
    Attachment1.Position = Vector3.new(0, 0.05, 0)

    local Trail = Instance.new("Trail", Part)
    Trail.Attachment0 = Attachment0
    Trail.Attachment1 = Attachment1
    Trail.FaceCamera = true
    Trail.Enabled = self.Constructor.Trail.Enabled

    -- Billboard

    local Billboard: BillboardGui | ParticleEmitter;
    if self.Constructor.Billboard.BillboardType == "Particle" then
        local Particle = Instance.new("ParticleEmitter")
        Particle.Name = "Billboard"
        Particle.Speed = NumberRange.new(0)
        Particle.Lifetime = NumberRange.new(self.Constructor.Emission.Lifetime)
        Particle.Rate = 0
        Particle.Parent = Part
        Particle.LockedToPart = true

        Particle:Emit(1)
    elseif self.Constructor.Billboard.BillboardType == "BillboardGui" then
        local Size = Util:GetNumberSequenceValue(self.Constructor.Billboard.Size, 0)

        Billboard = Instance.new("BillboardGui", Part)
        Billboard.Adornee = Part
        Billboard.Size = UDim2.fromScale(Size, Size)
        Billboard.Name = "Billboard"

        local ImageLabel = Instance.new("ImageLabel")
        ImageLabel.BackgroundTransparency = 1
        ImageLabel.Image = self.Constructor.Billboard.Texture
        ImageLabel.Size = UDim2.new(1, 0, 1, 0)
        ImageLabel.Parent = Billboard
        ImageLabel.ScaleType = Enum.ScaleType.Fit
    end

    -- Programming

    local DefinedLifetime = Util:GetNumberRangeValue(self.Constructor.Emission.Lifetime)
    local RX, RY, RZ = Origin.CFrame:ToEulerAnglesXYZ()

    self.Spawned:Fire(Part)

    Part:SetAttribute("Spawned", os.clock())
    Part:SetAttribute("OriginAxis", Vector3.new(RX, RY, RZ))
    Part:SetAttribute("Spread", Util:SquareUniformRandomPosition(self.Constructor.Motion.Spread))
    Part:SetAttribute("Lifetime", DefinedLifetime)

    table.insert(self.ActiveParts, Part)

    -- Spritesheet

    task.spawn(function()
        if self.Constructor.Spritesheet.Type == "OneShot" then
            if Billboard:IsA("BillboardGui") then
                local ImageLabel = Billboard:WaitForChild("ImageLabel", 15)
                local TotalShots = self.Constructor.Spritesheet.Columns * self.Constructor.Spritesheet.Rows

                local RatioX = self.Constructor.Spritesheet.ImageSize.X / self.Constructor.Spritesheet.Columns
                local RatioY = self.Constructor.Spritesheet.ImageSize.Y / self.Constructor.Spritesheet.Rows

                ImageLabel.ImageRectSize = Vector2.new(RatioX, RatioY)

                for Y = 0, self.Constructor.Spritesheet.Rows - 1 do
                    for X = 0, self.Constructor.Spritesheet.Columns - 1 do
                        ImageLabel.ImageRectOffset = Vector2.new(RatioX * X, RatioY * Y)
                        task.wait(DefinedLifetime / TotalShots)
                    end
                end
            end             
        end
    end)
end

function Particle:Update(Delta: number)
    for i, Particle: BasePart in pairs(self.ActiveParts) do
        if Particle.Parent then
            local Origin: BasePart = self.Constructor.Emission.Origin

            local Lived = os.clock() - Particle:GetAttribute("Spawned")
            local Lifetime = Particle:GetAttribute("Lifetime")

            local ParticleAlpha = Lived / Lifetime

            if Lived < Lifetime then

                if Particle.Billboard:IsA("BillboardGui") then
                    local NewSize = Util:GetNumberSequenceValue(self.Constructor.Billboard.Size, ParticleAlpha)
                    local NewBrightness = Util:GetNumberSequenceValue(self.Constructor.Billboard.Brightness, ParticleAlpha)

                    Particle.Billboard.Brightness = NewBrightness
                    Particle.Billboard.Size = UDim2.fromScale(NewSize, NewSize)
                    Particle.Billboard.ImageLabel.ImageTransparency = Util:GetNumberSequenceValue(
                        self.Constructor.Billboard.Transparency, ParticleAlpha
                    )

                    if Particle:GetAttribute("LoopFinished") == nil then
                        Particle:SetAttribute("LoopFinished", true)
                    end

                    if Particle:GetAttribute("LoopFinished") then
                        Particle:SetAttribute("LoopFinished", false)

                        task.spawn(function()
                            if self.Constructor.Spritesheet.Type == "Loop" then
                                local ImageLabel = Particle.Billboard:WaitForChild("ImageLabel", 15)
                
                                local RatioX = self.Constructor.Spritesheet.ImageSize.X / self.Constructor.Spritesheet.Columns
                                local RatioY = self.Constructor.Spritesheet.ImageSize.Y / self.Constructor.Spritesheet.Rows
                
                                ImageLabel.ImageRectSize = Vector2.new(RatioX, RatioY)
                
                                for Y = 0, self.Constructor.Spritesheet.Rows - 1 do
                                    for X = 0, self.Constructor.Spritesheet.Columns - 1 do
                                        ImageLabel.ImageRectOffset = Vector2.new(RatioX * X, RatioY * Y)
                                        task.wait(1 / self.Constructor.Spritesheet.Framerate)
                                    end
                                end

                                Particle:SetAttribute("LoopFinished", true)
                            end           
                        end)
                    end
                end

                if self.Constructor.Physics.InteractType ~= "OnSpawn" and not Particle:GetAttribute("NoMotion") then
                    local Axis = CFrame.Angles(
                        Particle:GetAttribute("OriginAxis").X, 
                        Particle:GetAttribute("OriginAxis").Y,
                        Particle:GetAttribute("OriginAxis").Z
                    )
    
                    local Direction = self.Constructor.Emission.Directions[math.random(1, #self.Constructor.Emission.Directions)]
                    local Normal = Axis * (Vector3.fromNormalId(Direction) + (Particle:GetAttribute("Spread") / 20))
    
                    local Speed = Util:GetNumberSequenceValue(self.Constructor.Motion.Speed, ParticleAlpha) * Normal

                    Particle.CFrame += (Speed / 50) * Delta * 60
                end

                if self.Constructor.Physics.InteractType == "Collide" then
                    local OverlapParams = OverlapParams.new()
                    OverlapParams.FilterDescendantsInstances = { Origin, workspace.Terrain }

                    local IsColliding = workspace:GetPartsInPart(Particle, OverlapParams)
                    if #IsColliding > 0 then
                        if self.Constructor.Physics.CollisionType == "Physics" then
                            Particle.Anchored = false
                            Particle.CanCollide = true

                            Particle:SetAttribute("NoMotion", true)
                        elseif self.Constructor.Physics.CollisionType == "StopMotion" then
                            Particle:SetAttribute("NoMotion", true)
                        end

                        self.Collides:Fire(Particle)
                    end
                end
            elseif Lived >= Lifetime then
                Particle:Destroy()

                self.Destroyed:Fire(Particle)
                table.remove(self.ActiveParts, i)
            end
        end
    end
end

--

return Particle