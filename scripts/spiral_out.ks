// spiral_out.ks
// Performs low-thrust spiral escape by burning at periapsis to raise apoapsis

SET TARGET_APOAPSIS TO 6.7e10. // Approximate Duna orbit radius from Sun (in meters)
SET THRUST_LEVEL TO 1.0.
SET BASE_BURN_DURATION TO 60.
SET BURN_GROWTH_RATE TO 1.0.
SET MAX_BURN_DURATION TO 300.
SET burn_count TO 0.
SET total_orbital_time TO 0.
SET cumulative_period TO 0.
SET estimated_remaining_burns TO 0.

PRINT "Beginning spiral-out phase toward Duna...".

UNTIL SHIP:ORBIT:APOAPSIS >= TARGET_APOAPSIS OR SHIP:ORBIT:ECCENTRICITY >= 0.90 {
    // Check for potential Mun encounter BEFORE periapsis burn
    IF SHIP:PATCHES:LENGTH > 1 {
        SET next_patch TO SHIP:PATCHES[1].
        IF next_patch:BODY:NAME = "Mun" {
            // Calculate approach angle to check if encounter would be favorable
            LOCAL mun_velocity IS MUN:VELOCITY:ORBIT.
            LOCAL ship_velocity IS SHIP:VELOCITY:ORBIT.
            LOCAL approach_angle IS VANG(mun_velocity, ship_velocity).
            
            IF approach_angle < 150 {
                PRINT "Skipping periapsis burn to avoid unfavorable Mun encounter (" + 
                      ROUND(approach_angle,1) + "°).".
                PRINT "Waiting for better geometry...".
                WAIT 60.  // Wait a minute before checking again
            } ELSE {
                // Proceed with normal periapsis burn if no unfavorable encounter detected
                SET t_to_peri TO SHIP:OBT:ETA:PERIAPSIS.

                IF t_to_peri > 30 {
                    PRINT "Timewarping to periapsis...".
                    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + t_to_peri - 5).
                    WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
                }

                WAIT UNTIL SHIP:OBT:ETA:PERIAPSIS <= 2.
                LOCK STEERING TO PROGRADE.
                WAIT 2.

                // Calculate burn duration with growth factor
                SET BURN_DURATION TO BASE_BURN_DURATION * (BURN_GROWTH_RATE ^ burn_count).
                IF BURN_DURATION > MAX_BURN_DURATION {
                    SET BURN_DURATION TO MAX_BURN_DURATION.
                }

                PRINT "Burning at periapsis to raise apoapsis (" + ROUND(BURN_DURATION, 0) + "s) with physics warp...".
                LOCK THROTTLE TO THRUST_LEVEL.
                SET KUNIVERSE:TIMEWARP:MODE TO "PHYSICS".
                SET KUNIVERSE:TIMEWARP:WARP TO 2. // 3x physics warp
                SET burn_timer TO 0.
                UNTIL burn_timer >= BURN_DURATION OR SHIP:ORBIT:ECCENTRICITY >= 0.90 {
                    WAIT 1.
                    SET burn_timer TO burn_timer + 1.
                }
                SET KUNIVERSE:TIMEWARP:WARP TO 0.
                SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
                LOCK THROTTLE TO 0.

                SET burn_count TO burn_count + 1.
                SET average_period TO cumulative_period / burn_count.

                // Estimate remaining burns and total time
                SET apo_gap TO TARGET_APOAPSIS - SHIP:ORBIT:APOAPSIS.
                SET avg_apo_rise TO apo_gap / (burn_count + 1).
                SET estimated_remaining_burns TO apo_gap / avg_apo_rise.

                // Check for upcoming Mun encounter
                IF SHIP:PATCHES:LENGTH > 1 {
                    SET next_patch TO SHIP:PATCHES[1].
                    IF next_patch:BODY:NAME = "Mun" {
                        // Only handle encounters in current orbit
                        IF SHIP:OBT:NEXTPATCHETA < SHIP:ORBIT:PERIOD {
                            PRINT "Mun encounter detected within current orbit. Executing gravity assist...".
                            PERFORM_MUN_ASSIST().
                        } ELSE {
                            PRINT "Mun encounter detected in future orbit. Continuing with current burn plan.".
                        }
                    }
                }

                WAIT 1.
                PRINT "Current apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS / 1000, 0) + " km".
            }
        }
    }

    IF t_to_peri > 30 {
        PRINT "Timewarping to periapsis...".
        KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + t_to_peri - 5).
        WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
    }

    WAIT UNTIL SHIP:OBT:ETA:PERIAPSIS <= 2.
    LOCK STEERING TO PROGRADE.
    WAIT 2.

    // Calculate burn duration with growth factor
    SET BURN_DURATION TO BASE_BURN_DURATION * (BURN_GROWTH_RATE ^ burn_count).
    IF BURN_DURATION > MAX_BURN_DURATION {
        SET BURN_DURATION TO MAX_BURN_DURATION.
    }

    PRINT "Burning at periapsis to raise apoapsis (" + ROUND(BURN_DURATION, 0) + "s) with physics warp...".
    LOCK THROTTLE TO THRUST_LEVEL.
    SET KUNIVERSE:TIMEWARP:MODE TO "PHYSICS".
    SET KUNIVERSE:TIMEWARP:WARP TO 2. // 3x physics warp
    SET burn_timer TO 0.
    UNTIL burn_timer >= BURN_DURATION OR SHIP:ORBIT:ECCENTRICITY >= 0.90 {
        WAIT 1.
        SET burn_timer TO burn_timer + 1.
    }
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
    LOCK THROTTLE TO 0.

    SET burn_count TO burn_count + 1.
    SET average_period TO cumulative_period / burn_count.

    // Estimate remaining burns and total time
    SET apo_gap TO TARGET_APOAPSIS - SHIP:ORBIT:APOAPSIS.
    SET avg_apo_rise TO apo_gap / (burn_count + 1).
    SET estimated_remaining_burns TO apo_gap / avg_apo_rise.

    // Check for upcoming Mun encounter
    IF SHIP:PATCHES:LENGTH > 1 {
        SET next_patch TO SHIP:PATCHES[1].
        IF next_patch:BODY:NAME = "Mun" {
            // Only handle encounters in current orbit
            IF SHIP:OBT:NEXTPATCHETA < SHIP:ORBIT:PERIOD {
                PRINT "Mun encounter detected within current orbit. Executing gravity assist...".
                PERFORM_MUN_ASSIST().
            } ELSE {
                PRINT "Mun encounter detected in future orbit. Continuing with current burn plan.".
            }
        }
    }

    WAIT 1.
    PRINT "Current apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS / 1000, 0) + " km".
}

PRINT "Spiral escape complete or Mun assist detected. Ready for interplanetary transfer to Duna.".
PRINT "Total estimated real-time duration: " + ROUND((cumulative_period + average_period * estimated_remaining_burns) / 60, 1) + " minutes".

// Function to perform gravity assist maneuver around the Mun
DECLARE FUNCTION PERFORM_MUN_ASSIST {
    PRINT "Checking Mun encounter geometry...".

    // Locate Mun encounter patch
    LOCAL mun_patch IS "".
    FOR patch IN SHIP:PATCHES {
        IF patch:BODY = MUN {
            SET mun_patch TO patch.
            BREAK.
        }
    }
    IF mun_patch = "" {
        PRINT "No Mun encounter found. Continuing spiral-out.".
        RETURN FALSE.
    }

    // Check if we're approaching from the correct side
    // For a prograde assist, we want to pass behind the Mun
    LOCAL mun_velocity IS MUN:VELOCITY:ORBIT.
    LOCAL ship_velocity IS SHIP:VELOCITY:ORBIT.
    LOCAL approach_angle IS VANG(mun_velocity, ship_velocity).

    // We want an approach angle of roughly 150-180 degrees (approaching from behind)
    IF approach_angle < 150 {
        PRINT "Unfavorable approach angle for gravity assist (" + ROUND(approach_angle,1) + "°).".
        PRINT "Want 150-180°, got " + ROUND(approach_angle,1) + "°. Skipping assist.".
        
        // Wait one orbit with time warp
        IF SHIP:ORBIT:ECCENTRICITY < 1 {
            LOCAL wait_time IS SHIP:ORBIT:PERIOD.
            PRINT "Time warping " + ROUND(wait_time/60,1) + " minutes for next orbit.".
            KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + wait_time - 10).
            WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
            WAIT 0.2. // Let physics settle
        }
        RETURN FALSE.
    }

    PRINT "Favorable approach angle (" + ROUND(approach_angle,1) + "°). Proceeding with gravity assist.".

    // Calculate patch times (use proper suffixes for kOS 1.4+)
    LOCAL soi_entry_time IS TIME:SECONDS + SHIP:OBT:NEXTPATCHETA.
    LOCAL patch_eta IS mun_patch:ETA:TRANSITION.  // Use TRANSITION instead of SECONDS
    LOCAL pe_time IS soi_entry_time + patch_eta.

    // Check for Mun impact and correct if needed
    LOCAL mun_periapsis IS mun_patch:PERIAPSIS - MUN:RADIUS.  // Convert to altitude
    SET impact_threshold TO 5000.  // Now just the altitude above surface
    SET optimal_periapsis TO 25000.  // Now just the altitude above surface

    IF mun_periapsis <= impact_threshold {
        PRINT "Warning: Trajectory intersects Mun. Raising periapsis with prograde burn...".
        LOCAL time_to_encounter IS SHIP:OBT:NEXTPATCHETA.
        IF time_to_encounter > 660 {  // If more than 11 minutes away
            PRINT "Timewarping to 10 minutes before Mun encounter...".
            KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + time_to_encounter - 600).
            WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
            WAIT 0.2. // Let physics settle
        }
        WAIT UNTIL SHIP:OBT:NEXTPATCHETA < 600.
        
        // Burn prograde to raise periapsis
        LOCK STEERING TO PROGRADE.
        WAIT UNTIL VANG(SHIP:FACING:VECTOR, PROGRADE:VECTOR) < 5.
        
        // Always use full throttle for ion engines
        LOCK THROTTLE TO 1.0.
        WAIT UNTIL (SHIP:PATCHES[0]:PERIAPSIS - MUN:RADIUS) > impact_threshold.
        LOCK THROTTLE TO 0.
    }

    // Adjust periapsis for optimal assist
    LOCAL current_periapsis IS mun_periapsis.
    IF ABS(current_periapsis - optimal_periapsis) > 1000 {
        PRINT "Adjusting for optimal assist periapsis of " + ROUND(optimal_periapsis/1000,1) + " km".
        LOCAL time_to_encounter IS SHIP:OBT:NEXTPATCHETA.
        IF time_to_encounter > 360 {  // If more than 6 minutes away
            PRINT "Timewarping to 5 minutes before Mun encounter...".
            KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + time_to_encounter - 300).
            WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
            WAIT 0.2. // Let physics settle
        }
        WAIT UNTIL SHIP:OBT:NEXTPATCHETA < 300.
        
        // Calculate velocity relative to Mun using position changes
        LOCAL pos1 IS SHIP:POSITION.
        WAIT 0.1.
        LOCAL pos2 IS SHIP:POSITION.
        LOCAL rel_velocity IS (pos2 - pos1):NORMALIZED.
        
        // Aim along or against velocity based on whether we need to raise or lower periapsis
        IF current_periapsis < optimal_periapsis {
            LOCK STEERING TO rel_velocity.
        } ELSE {
            LOCK STEERING TO -rel_velocity.
        }
        
        // Full throttle for ion engines
        LOCK THROTTLE TO 1.0.
        WAIT UNTIL ABS((mun_patch:PERIAPSIS - MUN:RADIUS) - optimal_periapsis) < 1000.
        LOCK THROTTLE TO 0.
    }

    // Final assist boost at periapsis
    PRINT "Waiting for Mun periapsis for assist boost...".
    WAIT UNTIL TIME:SECONDS >= pe_time - 60.
    
    // Use prograde at estimated periapsis
    LOCK STEERING TO PROGRADE.
    
    // Wait for alignment
    WAIT UNTIL VANG(SHIP:FACING:VECTOR, PROGRADE:VECTOR) < 5.
    
    // Long burn for ion engines
    PRINT "Executing assist boost burn...".
    LOCK THROTTLE TO 1.0.
    WAIT UNTIL TIME:SECONDS >= pe_time + 120. // 2 minute burn for ion engines
    LOCK THROTTLE TO 0.
    
    PRINT "Assist maneuver complete. New apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS/1000,0) + " km".
    RETURN TRUE.
}



