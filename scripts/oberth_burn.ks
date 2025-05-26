// oberth_burn.ks

IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}





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



DECLARE FUNCTION compute_max_safe_dv {
    PARAMETER burn_dv_limit.
    PARAMETER mu_val.
    PARAMETER r_per_val.
    PARAMETER v_per_vector.
    PARAMETER burn_dir_vector.
    PARAMETER dv_step.
    PARAMETER safe_periapsis.

    SET sim_dv TO 0.

    UNTIL sim_dv >= burn_dv_limit {
        SET scaled_burn TO burn_dir_vector * sim_dv.
        SET test_velocity_vector TO v_per_vector + scaled_burn.
        SET speed TO test_velocity_vector:MAG.
        SET energy TO (speed^2 / 2) - (mu_val / r_per_val).
        SET sma TO -mu_val / (2 * energy).
        SET ecc TO ABS(1 - (r_per_val * speed^2) / mu_val).
        SET peri TO sma * (1 - ecc).

        IF peri < safe_periapsis {
            BREAK.
        }

        SET sim_dv TO sim_dv + dv_step.
    }

    RETURN sim_dv.
}

// Wait for a maneuver node to exist
WAIT UNTIL hasNode.
SET man_node TO NEXTNODE.
REMOVE man_node.

SET PASSES_DONE TO 0.

// Read maneuver node ---
SET DELTA_V_VECTOR TO man_node:DELTAV.
SET TOTAL_DV TO DELTA_V_VECTOR:MAG.
SET BURN_VECTOR TO DELTA_V_VECTOR:NORMALIZED.
SET NODE_POS TO man_node:ORBIT:POSITION.
SET NODE_RADIUS TO NODE_POS:MAG.
SET NODE_VECTOR TO NODE_POS:NORMALIZED.
SET TRUE_ANOM TO NODE:ORBIT:TRUEANOMALY. //Angle from periapsis to current position
SET next_node_time TO SHIP:ORBIT:MEANANOMALYATEPOCH()

PRINT "Loaded maneuver node Δv: " + ROUND(TOTAL_DV,1) + " m/s".




SET accel to totalThrust / SHIP:MASS.
SET total_dv to man_node:DELTAV:MAG.
SET burn_time TO total_dv / accel.
SET node_time TO man_node:TIME.
SET burn_start_time to node_time - (burn_time / 2).


SET MU TO BODY:MU.
SET SAFE_PERI TO 75000.
SET DV_STEP TO 1.0.

SET PASSES_DONE TO 0.
SET V_INITIAL TO SHIP:VELOCITY:ORBIT:MAG.
SET TARGET_V TO V_INITIAL + TOTAL_DV.

IF burn_start_time - TIME:SECONDS > 30 {
    PRINT "Timewarping to burn sequence start.".
    KUNIVERSE:TIMEWARP:WARPTO(burn_start_time - 15).
    WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
    WAIT 0.2.
}

UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_V {

    // Recalculate current periapsis conditions
    SET R_PER TO BODY:RADIUS + SHIP:PERIAPSIS.
    SET V_PER TO SQRT(MU * (2 / R_PER - 1 / SHIP:ORBIT:SEMIMAJORAXIS)).

    // Compute safe Δv for this pass
    SET REMAINING_DV TO TARGET_V - SHIP:VELOCITY:ORBIT:MAG.
    SET MAX_PASS_DV TO compute_max_safe_dv(REMAINING_DV, MU, R_PER, V_PER, BURN_VECTOR, DV_STEP, SAFE_PERI).

    // Add a new maneuver node for this pass at the location of the original maneuver node
    SET node_time TO man_node:ETA.
    SET pass_node TO NODE(node_time, NODE_POS, MAX_PASS_DV).
    ADD pass_node.

    PRINT "Pass " + (PASSES_DONE+1) + ": Safe burn Δv = " + MAX_PASS_DV.
    SET TARGET_PASS_V TO SHIP:VELOCITY:ORBIT:MAG + MAX_PASS_DV.

    LOCK STEERING TO BURN_VECTOR.
    WAIT 20.
    LOCK THROTTLE TO 1.

    UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_PASS_V {
        IF SHIP:PERIAPSIS < SAFE_PERI {
            PRINT "ABORT: Periapsis dropped below " + SAFE_PERI.
            LOCK THROTTLE TO 0.
            WAIT 0.
        }
        WAIT 0.1.
    }

    LOCK THROTTLE TO 0.
    REMOVE pass_node.
    PRINT "Burn complete.".
    SET PASSES_DONE TO PASSES_DONE + 1.
    WAIT 2.

    UNTIL VDOT(SHIP:ORBIT:POSITION:NORMALIZED, NODE_VECTOR) > 0.999 {
        WAIT 0.5.
    }
    SET burn_start_time TO TIME:SECONDS.

}


// SET MU TO BODY:MU.
// SET R_PER TO BODY:RADIUS + SHIP:PERIAPSIS.
// SET V_PER TO SQRT(MU * (2 / R_PER - 1 / R_PER)).

// SET MAX_SAFE_DV TO compute_max_safe_dv(TOTAL_DV, MU, R_PER, V_PER, 1.0, 75000).

// PRINT "Maximum safe Δv without periapsis drop below 75km: " + MAX_SAFE_DV + " m/s".

// SET MAX_DV_PER_PASS TO MAX_SAFE_DV.
// SET PASS_COUNT TO CEILING(TOTAL_DV / MAX_DV_PER_PASS).
// SET V_INITIAL TO SHIP:VELOCITY:ORBIT:MAG.
// SET TARGET_V TO V_INITIAL + TOTAL_DV.

// PRINT "Using optimized Δv per pass: " + MAX_DV_PER_PASS + " m/s over " + PASS_COUNT + " passes.".

// // --- Wait to start burn loop so half the passes occur before the maneuver node time ---

// // Estimate time per pass (very rough: periapsis period)
// SET orbitPeriod TO SHIP:OBT:PERIOD.
// SET timePerPass TO orbitPeriod. // Each pass is one orbit

// SET halfPasses TO FLOOR(PASS_COUNT / 2).
// SET totalTimeForHalfPasses TO halfPasses * timePerPass.

// SET nodeTime TO man_node:TIME.
// SET startTime TO nodeTime - totalTimeForHalfPasses.

// // Only wait if the calculated start time is in the future
// IF startTime > TIME:SECONDS {
//     PRINT "Waiting to start burn sequence so half the passes occur before node time.".
//     PRINT "Burns will start at UT: " + startTime + " (in " + ROUND((startTime - TIME:SECONDS)/60,1) + " min)".
//     IF startTime - TIME:SECONDS > 60 {
//         PRINT "Timewarping to one minute before burn sequence start.".
//         KUNIVERSE:TIMEWARP:WARPTO(startTime - 15).
//         WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
//         WAIT 0.2.
//     }
// } ELSE {
//     PRINT "Burn sequence should start immediately to maximize Oberth effect.".
// }

// DECLARE FUNCTION perform_periapsis_burns {
//   PARAMETER totalDV.
//   PARAMETER burnThrottle.
//   PARAMETER numPasses.

//   // Capture and delete initial node
//     SET orignode TO NEXTNODE.
//     SET burnVec TO orignode:DELTAV:NORMALIZED.
//     SET originalDV TO orignode:DELTAV:MAG.
//     SET remainingDV TO originalDV.
//     REMOVE orignode.
//     PRINT "Captured and deleted original maneuver node.".

//   LOCK STEERING TO burnVec.
//   WAIT 20.
//   PRINT "Captured burn vector: " + burnVec.

//   // Estimate per-pass delta-V
//   SET segmentDV TO totalDV / numPasses.
//   PRINT "Delta-V per pass: " + segmentDV.

//   // Estimate ship acceleration
//   SET acc TO SHIP:MAXTHRUST / SHIP:MASS.
//   SET segmentTime TO segmentDV / acc.
//   PRINT "Burn duration per pass: " + segmentTime.

//   SET i TO 1.
//   UNTIL i > numPasses OR remainingDV <= 0.1 {
//     PRINT "=== Burn pass " + i + "/" + numPasses + " ===".
//     SET periTime TO TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS.
//     SET burnStart TO periTime - (segmentTime / 2).

//     PRINT "Warping to burn start: T+" + (burnStart - TIME:SECONDS) + "s".
//     KUNIVERSE:TIMEWARP:WARPTO(burnStart - 0.5).
//     WAIT UNTIL TIME:SECONDS >= burnStart.

//     PRINT "Burning...".
//     LOCK THROTTLE TO burnThrottle.
//     WAIT segmentTime.

//     SET remainingDV TO remainingDV - segmentDV.

//     IF SHIP:OBT:ECCENTRICITY >= 1 {
//         // === Timewarp to SOI Transition ===
//         PRINT "Timewarping to SOI exit...".
//         SET currentBody TO BODY.

//         // Estimate SOI transition time
//         SET soiExitTime TO SHIP:OBT:NEXTPATCHETA.

//         // Warp to ~30s before SOI transition to avoid overshoot
//         KUNIVERSE:TIMEWARP:WARPTO(soiExitTime - 30).
//         WAIT UNTIL TIME:SECONDS >= soiExitTime - 30.

//         PRINT "Waiting for SOI transition...".
//         WAIT UNTIL BODY:NAME <> currentBody:NAME.
//         PRINT "SOI transition complete. Now orbiting " + BODY:NAME.

//         // === Complete Burn After SOI Exit ===
//         // Recompute acceleration (in case new engines or fuel mass)
//         SET acc TO SHIP:MAXTHRUST / SHIP:MASS.

//         // Estimate time to complete remainingDV
//         SET finalBurnTime TO remainingDV / acc.

//         PRINT "Finishing burn in solar orbit, duration: " + finalBurnTime + "s".
//         LOCK STEERING TO burnVec.
//         UNTIL remainingDV <= 0.1 {
//             LOCK THROTTLE TO burnThrottle.
//             WAIT 0.1.
//             IF SHIP:AVAILABLETHRUST = 0 AND THROTTLE > 0 {
//                 PRINT "No thrust detected. Staging...".
//                 STAGE.
//                 WAIT 1. // Give time for engines to activate
//             }
//         }
//         WAIT finalBurnTime.
//         LOCK THROTTLE TO 0.

//         PRINT "Final burn complete.".
//         BREAK.
//     }

//     LOCK THROTTLE TO 0.
//     PRINT "Pass " + i + " complete.".

//     // Wait to coast to next periapsis
//     IF i < numPasses AND remainingDV > 0.1 {
//         PRINT "Warping to next periapsis...".
//         WAIT 2.
//         SET periapsisTime TO TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS.
//         KUNIVERSE:TIMEWARP:WARPTO(periapsisTime - 30).
//         WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
//         WAIT 1.
//         LOCK STEERING TO burnVec.
//         WAIT 10.
//     }

//     SET i TO i + 1.
//   }

//   UNLOCK STEERING.
//   PRINT "All burn passes complete.".
// }

// perform_periapsis_burns(TOTAL_DV, 1, PASS_COUNT).

// LOCK STEERING TO UP + R(0,90,0).
// PRINT "Oberth transfer complete.".
