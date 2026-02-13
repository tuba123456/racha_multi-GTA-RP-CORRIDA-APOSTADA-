local Tunnel = module("vrp","lib/Tunnel")
RachaC = {}
Tunnel.bindInterface("racha_multi", RachaC)

local active = false
local matchId = nil
local raceIndex = nil
local cfg = nil
local cp = 1
local smokeFx = {}

function RachaC.GetCoords()
  local ped = PlayerPedId()
  local c = GetEntityCoords(ped)
  return { x = c.x, y = c.y, z = c.z }
end

local function clearSmoke()
  for _, fx in pairs(smokeFx) do
    StopParticleFxLooped(fx, false)
  end
  smokeFx = {}
end

local function ensurePtfx(asset)
  RequestNamedPtfxAsset(asset)
  while not HasNamedPtfxAssetLoaded(asset) do
    Wait(10)
  end
end

local function createSmokeAt(pos, asset, fxName, scale, zOffset)
  UseParticleFxAssetNextCall(asset)
  local fx = StartParticleFxLoopedAtCoord(
    fxName,
    pos.x, pos.y, pos.z + (zOffset or 0.2),
    0.0, 0.0, 0.0,
    scale or 1.0,
    false, false, false, false
  )
  smokeFx[#smokeFx + 1] = fx
end

local function setCheckpointVisual()
  clearSmoke()
  local def = cfg.Races[raceIndex]
  if not def or not def.checkpoints or not def.checkpoints[cp] then return end

  local chk = def.checkpoints[cp]
  ensurePtfx(cfg.Smoke.asset)

  createSmokeAt(chk.left,  cfg.Smoke.asset, cfg.Smoke.fx, cfg.Smoke.scale, cfg.Smoke.zOffset)
  createSmokeAt(chk.right, cfg.Smoke.asset, cfg.Smoke.fx, cfg.Smoke.scale, cfg.Smoke.zOffset)

  -- ✅ GPS / rota marcada para o PRÓXIMO checkpoint
  SetNewWaypoint(chk.center.x + 0.0001, chk.center.y + 0.0001)
end

RegisterNetEvent("racha_multi:Start")
AddEventHandler("racha_multi:Start", function(_matchId, _raceIndex, _cfg)
  active = true
  matchId = _matchId
  raceIndex = _raceIndex
  cfg = _cfg
  cp = 1

  TriggerEvent("Notify", "verde", "[RACHA] Valendo! Passe na fumaça (checkpoints obrigatórios).", 10000)
  setCheckpointVisual()
end)

RegisterNetEvent("racha_multi:Stop")
AddEventHandler("racha_multi:Stop", function(_matchId)
  if matchId ~= _matchId then return end
  active = false
  matchId = nil
  raceIndex = nil
  cfg = nil
  cp = 1
  clearSmoke()
end)

CreateThread(function()
  while true do
    local wait = 250

    if active and cfg and raceIndex and matchId then
      wait = 80

      local ped = PlayerPedId()
      local coords = GetEntityCoords(ped)

      -- Saiu do carro / não é motorista => perde NA HORA
      if cfg.RequireVehicle then
        if not IsPedInAnyVehicle(ped) then
          if cfg.InstantForfeitOnLeave then
            TriggerServerEvent("racha_multi:Forfeit", matchId, "saiu do veículo")
            Wait(500)
          end
          goto continue
        end

        local veh = GetVehiclePedIsIn(ped,false)
        if cfg.RequireDriver and GetPedInVehicleSeat(veh,-1) ~= ped then
          if cfg.InstantForfeitOnLeave then
            TriggerServerEvent("racha_multi:Forfeit", matchId, "não está dirigindo")
            Wait(500)
          end
          goto continue
        end
      end

      local def = cfg.Races[raceIndex]
      if def and def.checkpoints and def.checkpoints[cp] then
        local center = def.checkpoints[cp].center
        local d = #(coords - vector3(center.x, center.y, center.z))

        -- perto do checkpoint = mais responsivo
        if d <= 40.0 then wait = 0 end

        if d <= (cfg.CheckpointRadius or 7.0) then
          TriggerServerEvent("racha_multi:Passed", matchId, cp)
          cp = cp + 1
          setCheckpointVisual()
          Wait(300)
        end
      end

      ::continue::
    end

    Wait(wait)
  end
end)
