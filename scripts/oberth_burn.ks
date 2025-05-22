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
SET burn_sizes_list TO LIST(30, 50, 70, 90, 120).
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

  // Capture original burn vector before any burn
  SET thisnode TO MAN_NODE(TIME:SECONDS + VESSEL:ORBIT:PERIAPSIS:ETA, totalDV, 0, 0).
  SET burnVec TO thisnode:DIRECTION:VEC:NORMALIZED.
  LOCK STEERING TO burnVec.
  PRINT "Captured burn vector: " + burnVec.

  // Estimate per-pass delta-V
  SET segmentDV TO totalDV / numPasses.
  PRINT "Delta-V per pass: " + segmentDV.

  // Estimate ship acceleration
  SET acc TO SHIP:MAXTHRUST / SHIP:MASS.
  SET segmentTime TO segmentDV / acc.
  PRINT "Burn duration per pass: " + segmentTime.

  SET i TO 1.
  UNTIL i > numPasses {
    PRINT "=== Burn pass " + i + "/" + numPasses + " ===".
    SET periTime TO TIME:SECONDS + VESSEL:ORBIT:PERIAPSIS:ETA.
    SET burnStart TO periTime - (segmentTime / 2).
    WAIT UNTIL TIME:SECONDS >= burnStart - 2. // buffer

    PRINT "Warping to burn start: T+" + (burnStart - TIME:SECONDS) + "s".
    KUNIVERSE:TIMEWARP:WARPTO(burnStart - 0.5).
    WAIT UNTIL TIME:SECONDS >= burnStart.

    PRINT "Burning...".
    LOCK THROTTLE TO burnThrottle.
    WAIT segmentTime.
    LOCK THROTTLE TO 0.
    PRINT "Pass " + i + " complete.".

    // Wait to coast to next periapsis
    IF i < numPasses {
      PRINT "Coasting to next periapsis...".
      WAIT UNTIL VESSEL:ORBIT:PERIAPSIS:ETA > 5.
      WAIT UNTIL VESSEL:ORBIT:PERIAPSIS:ETA < 60.
    }
    SET i TO i + 1.
  }

  UNLOCK STEERING.
  PRINT "All burn passes complete.".
}

perform_periapsis_burns(MAX_DV, 1, PASS_COUNT).

// // --- Burn loop ---
// UNTIL PASSES_DONE >= PASS_COUNT OR SHIP:VELOCITY:ORBIT:MAG >= TARGET_V {

//     // Timewarp to just before periapsis
//     SET periapsisTime TO TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS.

//     IF periapsisTime - TIME:SECONDS > 30 {
//         PRINT "Warping to periapsis at UT: " + periapsisTime.
//         KUNIVERSE:TIMEWARP:WARPTO(periapsisTime - 30).
//         WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
//         WAIT 1.
//     }

//     PRINT "Pass " + (PASSES_DONE+1) + ": Steering to burn vector (not maneuver!).".
//     LOCK STEERING TO BURN_VECTOR.

//     SET CURRENT_V TO SHIP:VELOCITY:ORBIT:MAG.
//     SET TARGET_PASS_V TO MIN(CURRENT_V + MAX_DV_PER_PASS, TARGET_V).

//     // TODO: fix in case it takes too long for the steering to lock
//     PRINT "Waiting for periapsis...".
//     WAIT UNTIL SHIP:OBT:ETA:PERIAPSIS < 1.

//     PRINT "Burning to reach " + ROUND(TARGET_PASS_V,1) + " m/s.".
//     LOCK THROTTLE TO 1.

//     WAIT UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_PASS_V OR SHIP:ALTITUDE > SHIP:APOAPSIS - 1000.

//     LOCK THROTTLE TO 0.
//     PRINT "Pass " + PASSES_DONE + " complete.".

//     SET PASSES_DONE TO PASSES_DONE + 1.
//     SET mass_val TO SHIP:MASS.
//     WAIT 2.
// }

// // Clean up node
// IF NODE:EXISTS {
//     NODE:REMOVE.
//     PRINT "Maneuver node removed.".
// }

LOCK STEERING TO UP + R(0,90,0).
PRINT "Oberth transfer complete.".
