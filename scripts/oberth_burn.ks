// oberth_burn.ks
// best for high-thrust, low-ISP engines


RUN "execute_burn.ks".
RUN "lore.ks".
// Load true anomaly functions
RUN "true_anomaly.ks".

// Turn off SAS if enabled
IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}

// Output crew list
write_crewlist().
wait_for_lore().
print_lore().

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

// Wait for a maneuver node to exist
PRINT "Checking for maneuver node...".
WAIT UNTIL hasNode.

// Δv availability check
SET MAX_DV TO SHIP:DELTAV:VACUUM.
SET TOTAL_DV TO NEXTNODE:DELTAV:MAG.

IF MAX_DV < TOTAL_DV {
    PRINT "ERROR: Required Δv (" + TOTAL_DV + ") exceeds vessel capability (" + MAX_DV + ").".
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

    PRINT "Computing maximum safe Δv...".

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


SET man_node TO NEXTNODE.


SET PASSES_DONE TO 0.

// Read maneuver node ---
SET DELTA_V_VECTOR TO man_node:DELTAV.
SET TOTAL_DV TO DELTA_V_VECTOR:MAG.
SET BURN_VECTOR TO DELTA_V_VECTOR:NORMALIZED.
SET node_pos TO man_node:ORBIT:POSITION.
SET NODE_RADIUS TO node_pos:MAG.
SET NODE_VECTOR TO node_pos:NORMALIZED.
// NODE:ORBIT:TRUEANOMALY is the true anomaly of the expected orbit after the maneuver
SET node_ta TO true_anomaly_at_time(man_node:ETA, SHIP:ORBIT, BODY:MU).
SET accel to totalThrust / SHIP:MASS.
SET total_dv to man_node:DELTAV:MAG.
SET burn_time TO total_dv / accel.
SET node_time TO man_node:TIME.
SET burn_start_time to node_time - (burn_time / 2).

// Estimate orbital state at burn start time
SET burn_ta TO true_anomaly_at_time(burn_start_time, SHIP:ORBIT, BODY:MU).
// Calculate radius at a given true anomaly
SET sma TO SHIP:ORBIT:SEMIMAJORAXIS.
SET ecc TO SHIP:ORBIT:ECCENTRICITY.
SET nu_deg TO burn_ta. // true anomaly in degrees
SET nu_rad TO nu_deg * CONSTANT:DEGTORAD.

SET r_burn TO sma * (1 - ecc^2) / (1 + ecc * COS(nu_rad)).
SET speed_burn TO SQRT(BODY:MU * (2 / r_burn - 1 / SHIP:ORBIT:SEMIMAJORAXIS)).
SET v_burn_vector TO BURN_VECTOR * speed_burn.


REMOVE man_node.
PRINT "Loaded maneuver node Δv: " + ROUND(TOTAL_DV,1) + " m/s".

SET SAFE_PERI TO 75000.
SET DV_STEP TO 5.0.

SET PASSES_DONE TO 0.
SET V_INITIAL TO SHIP:VELOCITY:ORBIT:MAG.
SET TARGET_V TO V_INITIAL + TOTAL_DV.

// Initiate burn sequence
UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_V {

    // Compute safe Δv for this pass
    SET REMAINING_DV TO TARGET_V - SHIP:VELOCITY:ORBIT:MAG.
    SET MAX_PASS_DV TO compute_max_safe_dv(
        REMAINING_DV,
        BODY:MU,
        r_burn,
        v_burn_vector,
        BURN_VECTOR,
        DV_STEP,
        SAFE_PERI
    ).

    // Add a new maneuver node for this pass at the location of the original maneuver node
    SET node_time TO time_at_true_anomaly(node_ta, SHIP:ORBIT, BODY:MU).
    SET radial_dv TO VDOT(BURN_VECTOR, V(1,0,0)) * MAX_PASS_DV.
    SET normal_dv TO VDOT(BURN_VECTOR, V(0,1,0)) * MAX_PASS_DV.
    SET prograde_dv TO VDOT(BURN_VECTOR, V(0,0,1)) * MAX_PASS_DV.
    SET pass_node TO NODE(node_time, radial_dv, normal_dv, prograde_dv).
    ADD pass_node.

    LOCK STEERING TO pass_node:BURNVECTOR.

    // Timewarp to just before the burn start time
    SET burn_start_time TO node_time - (burn_time / 2).
    IF burn_start_time - TIME:SECONDS > 30 {
        PRINT "Timewarping to burn start time.".
        KUNIVERSE:TIMEWARP:WARPTO(burn_start_time - 20).
        WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
        WAIT 0.2.
    }
    IF burn_start_time <= TIME:SECONDS {
        PRINT "Skipping timewarp: burn start time already passed!".
    }


    // Wait until burn start time (node time minus half the burn duration)
    WAIT UNTIL TIME:SECONDS >= burn_start_time.
    PRINT "Initiating burn for pass " + (PASSES_DONE + 1) + ", Safe burn Δv = " + MAX_PASS_DV.
    execute_burn(pass_node).

    REMOVE pass_node.
    PRINT "Burn complete.".
    SET PASSES_DONE TO PASSES_DONE + 1.

}
