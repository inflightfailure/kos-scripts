// execute_burn.ks

DECLARE FUNCTION execute_burn {
    PARAMETER burn_node. // The maneuver node to execute

    SET orig_dv to burn_node:DELTAV.

    UNTIL burn_node:DELTAV:MAG < 0.1 {
        SET remainingDeltaV TO burn_node:DELTAV:MAG.

        // Gradually reduce throttle when remainingDeltaV < 10 or less than 10% of initial deltaV
        IF remainingDeltaV < 10 or remainingDeltaV < orig_dv:MAG * 0.1 {
            LOCK THROTTLE TO MAX(0.1, remainingDeltaV / 10).
        } ELSE {
            LOCK THROTTLE TO 1.
        }

        IF VDOT(orig_dv, burn_node:DELTAV) < 0 {
            PRINT "Node vector diverging. Terminating burn early.".
            LOCK THROTTLE TO 0.
            BREAK.
        }

        IF remainingDeltaV < 0.1 {
            PRINT "Finalizing burn, remaining Δv: " + ROUND(remainingDeltaV, 2).
            WAIT UNTIL VDOT(orig_dv, burn_node:DELTAV) < 0.5.
            BREAK.
        }
    }

    LOCK THROTTLE TO 0.
}