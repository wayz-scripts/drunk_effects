local QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject()

local cfg = ConfigDrift or {}

local MAX_KMH     = cfg.MaxSpeedKmh or 90.0
local DRIFT_CMD   = cfg.Command or "drift"
local LOOP_MS     = cfg.LoopMs or 50
local KMH_ON      = cfg.LowSpeedKmhOn or 18.0
local KMH_OFF     = cfg.LowSpeedKmhOff or 12.0
local PWR_BUMP    = cfg.LaunchPowerBump or 18.0
local TQ_BUMP     = cfg.LaunchTorqueBump or 1.08
local D_ON        = cfg.DriftKmhOn or 28.0
local D_OFF       = cfg.DriftKmhOff or 22.0
local THR_MIN     = cfg.ThrottleMin or 0.25
local STR_MIN     = cfg.SteerMin or 0.23
local PULSE_MS    = cfg.GripPulseMs or 120
local PULSE_COOL  = cfg.PulseCooldownMs or 90
local PRESET      = cfg.Preset or {}
local THR_EFF     = math.max(0.14, THR_MIN * 0.70)
local STR_EFF     = math.max(0.18, STR_MIN * 0.75)
local D_ON_EFF    = math.max(18.0, (D_ON or 28.0) - 4.0)
local PULSE_MS_EF = math.max(PULSE_MS, 160)
local PULSE_CD_EF = math.min(PULSE_COOL, 70)
local PULSE_MAX_MULT = cfg.PulseMaxMult or 0.92
local PULSE_MIN_MULT = cfg.PulseMinMult or 0.86
local driftOn     = false
local saved       = {}
local lastVeh     = 0
local pulseUntil  = 0
local nextPulseAt = 0
local reduceState = false
local baseTraction = {}
local tractionTweaked = {}

local function kmh(v) return GetEntitySpeed(v) * 3.6 end

local function isDriver()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local v = GetVehiclePedIsIn(ped, false)
    return GetPedInVehicleSeat(v, -1) == ped
end

local function currentVeh()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    return GetVehiclePedIsIn(ped, false)
end

local function getF(v, k) return GetVehicleHandlingFloat(v, "CHandlingData", k) end
local function setF(v, k, val) if val ~= nil then SetVehicleHandlingFloat(v, "CHandlingData", k, val + 0.0) end end

local function saveHandling(v)
    if saved[v] then return end
    saved[v] = {
        fInitialDragCoeff                = getF(v, "fInitialDragCoeff"),
        fInitialDriveMaxFlatVel          = getF(v, "fInitialDriveMaxFlatVel"),
        fInitialDriveForce               = getF(v, "fInitialDriveForce"),
        fDriveInertia                    = getF(v, "fDriveInertia"),
        fClutchChangeRateScaleUpShift    = getF(v, "fClutchChangeRateScaleUpShift"),
        fClutchChangeRateScaleDownShift  = getF(v, "fClutchChangeRateScaleDownShift"),
        fSteeringLock                    = getF(v, "fSteeringLock"),
        fBrakeForce                      = getF(v, "fBrakeForce"),
        fHandBrakeForce                  = getF(v, "fHandBrakeForce"),
        fTractionCurveMax                = getF(v, "fTractionCurveMax"),
        fTractionCurveMin                = getF(v, "fTractionCurveMin"),
        fTractionCurveLateral            = getF(v, "fTractionCurveLateral"),
        fLowSpeedTractionLossMult        = getF(v, "fLowSpeedTractionLossMult"),
        fTractionLossMult                = getF(v, "fTractionLossMult"),
        fDriveBiasFront                  = getF(v, "fDriveBiasFront"),
    }
end

local function applyPreset(v)
    setF(v, "fInitialDragCoeff",                PRESET.fInitialDragCoeff)
    setF(v, "fInitialDriveMaxFlatVel",          PRESET.fInitialDriveMaxFlatVel)
    setF(v, "fInitialDriveForce",               PRESET.fInitialDriveForce)
    setF(v, "fDriveInertia",                    PRESET.fDriveInertia)
    setF(v, "fClutchChangeRateScaleUpShift",    PRESET.fClutchChangeRateScaleUpShift)
    setF(v, "fClutchChangeRateScaleDownShift",  PRESET.fClutchChangeRateScaleDownShift)
    setF(v, "fSteeringLock",                    PRESET.fSteeringLock)
    setF(v, "fBrakeForce",                      PRESET.fBrakeForce)
    setF(v, "fHandBrakeForce",                  PRESET.fHandBrakeForce)
    setF(v, "fTractionCurveMax",                PRESET.fTractionCurveMax)
    setF(v, "fTractionCurveMin",                PRESET.fTractionCurveMin)
    setF(v, "fTractionCurveLateral",            PRESET.fTractionCurveLateral)
    setF(v, "fLowSpeedTractionLossMult",        PRESET.fLowSpeedTractionLossMult)
    setF(v, "fTractionLossMult",                PRESET.fTractionLossMult)
    setF(v, "fDriveBiasFront",                  PRESET.fDriveBiasFront)

    baseTraction[v] = {
        max = getF(v, "fTractionCurveMax"),
        min = getF(v, "fTractionCurveMin"),
    }
    tractionTweaked[v] = false
end

local function restoreHandling(v)
    local s = saved[v]; if not s then return end
    for k, val in pairs(s) do setF(v, k, val) end
    saved[v] = nil
    baseTraction[v] = nil
    tractionTweaked[v] = nil
end

local function powerBoost(v, enabled)
    if enabled then
        SetVehicleEnginePowerMultiplier(v, PWR_BUMP)
        if SetVehicleEngineTorqueMultiplier then SetVehicleEngineTorqueMultiplier(v, TQ_BUMP) end
    else
        SetVehicleEnginePowerMultiplier(v, 0.0)
        if SetVehicleEngineTorqueMultiplier then SetVehicleEngineTorqueMultiplier(v, 1.0) end
    end
end

local function setReduce(v, state)
    if reduceState == state then return end
    SetVehicleReduceGrip(v, state)
    reduceState = state
end

local function applyTractionPulse(v)
    if not baseTraction[v] then return end
    if tractionTweaked[v] then return end
    local b = baseTraction[v]
    setF(v, "fTractionCurveMax", b.max * PULSE_MAX_MULT)
    setF(v, "fTractionCurveMin", b.min * PULSE_MIN_MULT)
    tractionTweaked[v] = true
end

local function restoreTractionFromPreset(v)
    if not baseTraction[v] then return end
    if not tractionTweaked[v] then return end
    local b = baseTraction[v]
    setF(v, "fTractionCurveMax", b.max)
    setF(v, "fTractionCurveMin", b.min)
    tractionTweaked[v] = false
end

local function driftActive()
    return driftOn == true
end

local function applyEffectiveCap(v)
    if v == 0 then return end
    if driftActive() then
        local dCap = (type(MAX_KMH) == "number" and MAX_KMH) or 90.0
        SetVehicleMaxSpeed(v, dCap / 3.6)
    else
        SetVehicleMaxSpeed(v, 0.0)
    end
end

local function enableDrift(v)
    if v == 0 then return end
    saveHandling(v)
    applyPreset(v)
    driftOn = true
    pulseUntil, nextPulseAt = 0, 0
    setReduce(v, false)
    applyEffectiveCap(v)
end

local function disableDrift(v)
    if v ~= 0 then
        powerBoost(v, false)
        setReduce(v, false)
        restoreTractionFromPreset(v)
        restoreHandling(v)
        applyEffectiveCap(v)
    end
    driftOn = false
end

RegisterCommand(DRIFT_CMD, function()
    local v = currentVeh()
    if v == 0 or not isDriver() then
        return
    end

    if not driftOn then
        enableDrift(v)
        if QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify('Drift ON', 'success', 3000)
        end
    else
        disableDrift(v)
        if QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify('Drift OFF', 'error', 3000)
        end
    end
end, false)

pcall(function()
    TriggerEvent('chat:addSuggestion', '/' .. DRIFT_CMD, 'Alterna drift asistido.')
end)

CreateThread(function()
    while true do
        local v = currentVeh()
        if v ~= lastVeh then
            if lastVeh ~= 0 and not driftOn then restoreHandling(lastVeh) end
            lastVeh = v
            if driftOn and v ~= 0 and isDriver() then
                saveHandling(v); applyPreset(v); setReduce(v, false)
                pulseUntil, nextPulseAt = 0, 0
                applyEffectiveCap(v)
            end
        end

        if driftOn and v ~= 0 and isDriver() then
            if not saved[v] then
                saveHandling(v); applyPreset(v); setReduce(v, false)
                applyEffectiveCap(v)
            end

            local speed = kmh(v)
            local thr   = GetControlNormal(0, 71)
            local brk   = GetControlNormal(0, 72)
            local steer = GetControlNormal(0, 59)
            local now   = GetGameTimer()

            if speed <= KMH_ON and thr > 0.05 and brk < 0.2 then
                powerBoost(v, true)
            elseif speed >= KMH_OFF then
                powerBoost(v, false)
            end

            local steerAbs = math.abs(steer)
            local wantPulse = (speed >= D_ON_EFF) and (steerAbs >= STR_EFF) and (thr >= THR_EFF) and (brk < 0.2)
            if wantPulse and now >= nextPulseAt then
                pulseUntil  = now + PULSE_MS_EF
                nextPulseAt = now + PULSE_MS_EF + PULSE_CD_EF
            end

            if now < pulseUntil then
                setReduce(v, true)
                applyTractionPulse(v)
            else
                setReduce(v, false)
                restoreTractionFromPreset(v)
            end
        else
            if v ~= 0 and saved[v] and not driftOn then
                powerBoost(v, false)
                setReduce(v, false)
                restoreTractionFromPreset(v)
                restoreHandling(v)
                applyEffectiveCap(v)
            end
        end

        Wait(LOOP_MS)
    end
end)

CreateThread(function()
    while true do
        if lastVeh ~= 0 and not isDriver() then
            if not driftOn and saved[lastVeh] then
                setReduce(lastVeh, false)
                restoreTractionFromPreset(lastVeh)
                restoreHandling(lastVeh)
                applyEffectiveCap(lastVeh)
                lastVeh = 0
            end
        end
        Wait(400)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if lastVeh ~= 0 then
        powerBoost(lastVeh, false)
        setReduce(lastVeh, false)
        restoreTractionFromPreset(lastVeh)
        restoreHandling(lastVeh)
        SetVehicleMaxSpeed(lastVeh, 0.0)
    end
end)
