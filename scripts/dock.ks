// dock.ks
// Final approach and automatic docking script
// Author: Nick + ChatGPT
// Assumes you are already within ~1 km of the target
// Uses RCS for precise maneuvers

CLEARSCREEN.
PRINT "Docking script started.".

// --- 1. Find Docking Ports ---

// Find the first available docking port on your ship
SET myPort TO SHIP:DOCKINGPORTS[0].

// Find the first docking port on the target
SET targetPort TO TARGET:DOCKINGPORTS[0].

PRINT "My Docking Port: " + myPort.
PRINT "Target Docking Port: " + targetPort.

// --- 2. Set Up for Docking ---

// Turn on RCS for fine control
RCS ON.

// --- 3. Vector Math: Steering Toward the Docking Port ---

// This part uses basic vector subtraction:
// Vector from my port to target port = target position - my position

PRINT "Aligning with docking port...".
LOCK STEERING TO (targetPort:POSITION - myPort:POSITION):NORMALIZED.

// Explanation:
// (targetPort:POSITION - myPort:POSITION)
//    - This creates a vector pointing from your port **toward** the target port.
// :NORMALIZED
//    - This turns the vector into a *unit vector* (length = 1), good for just pointing without adding unwanted thrust.

// Wait for the steering to settle
WAIT 5.

// --- 4. Vector Math: Match Velocities ---

PRINT "Matching velocities...".

// Here's the key idea: you want your relative velocity (your speed *compared to* the target) to be very low
LOCK THROTTLE TO 0.

// Calculate the relative velocity vector
SET relVelVec TO (SHIP:VELOCITY:ORBIT - TARGET:VELOCITY:ORBIT).

// Now, burn opposite to that vector to slow down your relative motion
LOCK STEERING TO relVelVec:NORMALIZED:NEGATED.

// Explanation:
// relVelVec:NORMALIZED:NEGATED
//    - First, normalize the velocity difference to get a direction.
//    - Then negate it (point opposite) to **burn against your relative motion**.

LOCK THROTTLE TO 0.2.

WAIT UNTIL relVelVec:MAG < 0.5.

// Explanation:
// relVelVec:MAG
//    - The "magnitude" (MAG) of a vector is its length (i.e., speed here).
// We wait until we're almost completely stationary relative to the target.

LOCK THROTTLE TO 0.

PRINT "Velocities matched.".

// --- 5. Approach Slowly Toward Target ---

PRINT "Approaching docking port...".

LOCK STEERING TO (targetPort:POSITION - myPort:POSITION):NORMALIZED.

LOCK THROTTLE TO 0.1.

WAIT UNTIL myPort:POSITION:DISTANCE(targetPort:POSITION) < 5.

// Explanation:
// myPort:POSITION:DISTANCE(targetPort:POSITION)
//    - This gives the straight-line distance between the two docking ports.

LOCK THROTTLE TO 0.

PRINT "Within 5 meters. Fine approach...".

LOCK THROTTLE TO 0.05.

WAIT UNTIL myPort:POSITION:DISTANCE(targetPort:POSITION) < 0.5.

LOCK THROTTLE TO 0.

PRINT "Docking should occur momentarily...".

// Wait for docking to happen
WAIT UNTIL myPort:DOCKED.

PRINT "Docking successful! Congratulations!".

RCS OFF.

