// Auto-execute next maneuver node using Tsiolkovsky equation for burn time calculation
// SWITCH TO 0.
// LIST FILES.

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

// Execute burn
LOCK THROTTLE TO 1.
SET lastDeltaV TO nicenode:DELTAV:MAG.
SET dv0 to nicenode:DELTAV.

UNTIL nicenode:DELTAV:MAG < 0.1 {
    SET remainingDeltaV TO nicenode:DELTAV:MAG.

    // Gradually reduce throttle when remainingDeltaV < 10 or less than 10% of initial deltaV
    IF remainingDeltaV < 10 or remainingDeltaV < dv0:MAG * 0.1 {
        LOCK THROTTLE TO MAX(0.1, remainingDeltaV / 10).
    } ELSE {
        LOCK THROTTLE TO 1.
    }

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
