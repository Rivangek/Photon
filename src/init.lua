local Photon = {}
Photon.Particles = {}

--

local Libraries = script.Libraries
local Classes = script.Classes

local ParticleClass = require(Classes.Particle)

local RunService = game:GetService("RunService")
local InputService = game:GetService("UserInputService")

local Signal = require(Libraries.FastSignal)

--

if RunService:IsServer() then
    error("Photon is not meant to be run on the server!")
end

local Player = game.Players.LocalPlayer
local Camera = workspace.CurrentCamera

--

type InternalParticle = {
    Constructor: ParticleConstructor,
    Spawned: { any },
    LastSpawn: number,

    Update: (number) -> nil,
    Spawn: () -> nil,
}

export type ExportedParticle = {
    Collides: RBXScriptSignal,
    Spawned: RBXScriptSignal,

    Destroy: () -> nil,
}

export type PhotonEnum = {
    Emission: {
        Shape: {
            Sphere: string,
            Box: string
        },
        Style: {
            Uniform: string,
            Burst: string
        }
    },

    Physics: {
        CollisionType: {
            None: string,
            StopMotion: string,
            Physics: string
        },

        InteractType: {
            None: string,
            Collide: string,
            OnSpawn: string
        }
    },

    Spritesheet: {
        SpritesheetType: {
            None: string,
            Loop: string,
            OneShot: string
        }
    }
}

export type ParticleConstructor = ParticleClass.Constructor

--

function Photon:Create(...): ExportedParticle
    local Particle = setmetatable({}, ParticleClass)
    Particle:Initialize(...)

    table.insert(self.Particles, Particle)
    return Particle
end

function Photon:SetSettings()
    
end

function Photon:GetEnum(): PhotonEnum
    return {
        Physics = {
            CollisionType = {
                None = "None",
                StopMotion = "StopMotion",
                Physics = "Physics"
            },

            InteractType = {
                None = "None",
                Collide = "Collide",
                OnSpawn = "OnSpawn"
            }
        },

        Emission = {
            Shape = {
                Sphere = "Sphere",
                Box = "Box"
            },

            Style = {
                Uniform = "Uniform",
                Burst = "Burst"
            }
        },

        Spritesheet = {
            SpritesheetType = {
                None = "None",
                Loop = "Loop",
                OneShot = "OneShot"
            }
        }
    }
end

function Photon:Update(Delta: number)
    debug.profilebegin("Photon Update")

    for _, Particle: (InternalParticle & ExportedParticle) in pairs(self.Particles) do

        -- Spawn Particles

        task.spawn(function()
            if Particle.LastSpawn and not (os.clock() - Particle.LastSpawn >= Particle.Constructor.Emission.SpawnTime) then
                return;
            end

            Particle.LastSpawn = os.clock()

            if Particle.Constructor.Emission.Style == "Burst" then
                for i = 1, Particle.Constructor.Emission.Rate do
                    Particle:Spawn()
                end
            elseif Particle.Constructor.Emission.Style == "Uniform" then
                for i = 1, Particle.Constructor.Emission.Rate do
                    Particle:Spawn()
                    task.wait(Particle.Constructor.Emission.SpawnTime / Particle.Constructor.Emission.Rate)
                end
            end
        end)

        --

        Particle:Update(Delta)
    end

    debug.profileend()
end

--

return Photon