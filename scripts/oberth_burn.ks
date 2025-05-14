// oberth_burn.ks
SET MIN_PERIAPSIS_ALTITUDE TO 70000.
SET PASSES_DONE TO 0.

// --- Step 1: Read maneuver node ---
IF NODE:EXISTS {
    SET MAN_NODE TO NODE.
    SET DELTA_V_VECTOR TO MAN_NODE:DELTAV.
    SET TOTAL_DV TO DELTA_V_VECTOR:MAG.
    SET BURN_VECTOR TO DELTA_V_VECTOR:NORMALIZED.
    PRINT "Loaded maneuver node Δv: " + ROUND(TOTAL_DV,1) + " m/s".
} ELSE {
    PRINT "No maneuver node found. Aborting.".
    WAIT 0.
}

// Δv availability check
SET MAX_DV TO SHIP:MAXDELTA.
    PRINT "ERROR: Required Δv (" + TOTAL_DV + ") exceeds vessel capability (" + MAX_DV + ").".
    WAIT 0.

// --- Optimization function ---
DECLARE FUNCTION burn_utility {
    PARAMETER burn_dv.
    PARAMETER total_dv.
    PARAMETER isp.
    PARAMETER thrust.
    PARAMETER mass.
    PARAMETER mu.
    PARAMETER r_per.

    SET accel TO thrust / mass.
    SET burn_time TO burn_dv / accel.

    SET a TO r_per.
    SET v_per TO SQRT(mu * (2/r_per - 1/a)).
    SET dwell_time TO (r_per / v_per) * 0.25.

    SET efficiency_score TO dwell_time / burn_time.
    IF efficiency_score > 1 { SET efficiency_score TO 1. }

    SET burn_count TO CEILING(total_dv / burn_dv).

    SET k1 TO 1.5.
    SET k2 TO 1.0.

    RETURN k1 * efficiency_score - k2 * burn_count.
}

// --- Auto-select best Δv per pass ---
SET burn_sizes_list to LIST(30, 50, 70, 90, 120).
SET best_score TO -99999.
SET best_burn TO 0.

SET MU TO BODY:MU.
SET R_PER TO BODY:RADIUS + SHIP:PERIAPSIS.
SET ISP TO SHIP:ISP.
SET T TO SHIP:MAXTHRUST.
SET MASS TO SHIP:MASS.

FOR b IN burn_sizes_list {
    SET score TO burn_utility(b, TOTAL_DV, ISP, T, MASS, MU, R_PER).
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

// --- Burn loop ---
UNTIL PASSES_DONE >= PASS_COUNT OR SHIP:VELOCITY:ORBIT:MAG >= TARGET_V {
    PRINT "Waiting for periapsis...".
    WAIT UNTIL SHIP:PERIAPSIS < MIN_PERIAPSIS_ALTITUDE.

    PRINT "Pass " + (PASSES_DONE+1) + ": Steering to maneuver direction.".
    LOCK STEERING TO BURN_VECTOR:VUNIT.

    SET CURRENT_V TO SHIP:VELOCITY:ORBIT:MAG.
    SET TARGET_PASS_V TO MIN(CURRENT_V + MAX_DV_PER_PASS, TARGET_V).

    PRINT "Burning to reach " + ROUND(TARGET_PASS_V,1) + " m/s.".
    LOCK THROTTLE TO 1.

    WAIT UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_PASS_V OR SHIP:ALTITUDE > SHIP:APOAPSIS - 1000.

    LOCK THROTTLE TO 0.
    PRINT "Pass " + PASSES_DONE + " complete.".

    SET PASSES_DONE TO PASSES_DONE + 1.
    SET MASS TO SHIP:MASS.
    WAIT 2.
}

// Clean up node
IF NODE:EXISTS {
    NODE:REMOVE.
    PRINT "Maneuver node removed.".
}

LOCK STEERING TO UP + R(0,90,0).
PRINT "Oberth transfer complete.".
