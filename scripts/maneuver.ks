// Auto-execute next maneuver node using Tsiolkovsky equation for burn time calculation
// SWITCH TO 0.
// LIST FILES.
// RUN maneuver("pe", 80000).

// Accept optional parameters: "pe" or "ap" and a target value in meters
DECLARE PARAMETER mode IS "", targetValue IS 0.

// Use standard gravity (9.80665 m/s^2) for ISP-based delta-v calculations.
// ISP is defined relative to Earth/Kerbin gravity and does NOT vary by celestial body.
SET g0 TO 9.80665.

IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}

// Auto-copy to local storage if running from archive
IF VOLUME():NAME = "0" {
    SET scriptName TO "capture.ks".

    // Check if the file exists in local storage
    IF NOT VOLUME(1):EXISTS(scriptName) {
        COPYPATH("0:/" + scriptName, "1:/" + scriptName).
        PRINT "Copied '" + scriptName + "' to local storage.".
    } ELSE {
        PRINT "Script already present in local storage.".
    }
}

// Default targets (0 means ignore)
SET targetPeriapsis TO 0.
SET targetApoapsis TO 0.
SET burnAt TO "".
SET mode TO mode:TOLOWER().

IF mode = "pe" {
    SET targetPeriapsis TO targetValue.
    PRINT "Target periapsis set to " + targetValue + " meters.".
} ELSE IF mode = "ap" {
    SET targetApoapsis TO targetValue.
    PRINT "Target apoapsis set to " + targetValue + " meters.".
} ELSE {
    PRINT "No valid orbital target provided. Defaulting to maneuver delta-v completion.".
}

// Determine the opposing point and create a maneuver node
IF mode = "pe" OR mode = "ap" {
    LOCAL currentPeriapsis TO SHIP:ORBIT:PERIAPSIS.
    LOCAL currentApoapsis TO SHIP:ORBIT:APOAPSIS.
    LOCAL semiMajorAxis TO (currentPeriapsis + currentApoapsis + 2 * BODY:RADIUS) / 2.

    // Declare variables outside the IF block
    LOCAL nodeTime TO 0.
    LOCAL desiredAltitude TO 0.
    LOCAL nodePosition TO 0.
 
    IF mode = "pe" {
        // Place the node at apoapsis to lower periapsis
        SET nodeTime TO TIME:SECONDS + ETA:APOAPSIS.
        SET desiredAltitude TO targetPeriapsis.
    } ELSE {
        // Place the node at periapsis to raise apoapsis
        SET nodeTime TO TIME:SECONDS + ETA:PERIAPSIS.
        SET desiredAltitude TO targetApoapsis.
    }

    SET mu TO BODY:MU.

    IF mode = "pe" {
        SET burnAt TO "apoapsis".
        SET nodeTime TO TIME:SECONDS + ETA:APOAPSIS.
        SET r1 TO SHIP:ORBIT:APOAPSIS + BODY:RADIUS.
        SET r2 TO targetPeriapsis + BODY:RADIUS.
    } ELSE {
        SET burnAt TO "periapsis".
        SET nodeTime TO TIME:SECONDS + ETA:PERIAPSIS.
        SET r1 TO SHIP:ORBIT:PERIAPSIS + BODY:RADIUS.
        SET r2 TO targetApoapsis + BODY:RADIUS.
    }


    SET currentPeriapsis TO SHIP:ORBIT:PERIAPSIS + BODY:RADIUS.
    SET currentApoapsis TO SHIP:ORBIT:APOAPSIS + BODY:RADIUS.
    SET currentSMA TO (currentPeriapsis + currentApoapsis) / 2.
    // Semi-major axis of transfer orbit from r1 to r2
    SET transferSMA TO (r1 + r2) / 2.

    SET vCurrent TO SQRT(mu * (2 / r1 - 1 / currentSMA)).
    SET vTransfer TO SQRT(mu * (2 / r1 - 1 / transferSMA)).

    SET deltaV TO vTransfer - vCurrent.

    ADD NODE(nodeTime, 0, 0, deltaV).

    PRINT "Maneuver node created to adjust " + mode + " to " + desiredAltitude + " meters.".
}

// Wait for a maneuver node to exist
WAIT UNTIL hasNode.
SET nicenode TO NEXTNODE.

// Calculate delta-v required from the maneuver node
SET deltaV TO nicenode:DELTAV:MAG.

LIST ENGINES IN ship_engines.
SET totalThrust TO 0.
SET totalISPWeighted TO 0.

IF ship_engines:LENGTH > 0 {
    // Use main engines
    FOR eng IN ship_engines {
        IF eng:THRUSTLIMIT > 0 AND eng:FLAMEOUT = FALSE {
            SET totalThrust TO totalThrust + eng:MAXTHRUST.
            SET totalISPWeighted TO totalISPWeighted + (eng:ISP * eng:MAXTHRUST).
        }
    }
    SET isp TO totalISPWeighted / totalThrust.
    SET thrust TO totalThrust.
} ELSE {
    // Use RCS if no engines
    PRINT "No main engines found. Attempting RCS.".
    RCS ON.

    // Estimate RCS thrust
    SET rcsThrust TO 1.0. // A rough average total thrust for RCS clusters
    SET rcsISP TO 220. // Approximate ISP for hydrazine

    SET thrust TO rcsThrust.
    SET isp TO rcsISP.
}

// Initial mass before burn
SET m0 TO SHIP:MASS.

// Compute final mass using Tsiolkovsky equation
SET mf TO m0 / (constant:e() ^ (deltaV / (isp * g0))).

// Average mass during burn (approximate)
SET mAvg TO (m0 + mf) / 2.

// Average acceleration = Thrust / Average Mass
SET accel TO thrust / mAvg.

// Estimated burn time
SET burnTime TO deltaV / accel.

// Burn starts at T - half burn time
SET burnStartTime TO nicenode:TIME - (burnTime / 2).

// Timewarp to just before burn start
IF burnStartTime - time:seconds > 30 {
    kuniverse:timewarp:warpto(burnStartTime - 20). // Warp to 30 seconds before burn
    WAIT 1.
    WAIT UNTIL kuniverse:timewarp:rate = 1.
    WAIT 0.2. // Allow physics to stabilize
}

// Point to maneuver nicenode direction
LOCK STEERING TO nicenode:BURNVECTOR.
PRINT "Locking steering to maneuver node.".

// Wait until burn start time
// ETA is estimated time in seconds until maneuver node
WAIT UNTIL burnStartTime - time:seconds <= 1.
PRINT "Burning for " + ROUND(burnTime, 1) + " seconds.".

SET periTargetAlt TO targetPeriapsis.
SET apoTargetAlt TO targetApoapsis.
SET margin TO 20. // meters of tolerance

// Execute burn
LOCK THROTTLE TO 1.
SET lastDeltaV TO nicenode:DELTAV:MAG.
SET dv0 to nicenode:DELTAV.

UNTIL (nicenode:DELTAV:MAG < 0.1 OR
  (burnAt = "apoapsis" AND periTargetAlt > 0 AND SHIP:PATCHES:LENGTH > 1 AND SHIP:PATCHES[1]:PERIAPSIS >= periTargetAlt - margin) OR
  (burnAt = "periapsis" AND apoTargetAlt > 0 AND SHIP:PATCHES:LENGTH > 1 AND SHIP:PATCHES[1]:APOAPSIS >= apoTargetAlt - margin))
{
    IF SHIP:PATCHES:LENGTH > 1 {
        SET patch TO SHIP:PATCHES[1].
    } ELSE {
        SET patch TO SHIP:ORBIT.
    }

    SET remainingDeltaV TO nicenode:DELTAV:MAG.

    IF VDOT(dv0, nicenode:DELTAV) < 0 {
        PRINT "Node vector diverging. Terminating burn early.".
        LOCK THROTTLE TO 0.
        BREAK.
    }

    IF remainingDeltaV < 0.1 {
        PRINT "Finalizing burn, remaining Δv: " + ROUND(remainingDeltaV, 2).
        WAIT UNTIL VDOT(dv0, nicenode:DELTAV) < 0.5.
        BREAK.
    }

    SET lastDeltaV TO remainingDeltaV.
    WAIT 0.
}

LOCK THROTTLE TO 0.
REMOVE nicenode.
PRINT "Maneuver complete.".
