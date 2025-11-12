ConfigDrift = {
    Command = "drift",
    LoopMs  = 50,

    LowSpeedKmhOn  = 18.0,
    LowSpeedKmhOff = 12.0,
    LaunchPowerBump  = 18.0,
    LaunchTorqueBump = 1.08,

    DriftKmhOn   = 24.0,
    DriftKmhOff  = 18.0,
    ThrottleMin  = 0.18,
    SteerMin     = 0.18,
    GripPulseMs  = 160,
    PulseCooldownMs = 60,
    MaxSpeedKmh = 150.0,

    Preset = {
        fInitialDragCoeff                = 9.0,
        fInitialDriveMaxFlatVel          = 140.0,
        fInitialDriveForce               = 0.43,
        fDriveInertia                    = 1.00,
        fClutchChangeRateScaleUpShift    = 2.8,
        fClutchChangeRateScaleDownShift  = 2.4,

        fSteeringLock                    = 38.0,
        fBrakeForce                      = 1.05,
        fHandBrakeForce                  = 1.35,

        fTractionCurveMax                = 2.05,
        fTractionCurveMin                = 1.78,
        fTractionCurveLateral            = 17.0,
        fLowSpeedTractionLossMult        = 0.85,
        fTractionLossMult                = 1.22,
        fDriveBiasFront                  = 0.0,
    },
}
