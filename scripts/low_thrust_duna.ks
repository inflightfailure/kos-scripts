// Low-Thrust Spiral Transfer to Duna

// Constants
SET MU TO 1.1723328e18. // Gravitational parameter of the Sun (m^3/s^2)
SET TARGET_APOAPSIS TO 2.07e10. // Target apoapsis in meters (approximate distance to Duna's orbit)
SET THRUST_LEVEL TO 0.25. // Throttle setting (0 to 1)
SET BURN_DURATION TO 60. // Burn duration in seconds

// Main Loop
UNTIL SHIP:ORBIT:APOAPSIS >= TARGET_APOAPSIS {

    // Calculate time until periapsis
    SET TIME_TO_PERIAPSIS TO ETA:PERIAPSIS.

    // Timewarp to 10 seconds before periapsis
    IF TIME_TO_PERIAPSIS > 30 {
        PRINT "Timewarping to periapsis...".
        KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + TIME_TO_PERIAPSIS - 10).
        WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
    }

    // Align to prograde
    LOCK STEERING TO PROGRADE.

    // Wait until periapsis
    WAIT UNTIL ETA:PERIAPSIS <= 1.

    // Execute burn
    PRINT "Executing burn...".
    LOCK THROTTLE TO THRUST_LEVEL.
    WAIT BURN_DURATION.
    LOCK THROTTLE TO 0.

    // Wait for orbit to update
    WAIT 5.

    // Display current apoapsis
    PRINT "Current apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS / 1000, 0) + " km".

}
PRINT "Target apoapsis achieved. Ready for Duna transfer.".
