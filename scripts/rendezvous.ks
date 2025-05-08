// rendezvous.ks
// Basic rendezvous script to get close to a targeted vessel in LKO
// Author: Nick + ChatGPT

CLEARSCREEN.
PRINT "Rendezvous script started.".

// Orient prograde to prepare
PRINT "Aligning prograde...".
LOCK STEERING TO PROGRADE.
WAIT 10.

// Estimate burn to match orbits
SET relVel TO (TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT):MAG.
PRINT "Relative velocity: " + ROUND(relVel, 1) + " m/s.".

// Burn to match velocities
PRINT "Burning to match velocity...".
LOCK THROTTLE TO 0.5.
WAIT UNTIL (SHIP:VELOCITY:ORBIT - TARGET:VELOCITY:ORBIT):MAG < 1.
LOCK THROTTLE TO 0.
PRINT "Velocity matched.".

// Coast until within 1km
PRINT "Waiting until within 1 km...".
WAIT UNTIL SHIP:POSITION:DISTANCE(TARGET:POSITION) < 1000.
PRINT "Approach within 1km achieved.".

PRINT "Switching to RCS for fine control.".
RCS ON.

// Orient toward the target
LOCK STEERING TO (TARGET:POSITION - SHIP:POSITION):NORMALIZED.
WAIT 5.

PRINT "Rendezvous complete. Ready for fine docking.".
