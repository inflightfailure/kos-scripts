// plan_duna_transfer.ks
// Creates and executes an interplanetary transfer to Duna from current solar orbit

PRINT "Planning interplanetary transfer to Duna...".

// Initialize bodies and orbital parameters
SET target_sun TO BODY.
SET target_duna TO BODY("Duna").
SET departure_radius TO SHIP:ORBIT:SEMIMAJORAXIS.
SET arrival_radius TO target_duna:ORBIT:SEMIMAJORAXIS.

// Calculate optimal ejection parameters
LOCAL kerbin_vel IS SQRT(target_sun:MU/KERBIN:ORBIT:SEMIMAJORAXIS).
LOCAL transfer_sma IS (arrival_radius + departure_radius) / 2.
LOCAL transfer_vel IS SQRT(target_sun:MU * (2/departure_radius - 1/transfer_sma)).
LOCAL v_infinity IS transfer_vel - kerbin_vel.

// Calculate ejection angle and required velocity
LOCAL escape_vel IS SQRT(2 * KERBIN:MU / SHIP:ORBIT:SEMIMAJORAXIS).
LOCAL v_ejection IS SQRT(v_infinity^2 + escape_vel^2).
LOCAL ejection_angle IS ARCCOS(escape_vel/v_ejection).

PRINT "Transfer parameters:".
PRINT "  Required velocity: " + ROUND(v_ejection,1) + " m/s".
PRINT "  Ejection angle: " + ROUND(ejection_angle,1) + "°".
PRINT "  V-infinity: " + ROUND(v_infinity,1) + " m/s".

// Calculate node burn vector
LOCAL node_normal IS VCRS(SHIP:VELOCITY:ORBIT, -BODY:POSITION):NORMALIZED.
LOCAL node_prograde IS SHIP:VELOCITY:ORBIT:NORMALIZED.
LOCAL node_radial IS VCRS(node_normal, node_prograde).

// Rotate prograde vector by ejection angle
LOCAL burn_vector IS node_prograde * COS(ejection_angle) + node_radial * SIN(ejection_angle).
LOCAL delta_v IS v_ejection - SHIP:VELOCITY:ORBIT:MAG.

// Place node at periapsis
SET node_time TO TIME:SECONDS + ETA:PERIAPSIS.
SET new_node TO NODE(node_time, 
    burn_vector * node_radial * delta_v,
    burn_vector * node_normal * delta_v,
    burn_vector * node_prograde * delta_v).
ADD new_node.

// Align and execute burn
LOCK STEERING TO new_node:BURNVECTOR.
SET burn_duration TO delta_v / (SHIP:MAXTHRUST / SHIP:MASS).
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
