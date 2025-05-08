// KSC Precision Landing Script (Trajectories Mod + Drag Prediction + Parachute/Engine Landing)
// Compatible with kOS 1.4+ with Trajectories mod installed

// === CONFIGURATION ===
SET kscLat TO -0.0972.
SET kscLon TO -74.5577.
SET kscAlt TO 70.0.
SET desiredPeAlt TO 25000.
SET lonMargin TO 1.5.
SET latMargin TO 0.2.

// === TRAJECTORIES MOD CHECK ===
IF NOT ADDONS:CONTAINS("TRAJECTORIES") {
    PRINT "ERROR: Trajectories mod not found. Aborting.".
    SHUTDOWN.
}
SET traj TO ADDONS:TRAJECTORIES.

// === SANITY CHECK ===
IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}

// === ORBITAL VALIDATION ===
WAIT UNTIL SHIP:BODY:NAME = "Kerbin" AND SHIP:ORBIT:PERIAPSISALTITUDE > 70000.
PRINT "Stable Kerbin orbit confirmed.".

// === PARACHUTE SCAN ===
LIST PARTS IN allParts.
SET chutes TO LIST().
FOR p IN allParts {
    IF p:NAME:CONTAINS("parachute") {
        chutes:ADD(p).
    }
}

// === DRAG MODEL FOR DESCENT ===
FUNCTION atmDensity {
    PARAMETER currentalt.
    RETURN 1.225 * (2.71828 ^ (-currentalt / 5000)).
}
SET dragCoefficient TO 0.75.
SET referenceArea TO 1.0.
SET beta TO SHIP:MASS / (dragCoefficient * referenceArea).

PRINT "Drag prediction (first-pass):".
FOR somealt IN RANGE(70000, 0, -5000) {
    SET rho TO atmDensity(somealt).
    SET decel TO (rho * VELOCITY:SURFACE:MAG ^ 2) / (2 * beta).
    PRINT "Alt: " + somealt + " | Decel: " + ROUND(decel, 2).
}

// === TRAJECTORY PREDICTION ===
SET impact TO traj:IMPACTPOS.
PRINT "Predicted landing Lat: " + ROUND(impact:LATITUDE, 4) + " Lon: " + ROUND(impact:LONGITUDE, 4).

IF ABS(impact:LATITUDE - kscLat) > latMargin OR ABS(impact:LONGITUDE - kscLon) > lonMargin {
    PRINT "Predicted landing too far from KSC. Aborting.".
    SHUTDOWN.
}

PRINT "Projected impact within target range. Proceeding with deorbit...".

// === DEORBIT PLANNING ===
SET mu TO SHIP:BODY:MU.
SET bodyRadius TO SHIP:BODY:RADIUS.
SET r1 TO SHIP:ORBIT:RADIUSAT(SHIP:POSITION).
SET r2 TO bodyRadius + desiredPeAlt.
SET v1 TO SQRT(mu * (2 / r1 - 1 / SHIP:ORBIT:SEMI_MAJOR_AXIS)).
SET v2 TO SQRT(mu * (2 / r1 - 1 / ((r1 + r2) / 2))).
SET requiredDV TO v1 - v2.

PRINT "Required deorbit \u0394v: " + ROUND(requiredDV, 2) + " m/s".
PRINT "Available \u0394v: " + ROUND(SHIP:AVAILABLEDELTAV, 2) + " m/s".

IF requiredDV > SHIP:AVAILABLEDELTAV {
    PRINT "ERROR: Insufficient delta-v for deorbit.".
    SHUTDOWN.
}

// === DEORBIT BURN ===
LOCK STEERING TO RETROGRADE.
WAIT UNTIL ETA:PERIAPSIS < 60.
PRINT "Performing deorbit burn...".
LOCK THROTTLE TO 0.5.
UNTIL SHIP:ORBIT:PERIAPSISALTITUDE <= desiredPeAlt {
    WAIT 0.2.
}
LOCK THROTTLE TO 0.
PRINT "Deorbit burn complete. New periapsis: " + ROUND(SHIP:ORBIT:PERIAPSISALTITUDE, 0) + " m".

// === ENTRY AND LANDING ===
WAIT UNTIL SHIP:ALTITUDE < 70000.
PRINT "Atmospheric entry detected.".

WAIT UNTIL SHIP:ALTITUDE < 10000 AND ABS(SHIP:GEOPOSITION:LAT - kscLat) < 0.5 AND ABS(SHIP:GEOPOSITION:LONGITUDE - kscLon) < 1.5.
PRINT "Approaching KSC region.".

IF chutes:LENGTH > 0 {
    PRINT "Parachutes detected. Deploying.".
    WHEN STAGE:HASPARACHUTES AND NOT STAGE:PARACHUTESDEPLOYED THEN {
        PRINT "Staging to deploy parachutes.".
        STAGE.
    }
    FOR p IN chutes {
        IF NOT p:DEPLOYED {
            SET p:DEPLOY TO TRUE.
        }
    }

    WAIT UNTIL SHIP:ALTITUDE < 200.
    LOCK STEERING TO UP + R(0,180,0).
    LOCK THROTTLE TO 0.25.
    UNTIL SHIP:VERTICALSPEED > -1 {
        WAIT 0.1.
    }
    LOCK THROTTLE TO 0.
    PRINT "Landed with parachute support.".

} ELSE {
    PRINT "No parachutes found. Proceeding with powered landing.".

    IF SHIP:MAXTHRUST = 0 AND STAGE:HASFUEL {
        PRINT "Staging to activate engines.".
        STAGE.
        WAIT 1.
    }

    LOCK STEERING TO UP + R(0,180,0).
    WAIT UNTIL SHIP:ALTITUDE < 2000.

    LOCK THROTTLE TO 0.5.
    UNTIL SHIP:VERTICALSPEED > -2 AND SHIP:ALTITUDE < 100 {
        SET throttleValue TO ABS(SHIP:VERTICALSPEED) / 15.
        IF throttleValue < 0.1 {
            SET throttleValue TO 0.1.
        } ELSE IF throttleValue > 0.8 {
            SET throttleValue TO 0.8.
        }
        LOCK THROTTLE TO throttleValue.
        WAIT 0.1.
    }
    LOCK THROTTLE TO 0.
    PRINT "Powered landing complete.".
}
