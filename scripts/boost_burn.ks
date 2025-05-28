// boost_burn.ks
// Performs a high-thrust Oberth-style burn using the available delta-v budget

RUN true_anomaly.ks.
RUN safe_dv.ks.

PARAMETER dv_cap.
PARAMETER safe_periapsis.
PARAMETER dv_step.

PRINT "Preparing Oberth burn with cap: " + ROUND(dv_cap, 1) + " m/s".

// Remove any existing maneuver nodes
IF HASNODE {
    REMOVE NEXTNODE.
    PRINT "Removed existing maneuver node.".
}

// Set up periapsis-centered burn
SET node_time TO TIME:SECONDS + ETA:PERIAPSIS.
SET burn_duration TO dv_cap / (SHIP:MAXTHRUST / SHIP:MASS).
SET burn_start_time TO node_time - (burn_duration / 2).

// Warp to start
IF burn_start_time - TIME:SECONDS > 30 {
    PRINT "Warping to burn start...".
    KUNIVERSE:TIMEWARP:WARPTO(burn_start_time - 20).
    WAIT 1.
    WAIT UNTIL kuniverse:timewarp:rate = 1.
    WAIT 0.2. // Allow physics to stabilize
}

// PRINT "Waiting for burn start...".
// WAIT UNTIL TIME:SECONDS >= burn_start_time.

// Use actual ship state at burn start
SET v_vec TO SHIP:VELOCITY:ORBIT.
SET r_val TO SHIP:ALTITUDE + BODY:RADIUS.
SET burn_vector TO SHIP:VELOCITY:ORBIT:NORMALIZED.

// Estimate max safe burn
SET max_dv TO compute_max_safe_dv(dv_cap, BODY:MU, r_val, v_vec, burn_vector, dv_step, safe_periapsis).
PRINT "Max safe Oberth burn Δv: " + max_dv + " m/s".
PRINT "Burn duration: " + ROUND(burn_duration, 1) + " seconds".

// Create temporary maneuver node for alignment
SET node_radial TO 0.
SET node_normal TO 0.
SET node_prograde TO max_dv.
SET new_node TO NODE(node_time, node_radial, node_normal, node_prograde).
ADD new_node.

LOCK STEERING TO new_node:BURNVECTOR.
// Wait until steering stabilizes
SET steer_error TO 1.
UNTIL steer_error < 0.1 {
    SET steer_error TO VANG(SHIP:FACING:VECTOR, new_node:BURNVECTOR).
    WAIT 0.1.
}
WAIT 0.5.

// Execute burn manually
LOCK THROTTLE TO 1.
UNTIL STAGE:DELTAV:CURRENT <= 0 {
    IF SHIP:PERIAPSIS < safe_periapsis {
        PRINT "ABORT: periapsis dropped too low!".
        LOCK THROTTLE TO 0.
        BREAK.
    }
    WAIT 0.1.
}
LOCK THROTTLE TO 0.
PRINT "Oberth burn complete.".
UNLOCK STEERING.
REMOVE new_node.
