// Constants
SET ECC_THRESHOLD TO 0.05. // Maximum acceptable eccentricity

// Ensure we're in orbit around a body
IF NOT SHIP:ORBIT:BODY:HASATMOSPHERE OR SHIP:ORBIT:PERIAPSIS > SHIP:ORBIT:BODY:ATMOSPHEREHEIGHT {
    PRINT "Verifying orbital eccentricity...".
    
    // Check eccentricity
    SET ecc TO SHIP:ORBIT:ECCENTRICITY.
    PRINT "Eccentricity is: " + ROUND(ecc, 3).

    IF ecc > ECC_THRESHOLD {
        PRINT "Orbit too eccentric. Circularizing...".
        
        // Decide where to circularize: at apoapsis or periapsis
        SET useApoapsis TO SHIP:ORBIT:APOAPSIS > SHIP:ORBIT:PERIAPSIS.
        IF useApoapsis {
            SET r TO SHIP:ORBIT:APOAPSIS.
            SET eta TO SHIP:ORBIT:TIMEAT(SHIP:ORBIT:APOAPSIS).
        } ELSE {
            SET r TO SHIP:ORBIT:PERIAPSIS.
            SET eta TO SHIP:ORBIT:TIMEAT(SHIP:ORBIT:PERIAPSIS).
        }

        // Calculate deltaV required to circularize
        SET mu TO SHIP:BODY:MU.
        SET v_circular TO SQRT(mu / r).
        SET v_orbit TO SQRT(2 * mu / r - mu / SHIP:ORBIT:SEMI MAJOR AXIS).
        SET deltaV TO v_circular - v_orbit.

        // Estimate burn time
        SET burnTime TO (SHIP:MASS * ABS(deltaV)) / (SHIP:MAXTHRUST / SHIP:AVAILABLETHRUST).

        // Display burn information
        PRINT "Estimated Delta-V: " + ROUND(deltaV, 2) + " m/s".
        PRINT "Burn begins in: " + ROUND(eta, 1) + " seconds".
        PRINT "Estimated burn duration: " + ROUND(burnTime, 1) + " seconds".

        // Ask user to confirm
        PRINT "Type YES to confirm the burn or anything else to cancel.".
        SET confirm TO "".
        UNTIL confirm:UPPER = "YES" OR confirm:UPPER ≠ "" {
            INPUT confirm.
        }

        IF confirm:UPPER = "YES" {
            // Create and configure the maneuver node
            SET node TO NODE(TIME + eta).
            SET progradeVec TO SHIP:VELOCITY:ORBIT:NORMALIZED.
            node:ADDDELTAV(progradeVec * deltaV).

            WAIT UNTIL ETA:NODE(0) < 30.

            LOCK STEERING TO NODE(0):DIRECTION.

            WAIT UNTIL ETA:NODE(0) < 3.

            SET THROTTLE TO 1.
            WAIT burnTime.
            SET THROTTLE TO 0.

            REMOVE NODE(0).
            PRINT "Circularization complete.".
        } ELSE {
            PRINT "Burn cancelled by user.".
        }
    } ELSE {
        PRINT "Orbit is already circular.".
    }
} ELSE {
    PRINT "Warning: Orbit may be within atmospheric boundary!".
}
