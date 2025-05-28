// plan_duna_transfer.ks
// Creates and executes an interplanetary transfer to Duna from current solar orbit

PRINT "Planning interplanetary transfer to Duna...".

SET sun TO BODY.
SET duna TO BODY("Duna").
SET r1 TO SHIP:ORBIT:SEMIMAJORAXIS.
SET r2 TO duna:ORBIT:SEMIMAJORAXIS.

// Estimate transfer Δv for Hohmann-style injection
SET v1 TO SQRT(sun:MU / r1).
SET v_trans TO SQRT(2 * sun:MU * r2 / (r1 * (r1 + r2))).
SET dv TO v_trans - v1.

// Place node at periapsis for maximum efficiency
SET node_time TO TIME:SECONDS + ETA:PERIAPSIS.
SET new_node TO NODE(node_time, 0, 0, dv).
ADD new_node.

// Align and execute burn
LOCK STEERING TO new_node:BURNVECTOR.
SET burn_duration TO dv / (SHIP:MAXTHRUST / SHIP:MASS).
SET burn_start_time TO node_time - (burn_duration / 2).

IF burn_start_time - TIME:SECONDS > 30 {
    PRINT "Warping to burn start...".
    KUNIVERSE:TIMEWARP:WARPTO(burn_start_time - 20).
    WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
    WAIT 0.2.
}

WAIT UNTIL TIME:SECONDS >= burn_start_time.
PRINT "Executing Duna transfer burn with physics warp...".
SET KUNIVERSE:TIMEWARP:MODE TO "PHYSICS".
SET KUNIVERSE:TIMEWARP:WARP TO 2.
LOCK THROTTLE TO 1.
WAIT burn_duration.
SET KUNIVERSE:TIMEWARP:WARP TO 0.
SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
LOCK THROTTLE TO 0.
REMOVE new_node.

PRINT "Interplanetary burn to Duna complete.".
