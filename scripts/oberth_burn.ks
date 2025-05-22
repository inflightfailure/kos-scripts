// oberth_burn.ks

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

SET PASSES_DONE TO 0.

// Wait for a maneuver node to exist
WAIT UNTIL hasNode.
SET MAN_NODE TO NEXTNODE.

// --- Step 1: Read maneuver node ---
SET DELTA_V_VECTOR TO MAN_NODE:DELTAV.
SET TOTAL_DV TO DELTA_V_VECTOR:MAG.
SET BURN_VECTOR TO DELTA_V_VECTOR:NORMALIZED.
PRINT "Loaded maneuver node Δv: " + ROUND(TOTAL_DV,1) + " m/s".

// Δv availability check
SET MAX_DV TO SHIP:DELTAV:VACUUM.

IF MAX_DV < TOTAL_DV {
    PRINT "ERROR: Required Δv (" + TOTAL_DV + ") exceeds vessel capability (" + MAX_DV + ").".
    WAIT 0.
}

// --- Engine ISP calculation ---
LIST ENGINES IN ship_engines.
SET totalThrust TO 0.
SET totalISPWeighted TO 0.

FOR eng IN ship_engines {
    IF eng:THRUSTLIMIT > 0 AND NOT eng:FLAMEOUT {
        SET totalThrust TO totalThrust + eng:MAXTHRUST.
        SET totalISPWeighted TO totalISPWeighted + (eng:ISP * eng:MAXTHRUST).
    }
}

IF totalThrust > 0 {
    SET isp_param TO totalISPWeighted / totalThrust.
} ELSE {
    PRINT "No active engines found. Aborting.".
    WAIT 0.
}

// --- Optimization function ---
DECLARE FUNCTION burn_utility {
    PARAMETER burn_dv.
    PARAMETER total_dv.
    PARAMETER isp_val.
    PARAMETER thrust_val.
    PARAMETER mass_val.
    PARAMETER mu_val.
    PARAMETER r_per_val.

    SET accel TO thrust_val / mass_val.
    SET burn_time TO burn_dv / accel.

    // Avoid 'a' as a variable name (reserved in kOS)
    SET semiMajor TO r_per_val.
    SET v_per TO SQRT(mu_val * (2 / r_per_val - 1 / semiMajor)).
    SET dwell_time TO (r_per_val / v_per) * 0.25.

    SET efficiency_score TO dwell_time / burn_time.
    IF efficiency_score > 1 { SET efficiency_score TO 1. }

    SET burn_count TO CEILING(total_dv / burn_dv).

    SET k1 TO 1.5.
    SET k2 TO 1.0.

    RETURN k1 * efficiency_score - k2 * burn_count.
}

// --- Auto-select best Δv per pass ---
SET burn_sizes_list TO LIST(10, 20, 30, 50, 80, 120, 200, 320, 520, 840).
SET best_score TO -99999.
SET best_burn TO 0.

SET MU TO BODY:MU.
SET R_PER TO BODY:RADIUS + SHIP:PERIAPSIS.
SET T TO SHIP:MAXTHRUST.
SET mass_val TO SHIP:MASS.

FOR b IN burn_sizes_list {
    SET score TO burn_utility(b, TOTAL_DV, isp_param, T, mass_val, MU, R_PER).
    PRINT "Δv " + b + ": score = " + score.
    IF score > best_score {
        SET best_score TO score.
        SET best_burn TO b.
    }
}

SET MAX_DV_PER_PASS TO best_burn.
SET PASS_COUNT TO CEILING(TOTAL_DV / MAX_DV_PER_PASS).
SET V_INITIAL TO SHIP:VELOCITY:ORBIT:MAG.
SET TARGET_V TO V_INITIAL + TOTAL_DV.

PRINT "Using optimized Δv per pass: " + MAX_DV_PER_PASS + " m/s over " + PASS_COUNT + " passes.".

// --- Wait to start burn loop so half the passes occur before the maneuver node time ---

// Estimate time per pass (very rough: periapsis period)
SET orbitPeriod TO SHIP:OBT:PERIOD.
SET timePerPass TO orbitPeriod. // Each pass is one orbit

SET halfPasses TO FLOOR(PASS_COUNT / 2).
SET totalTimeForHalfPasses TO halfPasses * timePerPass.

SET nodeTime TO MAN_NODE:TIME.
SET startTime TO nodeTime - totalTimeForHalfPasses.

// Only wait if the calculated start time is in the future
IF startTime > TIME:SECONDS {
    PRINT "Waiting to start burn sequence so half the passes occur before node time.".
    PRINT "Burns will start at UT: " + startTime + " (in " + ROUND((startTime - TIME:SECONDS)/60,1) + " min)".
    IF startTime - TIME:SECONDS > 60 {
        PRINT "Timewarping to one minute before burn sequence start.".
        KUNIVERSE:TIMEWARP:WARPTO(startTime - 15).
        WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
        WAIT 0.2.
    }
} ELSE {
    PRINT "Burn sequence should start immediately to maximize Oberth effect.".
}

DECLARE FUNCTION perform_periapsis_burns {
  PARAMETER totalDV.
  PARAMETER burnThrottle.
  PARAMETER numPasses.

  // Capture and delete initial node
    SET orignode TO NEXTNODE.
    SET burnVec TO orignode:DELTAV:NORMALIZED.
    SET originalDV TO orignode:DELTAV:MAG.
    SET remainingDV TO originalDV.
    REMOVE orignode.
    PRINT "Captured and deleted original maneuver node.".

  LOCK STEERING TO burnVec.
  WAIT 10.
  PRINT "Captured burn vector: " + burnVec.

  // Estimate per-pass delta-V
  SET segmentDV TO totalDV / numPasses.
  PRINT "Delta-V per pass: " + segmentDV.

  // Estimate ship acceleration
  SET acc TO SHIP:MAXTHRUST / SHIP:MASS.
  SET segmentTime TO segmentDV / acc.
  PRINT "Burn duration per pass: " + segmentTime.

  SET i TO 1.
  UNTIL i > numPasses OR remainingDV <= 0.1 {
    PRINT "=== Burn pass " + i + "/" + numPasses + " ===".
    SET periTime TO TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS.
    SET burnStart TO periTime - (segmentTime / 2).

    // Add a temporary dummy node to access its reference frame
    SET nodeTime TO burnStart. // Absolute UT time of the desired burn
    SET nodeUTOffset TO nodeTime - TIME:SECONDS. // Offset from NOW in seconds

    // Add dummy node
    SET dummy_node TO NODE(nodeUTOffset, 0, 0, 0).
    ADD dummy_node.
    WAIT 0.1.

    // SET pass_node TO NODE(nodeUTOffset, 0, 0, 0).
    // ADD pass_node.
    // WAIT 0.1.

    // Calculate future frame at burn time
    SET futurePos TO POSITIONAT(SHIP, burnStart).
    SET futureVel TO VELOCITYAT(SHIP, burnStart):ORBIT.

    SET progradeVec TO futureVel:NORMALIZED.
    SET normalVec TO VCRS(futurePos, futureVel):NORMALIZED.
    SET radialVec TO VCRS(normalVec, progradeVec):NORMALIZED.

    // Transform burnVec into orbital frame basis at burn time
    SET progradeDV TO VDOT(burnVec, progradeVec).
    SET normalDV TO VDOT(burnVec, normalVec).
    SET radialDV TO VDOT(burnVec, radialVec).

    REMOVE dummy_node. // Clean up dummy before adding the final node

    SET pass_node TO NODE(nodeUTOffset, progradeDV, normalDV, radialDV).
    ADD pass_node.

    WAIT UNTIL TIME:SECONDS >= burnStart - 2. // buffer

    PRINT "Warping to burn start: T+" + (burnStart - TIME:SECONDS) + "s".
    KUNIVERSE:TIMEWARP:WARPTO(burnStart - 0.5).
    WAIT UNTIL TIME:SECONDS >= burnStart.

    PRINT "Burning...".
    LOCK THROTTLE TO burnThrottle.
    WAIT segmentTime.

    SET remainingDV TO remainingDV - segmentDV.

    // Remove the node after the burn
    IF HASNODE {
        REMOVE NEXTNODE.
    }

    IF SHIP:OBT:ECCENTRICITY >= 1 {
        PRINT "Trajectory is now hyperbolic. Completing original maneuver burn.".
        UNTIL remainingDV <= 0.1 {
            LOCK THROTTLE TO burnThrottle.
            WAIT 0.1.
            IF SHIP:AVAILABLETHRUST = 0 AND THROTTLE > 0 {
                PRINT "No thrust detected. Staging...".
                STAGE.
                WAIT 1. // Give time for engines to activate
            }
        }
        LOCK THROTTLE TO 0.
        PRINT "Original maneuver burn complete.".
        BREAK.
    }

    LOCK THROTTLE TO 0.
    PRINT "Pass " + i + " complete.".

    // Wait to coast to next periapsis
    IF i < numPasses AND remainingDV > 0.1 {
        PRINT "Warping to next periapsis...".
        WAIT 2.
        SET periapsisTime TO TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS.
        KUNIVERSE:TIMEWARP:WARPTO(periapsisTime - 30).
        WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
        WAIT 1.
        LOCK STEERING TO burnVec.
        WAIT 10.
    }

    SET i TO i + 1.
  }

  UNLOCK STEERING.
  PRINT "All burn passes complete.".
}

perform_periapsis_burns(TOTAL_DV, 1, PASS_COUNT).

LOCK STEERING TO UP + R(0,90,0).
PRINT "Oberth transfer complete.".
