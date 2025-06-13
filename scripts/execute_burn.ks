// execute_burn.ks

DECLARE FUNCTION execute_burn {
    PARAMETER burn_node. // The maneuver node to execute

    SET orig_dv TO burn_node:DELTAV.
    
    // Calculate burn duration
    LOCAL max_acceleration IS SHIP:MAXTHRUST / SHIP:MASS.
    LOCAL burn_time IS burn_node:DELTAV:MAG / max_acceleration.
    LOCAL warp_rate IS 1.
    LOCAL long_burn IS false.
    
    // Scale physics warp based on burn duration
    IF burn_time > 1800 {        // > 30 minutes
        SET warp_rate TO 4.      // Maximum physics warp
    } ELSE IF burn_time > 600 { // > 10 minutes
        SET warp_rate TO 3.
    } ELSE IF burn_time > 180 {  // > 3 minutes
        SET warp_rate TO 2.
    }
    
    IF warp_rate > 1 {
        SET long_burn TO true.
        PRINT "Long burn detected (" + ROUND(burn_time/60,1) + " minutes).".
        PRINT "Enabling " + warp_rate + "x physics warp.".
        SET KUNIVERSE:TIMEWARP:MODE TO "PHYSICS".
        SET KUNIVERSE:TIMEWARP:WARP TO warp_rate.
        WAIT 1. // Allow physics to settle
    }

    LOCAL prev_remainingDeltaV IS burn_node:DELTAV:MAG.

    UNTIL burn_node:DELTAV:MAG < 0.1 {
        SET remainingDeltaV TO burn_node:DELTAV:MAG.
        LOCAL remaining_percent IS remainingDeltaV / orig_dv:MAG.

        // Safety check: abort if remaining Δv increases
        // IF remainingDeltaV > prev_remainingDeltaV {
        //     PRINT "Warning: Remaining Δv increased! Aborting burn.".
        //     BREAK.
        // }
        // SET prev_remainingDeltaV TO remainingDeltaV.

        // Disable warp for fine control near end
        IF warp_rate > 1 AND remaining_percent < 0.1 {
            PRINT "Approaching burn completion, disabling warp.".
            SET KUNIVERSE:TIMEWARP:WARP TO 0.
            SET warp_rate TO 1.
            WAIT 1. // Allow physics to settle
        }

        // Throttle control with progress display
        IF (remainingDeltaV < 10 OR remainingDeltaV < orig_dv:MAG * 0.1) AND long_burn = false {
            LOCK THROTTLE TO MAX(0.1, remainingDeltaV / 10).
        } ELSE {
            LOCK THROTTLE TO 1.
        }
        
        PRINT "Burn progress: " + ROUND((1 - remaining_percent) * 100, 1) + "%   " AT (0,12).
        PRINT "Remaining Δv: " + ROUND(remainingDeltaV, 1) + " m/s   " AT (0,13).
        PRINT "Time warp: " + warp_rate + "x   " AT (0,14).

        IF VDOT(orig_dv, burn_node:DELTAV) < 0 {
            PRINT "Node vector diverging. Terminating burn early.".
            BREAK.
        }

        WAIT 0.1.
    }

    // Cleanup
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
    LOCK THROTTLE TO 0.
}