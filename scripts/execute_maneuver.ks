// maneuver.ks - Function to execute a maneuver node

RUN "execute_burn.ks".

DECLARE FUNCTION execute_maneuver_node {
    PARAMETER nicenode.

    LOCAL g0 IS 9.80665.

    IF SAS {
        SAS OFF.
        PRINT "SAS disabled.".
    }

    // Point to maneuver node direction
    LOCK STEERING TO nicenode:BURNVECTOR.
    PRINT "Locking steering to maneuver node.".

    // Wait until ship is pointed at the maneuver node
    WAIT UNTIL VANG(SHIP:FACING:VECTOR, nicenode:BURNVECTOR) < 1.
    PRINT "Ship aligned with maneuver node.".

    // Calculate delta-v required from the maneuver node
    LOCAL deltaV IS nicenode:DELTAV:MAG.

    LIST ENGINES IN ship_engines.
    LOCAL totalThrust IS 0.
    LOCAL totalISPWeighted IS 0.

    IF ship_engines:LENGTH > 0 {
        // Use main engines
        FOR eng IN ship_engines {
            IF eng:THRUSTLIMIT > 0 AND eng:FLAMEOUT = FALSE {
                SET totalThrust TO totalThrust + eng:MAXTHRUST.
                SET totalISPWeighted TO totalISPWeighted + (eng:ISP * eng:MAXTHRUST).
            }
        }
        SET isp TO totalISPWeighted / totalThrust.
        SET thrust TO totalThrust.
    } ELSE {
        // Use RCS if no engines
        PRINT "No main engines found. Attempting RCS.".
        RCS ON.

        // Estimate RCS thrust
        SET rcsThrust TO 1.0. // A rough average total thrust for RCS clusters
        SET rcsISP TO 220. // Approximate ISP for hydrazine

        SET thrust TO rcsThrust.
        SET isp TO rcsISP.
    }

    // Initial mass before burn
    LOCAL m0 IS SHIP:MASS.

    // Compute final mass using Tsiolkovsky equation
    LOCAL mf IS m0 / (constant:e() ^ (deltaV / (isp * g0))).

    // Average mass during burn (approximate)
    LOCAL mAvg IS (m0 + mf) / 2.

    // Average acceleration = Thrust / Average Mass
    LOCAL accel IS thrust / mAvg.

    // Estimated burn time
    LOCAL burnTime IS deltaV / accel.

    // Burn starts at T - half burn time
    LOCAL burnStartTime IS nicenode:TIME - (burnTime / 2).

    // Timewarp to just before burn start
    IF burnStartTime - time:seconds > 30 {
        kuniverse:timewarp:warpto(burnStartTime - 5).
        WAIT 1.
        WAIT UNTIL kuniverse:timewarp:rate = 1.
        WAIT 0.2.
    }

    // Point to maneuver node direction again
    LOCK STEERING TO nicenode:BURNVECTOR.

    // Wait until burn start time
    WAIT UNTIL burnStartTime - time:seconds <= 1.
    PRINT "Burning for " + ROUND(burnTime, 1) + " seconds.".

    // Execute burn
    execute_burn(nicenode).

    UNLOCK STEERING.

    REMOVE nicenode.
    PRINT "Maneuver complete.".
}
