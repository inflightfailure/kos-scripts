// Passive capture script - burns retrograde at periapsis to capture into orbit
// Compatible with kOS 1.4+

// Disable SAS to prevent steering conflict
IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}

// Wait until vessel is on an escape trajectory
WAIT UNTIL SHIP:ORBIT:ECCENTRICITY >= 1.
PRINT "Escape trajectory detected. Waiting for periapsis...".

// Wait until we're close to periapsis (5 seconds before)
WAIT UNTIL ETA:PERIAPSIS < 30.

PRINT "Approaching periapsis. Preparing for capture burn...".
LOCK STEERING TO RETROGRADE.
WAIT UNTIL ETA:PERIAPSIS < 5.

LOCK THROTTLE TO 1.
PRINT "Burning retrograde...".

// Burn until captured (eccentricity < 1) or timeout
SET burnStart TO TIME:SECONDS.
UNTIL SHIP:ORBIT:ECCENTRICITY < 1 OR SHIP:ORBIT:PERIAPSISALTITUDE < 0 {
    IF TIME:SECONDS - burnStart > 60 {
        PRINT "Capture failed or timed out.".
        BREAK.
    }
    WAIT 0.1.
}

LOCK THROTTLE TO 0.

IF SHIP:ORBIT:ECCENTRICITY < 1 {
    PRINT "Capture successful. Final Periapsis: " + ROUND(SHIP:ORBIT:PERIAPSISALTITUDE, 0) + " m".
} ELSE {
    PRINT "Capture failed or periapsis too low.".
}
