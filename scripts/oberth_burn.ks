// oberth_burn.ks - Modular, readable Oberth burn sequencer

RUN "capture_node.ks".
RUN "compute_max_safe_dv.ks".
RUN "execute_burn.ks".
RUN "lore.ks".
RUN "execute_maneuver.ks".
RUN "true_anomaly.ks".

IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}

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

// --- Constants ---
SET SAFE_PERI TO 75500.
SET DV_STEP TO 5.0.
SET max_dv_per_burn TO 100.

// --- Node capture and setup ---
PRINT "Checking for maneuver node...".
WAIT UNTIL ALLNODES:LENGTH > 0.

// Use the first node in the list (the soonest one)
SET man_node TO ALLNODES[0].
SET node_params TO capture_node_parameters(man_node).
SET original_node_time TO node_params[0].
SET original_prograde TO node_params[1].
SET original_normal TO node_params[2].
SET original_radial TO node_params[3].
SET original_burn_ta TO true_anomaly_at_time(original_node_time, SHIP:ORBIT, BODY:MU).
SET DELTA_V_VECTOR TO V(original_prograde, original_normal, original_radial).
SET TOTAL_DV TO DELTA_V_VECTOR:MAG.
SET BURN_VECTOR TO DELTA_V_VECTOR:NORMALIZED.

// Remove only the first node (leave others for later)
REMOVE man_node.

PRINT "Loaded maneuver node Δv: " + ROUND(TOTAL_DV,1) + " m/s".

SET PASSES_DONE TO 0.
SET V_INITIAL TO SHIP:VELOCITY:ORBIT:MAG.
SET TARGET_V TO V_INITIAL + TOTAL_DV.
SET burn_plan TO 0.

// --- Helper function for burn planning ---
DECLARE FUNCTION plan_burn {
    PARAMETER plan_burn_ta.
    PARAMETER plan_burn_vector.
    PARAMETER plan_remaining_dv.

    SET sma TO SHIP:ORBIT:SEMIMAJORAXIS.
    SET ecc TO SHIP:ORBIT:ECCENTRICITY.
    SET nu_rad TO plan_burn_ta * CONSTANT:DEGTORAD.
    SET r_burn TO sma * (1 - ecc^2) / (1 + ecc * COS(nu_rad)).
    SET speed_burn TO SQRT(BODY:MU * (2 / r_burn - 1 / sma)).
    SET v_burn_vector TO plan_burn_vector * speed_burn.
    PRINT "Burn vector: " + v_burn_vector + " m/s at true anomaly " + plan_burn_ta + "°".
    PRINT "plan_remaining_dv: " + plan_remaining_dv.
    PRINT "dv_to_use: " + max_dv_per_burn.
    IF plan_remaining_dv < max_dv_per_burn {
        SET requested_dv TO plan_remaining_dv.
    } ELSE {
        SET requested_dv TO max_dv_per_burn.
    }
    // SET requested_dv TO MIN(plan_remaining_dv, dv_to_use).
    PRINT "Requested dv: " + requested_dv + " m/s".
    IF requested_dv <= 0 {
        PRINT "Error: Requested dv is zero or negative!".
        WAIT 0.
    }
    SET accel TO SHIP:AVAILABLETHRUST / SHIP:MASS.
    IF accel <= 0 {
        PRINT "Error: Acceleration is zero or negative!".
        WAIT 0.
    }
    SET burn_time TO requested_dv / accel.
    PRINT "Calculated burn time: " + ROUND(burn_time, 1) + " seconds".

    RETURN LIST(requested_dv, burn_time, v_burn_vector).
}

// First pass: use original node time, true anomaly, and original burn vector
PRINT "Creating new node based on original node time and true anomaly...".
SET node_time TO original_node_time.
// LOCAL vel TO VELOCITYAT(SHIP, node_time):ORBIT:NORMALIZED.
SET pass_node to NODE(
    node_time,
    BURN_VECTOR:X * max_dv_per_burn,
    BURN_VECTOR:Y * max_dv_per_burn,
    BURN_VECTOR:Z * max_dv_per_burn
).
ADD pass_node.
execute_maneuver_node(pass_node).
// After first burn
SET burn_time TO max_dv_per_burn / (SHIP:AVAILABLETHRUST / SHIP:MASS). // If first burn was max_dv_per_burn m/s
SET PASSES_DONE TO 1.

// --- Main burn loop ---
UNTIL SHIP:VELOCITY:ORBIT:MAG >= TARGET_V {
    PRINT "DEBUG: TARGET_V=" + TARGET_V + ", SHIP:VELOCITY:ORBIT:MAG=" + SHIP:VELOCITY:ORBIT:MAG.
    SET remaining_dv TO TARGET_V - SHIP:VELOCITY:ORBIT:MAG.

    PRINT "Creating subsequent pass node at original true anomaly...".

    // Find the next UT when the ship will reach the original true anomaly
    LOCAL next_ta_time IS time_at_true_anomaly(original_burn_ta, SHIP:ORBIT, BODY:MU).
    IF next_ta_time < TIME:SECONDS {
        SET next_ta_time TO next_ta_time + SHIP:ORBIT:PERIOD.
    }
    SET node_time TO next_ta_time.
    SET burn_ta TO original_burn_ta.
    // SET burn_vector TO BURN_VECTOR.
    // SET burn_vector TO VELOCITYAT(SHIP, node_time):ORBIT:NORMALIZED.
    SET burn_vector to BURN_VECTOR.

    // Use plan_burn for this pass
    LOCAL burn_plan IS plan_burn(node_time, burn_vector, remaining_dv).
    PRINT "burn_plan: " + burn_plan.
    SET max_pass_dv TO max_dv_per_burn.
    SET burn_time TO burn_plan[1].
    SET v_burn_vector TO burn_plan[2].
    SET burn_start_time TO node_time - (burn_time / 2).

    IF max_pass_dv < 1 {
        PRINT "Safe Δv for this pass too small, aborting.".
        BREAK.
    }

    // Create and verify maneuver node
    SET pass_node TO NODE(
        node_time,
        BURN_VECTOR:X * max_pass_dv,
        BURN_VECTOR:Y * max_pass_dv,
        BURN_VECTOR:Z * max_pass_dv
    ).
    PRINT "Creating maneuver node at " + ROUND(node_time - TIME:SECONDS, 1) + " seconds from now.".
    ADD pass_node.
    WAIT 1.

    LOCAL active_node IS ALLNODES[0].
    execute_maneuver_node(active_node).

    PRINT "Burn complete. Remaining Δv: " + ROUND(TARGET_V - SHIP:VELOCITY:ORBIT:MAG, 1) + " m/s".
    PRINT "Current Periapsis: " + ROUND(SHIP:ORBIT:PERIAPSIS/1000,1) + " km, Apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS/1000,1) + " km".
    SET PASSES_DONE TO PASSES_DONE + 1.

    WAIT 1.
}

PRINT "Oberth burn sequence complete. Final orbit: Pe " + ROUND(SHIP:ORBIT:PERIAPSIS/1000,1) + " km, Ap " + ROUND(SHIP:ORBIT:APOAPSIS/1000,1) + " km".
