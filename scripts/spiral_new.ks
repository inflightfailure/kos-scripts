// spiral_new.ks - Spiral out and execute interplanetary transfer

RUN "capture_node.ks".
RUN "true_anomaly.ks".
RUN "execute_maneuver.ks".
RUN "execute_burn.ks".

// --- 1. Capture both transfer node parameters ---
WAIT UNTIL ALLNODES:LENGTH >= 2.
SET primary_node TO ALLNODES[0].
SET tuning_node TO ALLNODES[1].

SET primary_params TO capture_node_parameters(primary_node).
SET tuning_params TO capture_node_parameters(tuning_node).

SET transfer_dv TO SQRT(primary_params[1]^2 + primary_params[2]^2 + primary_params[3]^2).

REMOVE primary_node.
REMOVE tuning_node.

// --- 1b. Timewarp to the initial maneuver node's time ---
SET transfer_time TO primary_params[0].
PRINT "Timewarping to initial maneuver node time: " + transfer_time + " ...".
IF transfer_time - TIME:SECONDS > 120 {
    // If the burn is more than 2 minutes away, timewarp close to it
    KUNIVERSE:TIMEWARP:WARPTO(transfer_time).
    WAIT 1.
    WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
    WAIT 0.2.
}

// Optionally, wait until just before the node if not already there
// WAIT UNTIL TIME:SECONDS >= transfer_time - 30.

// --- 2. Spiral out until near escape (target Ap near SOI) ---
SET SOI_TARGET TO BODY:SOIRADIUS * 0.95.
SET max_dv_per_burn TO 150. // Or your preferred value

PRINT "Beginning spiral-out phase until Apoapsis > " + ROUND(SOI_TARGET/1000,1) + " km.".

UNTIL SHIP:ORBIT:APOAPSIS > SOI_TARGET {
    // Abort spiral if we leave the SOI
    IF SHIP:ORBIT:APOAPSIS < 0 {
        PRINT "Apoapsis is negative. Ending spiral-out.".
        BREAK.
    }

    LOCAL node_time IS TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS.
    //LOCAL burn_vector IS VELOCITYAT(SHIP, node_time):ORBIT:NORMALIZED.
    LOCAL burn_dv IS MIN(max_dv_per_burn, transfer_dv).

    // Track remaining delta-v before burn
    LOCAL dv_before IS SHIP:DELTAV:CURRENT.

    SET pass_node TO NODE(
        node_time,
        0,
        0,
        burn_dv
    ).
    ADD pass_node.
    WAIT 1.

    // Check the predicted apoapsis after the burn
    // TODO: adjust since an escape trajectory can still have a positive apoapsis
    LOCAL predicted_ap IS pass_node:ORBIT:APOAPSIS.
    LOCAL reduction is pass_node:prograde * 0.1.
    IF predicted_ap < 0 {
        PRINT "Adjusting burn to avoid negative apoapsis.".
        UNTIL pass_node:ORBIT:APOAPSIS > 0 {
            SET pass_node:prograde TO pass_node:prograde - reduction.
            WAIT 0.1.
        }
    }

    LOCAL active_node IS ALLNODES[0].
    execute_maneuver_node(active_node).

    // Track remaining delta-v after burn
    LOCAL dv_after IS SHIP:DELTAV:CURRENT.
    LOCAL dv_used IS dv_before - dv_after.
    LOCAL efficiency IS 0.
    IF ABS(dv_used) > 0.0001 {
        SET efficiency TO (burn_dv / dv_used) * 100.
    }

    PRINT "Spiral burn complete. Current Ap: " + ROUND(SHIP:ORBIT:APOAPSIS/1000,1) + " km".
    PRINT "Burn Δv: " + ROUND(burn_dv,2) + " m/s, Δv used: " + ROUND(dv_used,2) + " m/s, Efficiency: " + ROUND(efficiency,1) + "%".
    WAIT 1.
}

// --- 3. Wait for the correct transfer window ---
PRINT "Spiral-out complete. Waiting for transfer window...".

// Use primary_params for the transfer node
SET transfer_time TO primary_params[0].
SET transfer_prograde TO primary_params[1].
SET transfer_normal TO primary_params[2].
SET transfer_radial TO primary_params[3].
SET transfer_burn_ta TO true_anomaly_at_time(transfer_time, SHIP:ORBIT, BODY:MU).

// Find the next time ship will reach the transfer node's true anomaly
LOCAL next_ta_time IS time_at_true_anomaly(transfer_burn_ta, SHIP:ORBIT, BODY:MU).
IF next_ta_time < TIME:SECONDS {
    SET next_ta_time TO next_ta_time + SHIP:ORBIT:PERIOD.
}
SET node_time TO next_ta_time.

// Wait until close to the transfer window
IF TIME:SECONDS < node_time - 60 {
    PRINT "Timewarping to transfer window at UT " + node_time + "...".
    KUNIVERSE:TIMEWARP:WARPTO(node_time - 60).
    WAIT 1.
    WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
    WAIT 0.2.
} ELSE {
    LOCAL wait_time IS node_time - 5 - TIME:SECONDS.
    PRINT "Waiting " + ROUND(wait_time, 1) + " seconds for transfer window...".
    UNTIL TIME:SECONDS >= node_time - 5 {
        LOCAL remaining IS node_time - 5 - TIME:SECONDS.
        PRINT "Transfer burn in " + ROUND(remaining, 1) + " seconds..." AT (0, 20).
        WAIT 0.5.
    }
}
WAIT UNTIL TIME:SECONDS >= node_time - 5.

// --- 4. Reconstruct and execute the transfer node ---
PRINT "Creating transfer node at spiral-out periapsis...".
SET transfer_node TO NODE(
    node_time,
    transfer_prograde,
    transfer_normal,
    transfer_radial
).
ADD transfer_node.
WAIT 1.
LOCAL active_node IS ALLNODES[0].
execute_maneuver_node(active_node).

PRINT "Transfer burn complete! You are now on your way to Kerbin.".

// --- 5. Wait for and execute the tuning node ---
PRINT "Waiting for tuning burn at UT " + tuning_params[0] + "...".
WAIT UNTIL TIME:SECONDS >= tuning_params[0] - 60.

PRINT "Creating tuning node...".
SET tuning_node TO NODE(
    tuning_params[0],
    tuning_params[1],
    tuning_params[2],
    tuning_params[3]
).
ADD tuning_node.
WAIT 1.
LOCAL active_node IS ALLNODES[0].
execute_maneuver_node(active_node).

PRINT "Tuning burn complete!".