// oberth_burn.ks
SET MIN_PERIAPSIS_ALTITUDE TO 70000.
SET PASSES_DONE TO 0.
SET TOTAL_DV TO 800. // Replace or load from planner
SET V_INITIAL TO SHIP:VELOCITY:ORBIT:MAG.
SET TARGET_V TO V_INITIAL + TOTAL_DV.

// Δv availability check
SET MAX_DV TO SHIP:MAXDELTA.
IF TOTAL_DV > MAX_DV {
    PRINT "ERROR: Required Δv (" + TOTAL_DV + ") exceeds vessel capability (" + MAX_DV + ").".
}

// --- Optimization function ---
DECLARE FUNCTION burn_utility {
    DECLARE PARAMETER burn_dv.
    DECLARE PARAMETER total_dv.
    DECLARE PARAMETER isp.
    DECLARE PARAMETER thrust.
    DECLARE PARAMETER mass.
    DECLARE PARAMETER mu.
    DECLARE PARAMETER r_per.

    SET accel TO thrust / mass.
    SET burn_time TO burn_dv / accel.

    SET a TO r_per.
    SET v_per TO SQRT(mu * (2/r_per - 1/a)).
    SET dwell_time TO (r_per / v_per) * 0.25.

    SET efficiency_score TO dwell_time / burn_time.
    IF efficiency_score > 1 { SET efficiency_score TO 1. }

    SET burn_count TO CEILING(total_dv / burn_dv).

    SET k1 TO 1.5. // Efficiency weight
    SET k2 TO 1.0. // Burn count penalty

    RETURN k1 * efficiency_score - k2 * burn_count.
}

// --- Auto-select best Δv per pass ---
SET burn_sizes TO LIST(30, 50, 70, 90, 120).
SET best_score TO -99999.
SET best_burn TO 0.

SET MU TO BODY:MU.
SET R_PER TO BODY:RADIUS + SHIP:PERIAPSIS.
SET ISP TO SHIP:ISP.
SET T TO SHIP:MAXTHRUST.
SET MASS TO SHIP:MASS.

FOR b IN burn_sizes {
    SET score TO burn_utility(b, TOTAL_DV, ISP, T, MASS, MU, R_PER).
    PRINT "Δv " + b + ": score = " + score.
    IF score > best_score {
        SET best_score TO score.
        SET best_burn TO b.
    }
}

SET MAX_DV_PER_PASS TO best_burn.
SET PASS_COUNT TO CEILING(TOTAL_DV / MAX_DV_PER_PASS).

PRINT "Optimal Δv per pass: " + MAX_DV_PER_PASS + " m/s over " + PASS_COUNT + " passes.".

// --- Burn loop ---
UNTIL PASSES_DONE >= PASS_COUNT OR SHIP:VELOCITY:ORBIT:MAG >= TARGET_V {
    PRINT "Waiting for periapsis...".
    WAIT UNTIL SHIP:PERIAPSIS < MIN_PERIAPSIS_ALTITUDE.

    PRINT "Pass " + (PASSES_DONE+1) + ": Steering to prograde.".
    LOCK STEERING TO PROGRADE.

    SET CURRENT_V TO SHIP:VELOCITY:ORBIT:MAG.
    SET TARGET_PASS_V TO MIN(CURRENT_V + MAX_DV_PER_PASS, TARGET_V).

    PRINT "Burning to reach " + ROUND(TARGET_PASS_V,1) + " m/s.".
    LOCK THROTTLE TO 1.

    WAIT UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_PASS_V OR SHIP:ALTITUDE > SHIP:APOAPSIS - 1000.

    LOCK THROTTLE TO 0.
    PRINT "Pass " + PASSES_DONE + " complete.".

    SET PASSES_DONE TO PASSES_DONE + 1.

    // Update mass & reoptimize if desired (optional)
    SET MASS TO SHIP:MASS.
    WAIT 2.
}

LOCK STEERING TO UP + R(0,90,0).
PRINT "Oberth transfer complete.".
