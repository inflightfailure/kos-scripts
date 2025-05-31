// spiral_out.ks
// Performs low-thrust spiral escape by burning at periapsis to raise apoapsis
// TODO: plan Mun assist for optimal periapsis adjustment

// Configuration constants
SET TARGET_APOAPSIS TO 6.7e10. // Approximate Duna orbit radius from Sun (in meters)
SET THRUST_LEVEL TO 1.0.
SET BASE_BURN_DURATION TO 90.
SET BURN_GROWTH_RATE TO 1.0.
SET MAX_BURN_DURATION TO 300.
SET IMPACT_THRESHOLD TO 5000.  // Mun safety altitude
SET OPTIMAL_PERIAPSIS TO 25000. // Target Mun periapsis
SET MAX_ENCOUNTER_SEARCH TO 10.       // Maximum orbit raises to find encounter

// Tracking variables
SET burn_count TO 0.
SET BURN_DURATION TO BASE_BURN_DURATION.

// Safety cleanup on abort
ON ABORT {
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
}

PRINT "Beginning spiral-out phase, searching for Mun encounter...".

// Switch to and configure map view
SET MAPVIEW TO TRUE.

// Initial orbit raising until we find good Mun encounter
LOCAL encounter_found IS FALSE.
LOCAL raise_count IS 0.

UNTIL encounter_found OR raise_count >= MAX_ENCOUNTER_SEARCH {
    // Perform small raise at periapsis
    IF PERFORM_PERIAPSIS_BURN() {
        SET raise_count TO raise_count + 1.
        
        // Check for potential Mun encounters
        IF SHIP:PATCHES:LENGTH > 1 {
            LOCAL future_patch IS SHIP:PATCHES[1].
            IF future_patch:BODY:NAME = "Mun" {
                LOCAL encounter_pe IS future_patch:PERIAPSIS - MUN:RADIUS.
                
                // Check if encounter is usable and needs adjustment
                IF encounter_pe > IMPACT_THRESHOLD {
                    SET encounter_found TO TRUE.
                    PRINT "Found Mun encounter at altitude: " + ROUND(encounter_pe/1000,1) + " km".
                    
                    // Immediate periapsis adjustment if needed
                    IF ABS(encounter_pe - OPTIMAL_PERIAPSIS) > 1000 {
                        PRINT "Adjusting encounter periapsis...".
                        LOCAL burn_direction IS PROGRADE.
                        IF encounter_pe > OPTIMAL_PERIAPSIS {
                            SET burn_direction TO RETROGRADE. // Lower periapsis by decreasing velocity
                        } ELSE {
                            SET burn_direction TO PROGRADE.   // Raise periapsis by increasing velocity
                        }
                        
                        LOCK STEERING TO burn_direction.
                        WAIT UNTIL VANG(SHIP:FACING:VECTOR, burn_direction:VECTOR) < 5.
                        
                        LOCK THROTTLE TO 0.1.  // Very gentle adjustment
                        UNTIL ABS(future_patch:PERIAPSIS - MUN:RADIUS - OPTIMAL_PERIAPSIS) < 1000 {
                            SET encounter_pe TO future_patch:PERIAPSIS - MUN:RADIUS.
                            PRINT "  Current periapsis: " + ROUND(encounter_pe/1000,1) + " km    " AT (0,12).
                            PRINT "  Target periapsis: " + ROUND(OPTIMAL_PERIAPSIS/1000,1) + " km    " AT (0,13).
                            WAIT 0.1.
                        }
                        LOCK THROTTLE TO 0.
                    }
                    BREAK.
                }
            }
        }
        
        PRINT "Orbit " + raise_count + "/" + MAX_ENCOUNTER_SEARCH + ": No useful encounter found yet.".
    }
    WAIT 1.
}

IF encounter_found {
    PRINT "Proceeding with planned Mun assist.".
    IF PERFORM_MUN_ASSIST() {
        PRINT "Mun assist successful, continuing spiral out...".
    }
}

// Main loop
UNTIL SHIP:ORBIT:APOAPSIS >= TARGET_APOAPSIS OR SHIP:ORBIT:ECCENTRICITY >= 0.90 {
    LOCAL continue_loop IS TRUE.  // Flag for loop control
    
    // Check for potential Mun encounter BEFORE periapsis burn
    IF SHIP:PATCHES:LENGTH > 1 {
        LOCAL future_patch IS SHIP:PATCHES[1].
        IF future_patch:BODY:NAME = "Mun" {
            // Calculate relative positions and velocities
            LOCAL mun_to_ship IS future_patch:POSITION - MUN:POSITION.
            LOCAL approach_vel IS SHIP:VELOCITY:ORBIT - MUN:VELOCITY:ORBIT.
            LOCAL approach_angle IS VANG(mun_to_ship, approach_vel).
            
            IF approach_angle < 150 {
                // Check if we're approaching or departing the Mun
                LOCAL current_dist IS (future_patch:POSITION - MUN:POSITION):MAG.
                WAIT 1.  // Wait longer to see clear position change
                LOCAL new_dist IS (future_patch:POSITION - MUN:POSITION):MAG.
                LOCAL closing_rate IS current_dist - new_dist.
                
                IF closing_rate > 0 {
                    PRINT "Approaching Mun at " + ROUND(closing_rate,1) + " m/s. Skipping burn.".
                    SET continue_loop TO FALSE.
                } ELSE {
                    PRINT "Moving away from Mun. Continuing burn.".
                }
            } ELSE IF SHIP:OBT:NEXTPATCHETA < SHIP:ORBIT:PERIOD {
                PRINT "Mun encounter detected within current orbit. Executing gravity assist...".
                IF PERFORM_MUN_ASSIST() {
                    PRINT "Assist complete. New apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS/1000,0) + " km".
                }
            }
        }
    }

    // Perform normal periapsis burn if no Mun interaction and loop should continue
    IF continue_loop AND PERFORM_PERIAPSIS_BURN() {
        SET burn_count TO burn_count + 1.
        
        // Check if burn created a future Mun encounter
        IF SHIP:PATCHES:LENGTH > 1 {
            LOCAL collision_patch IS SHIP:PATCHES[1].
            IF collision_patch:BODY:NAME = "Mun" {
                LOCAL future_periapsis IS collision_patch:PERIAPSIS - MUN:RADIUS.
                IF future_periapsis <= IMPACT_THRESHOLD {
                    PRINT "Warning: Burn created future Mun collision! Reverting burn...".
                    // Burn retrograde briefly to lower apoapsis
                    LOCK STEERING TO RETROGRADE.
                    WAIT UNTIL VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR) < 5.
                    LOCK THROTTLE TO 1.0.
                    WAIT 10.
                    LOCK THROTTLE TO 0.
                    UNLOCK STEERING.
                    WAIT 1. // Allow orbit calculations to update
                    SET continue_loop TO FALSE.
                }
            }
        }
        
        // Update progress only if no safety issues and loop should continue
        IF continue_loop {
            LOCAL progress IS 100 * SHIP:ORBIT:APOAPSIS / TARGET_APOAPSIS.
            PRINT "Progress: " + ROUND(progress, 1) + "%".
        }
    }
    
    IF NOT continue_loop {
        WAIT 1.
        PRINT "Current apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS / 1000, 0) + " km".
    }
}

PRINT "Spiral escape complete. Ready for interplanetary transfer to Duna.".

// Mun assist function
DECLARE FUNCTION PERFORM_MUN_ASSIST {
    LOCAL success IS FALSE.
    
    IF SHIP:BODY <> KERBIN {
        PRINT "Error: Must be in Kerbin orbit for Mun assist.".
        RETURN.
    }

    IF SHIP:AVAILABLETHRUST < 0.1 {
        PRINT "Error: No thrust available!".
        RETURN.
    }

    LOCAL mun_patch IS "".
    FOR patch IN SHIP:PATCHES {
        IF patch:BODY = MUN {
            SET mun_patch TO patch.
            BREAK.
        }
    }
    IF mun_patch = "" { RETURN FALSE. }

    LOCAL mun_periapsis IS mun_patch:PERIAPSIS - MUN:RADIUS.
    LOCAL time_to_encounter IS SHIP:OBT:NEXTPATCHETA.
    
    // Single periapsis adjustment block
    IF ABS(mun_periapsis - OPTIMAL_PERIAPSIS) > 1000 AND DEFINED mun_patch {
        IF time_to_encounter > 180 {  
            PRINT "Timewarping to 3 minutes before encounter...".
            PRINT "Current periapsis: " + ROUND(mun_periapsis/1000,1) + " km".
            PRINT "Target periapsis: " + ROUND(OPTIMAL_PERIAPSIS/1000,1) + " km".
            
            KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + time_to_encounter - 180).
            
            // Monitor time warp progress
            UNTIL KUNIVERSE:TIMEWARP:RATE = 1 {
                PRINT "  Time to encounter: " + ROUND(SHIP:OBT:NEXTPATCHETA,0) + "s" AT (0,12).
                PRINT "  Time warp rate: " + KUNIVERSE:TIMEWARP:RATE + "x" AT (0,13).
                WAIT 0.5.
            }
            
            // Verify encounter still exists
            IF NOT (SHIP:PATCHES:LENGTH > 1) OR SHIP:PATCHES[1]:BODY:NAME <> "Mun" {
                PRINT "Error: Lost Mun encounter during time warp!".
                RETURN FALSE.
            }
            
            WAIT 0.5.
            PRINT "Time warp complete. Beginning periapsis adjustment...".
        }
        
        // Calculate burn direction based on periapsis height
        LOCAL burn_direction IS PROGRADE.
        IF mun_periapsis > OPTIMAL_PERIAPSIS {
            SET burn_direction TO PROGRADE.    // Lower periapsis by increasing velocity
            PRINT "Lowering periapsis to optimal height...".
        } ELSE {
            SET burn_direction TO RETROGRADE.  // Raise periapsis by decreasing velocity
            PRINT "Raising periapsis to optimal height...".
        }
        
        // Align to burn direction
        LOCK STEERING TO burn_direction.
        LOCAL align_start IS TIME:SECONDS.
        WAIT UNTIL VANG(SHIP:FACING:VECTOR, burn_direction:VECTOR) < 5 OR TIME:SECONDS > align_start + 30.
        IF VANG(SHIP:FACING:VECTOR, burn_direction:VECTOR) >= 5 {
            PRINT "Warning: Failed to achieve proper alignment!".
            UNLOCK STEERING.
            RETURN FALSE.
        }
        
        // Execute periapsis adjustment burn
        LOCK THROTTLE TO 1.0.
        SET KUNIVERSE:TIMEWARP:MODE TO "PHYSICS".
        SET KUNIVERSE:TIMEWARP:WARP TO 2.
        
        UNTIL ABS(mun_periapsis - OPTIMAL_PERIAPSIS) < 1000 OR NOT (DEFINED mun_patch) {
            SET mun_periapsis TO mun_patch:PERIAPSIS - MUN:RADIUS.
            PRINT "  Current periapsis: " + ROUND(mun_periapsis/1000,1) + " km    " AT (0,12).
            PRINT "  Target periapsis: " + ROUND(OPTIMAL_PERIAPSIS/1000,1) + " km    " AT (0,13).
            PRINT "  Difference: " + ROUND(ABS(mun_periapsis - OPTIMAL_PERIAPSIS)/1000,1) + " km    " AT (0,14).
            WAIT 0.1.
        }
        
        SET KUNIVERSE:TIMEWARP:WARP TO 0.
        SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
    }
    
    // Adjust to optimal periapsis
    IF ABS(mun_periapsis - OPTIMAL_PERIAPSIS) > 1000 AND DEFINED mun_patch {
        IF time_to_encounter > 180 {  
            PRINT "Timewarping to Munar encounter...".  
            KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + time_to_encounter).
            
            // Monitor time warp progress
            UNTIL KUNIVERSE:TIMEWARP:RATE = 1 {
                PRINT "  Time to encounter: " + ROUND(SHIP:OBT:NEXTPATCHETA,0) + "s" AT (0,12).
                PRINT "  Time warp rate: " + KUNIVERSE:TIMEWARP:RATE + "x" AT (0,13).
                WAIT 0.5.
            }
            
            // Verify we're still on track for encounter
            IF NOT (SHIP:PATCHES:LENGTH > 1) OR SHIP:PATCHES[1]:BODY:NAME <> "Mun" {
                PRINT "Error: Lost Mun encounter during time warp!".
                RETURN FALSE.
            }
            
            WAIT 0.5.  // Increased settle time
            PRINT "Time warp complete. " + ROUND(SHIP:OBT:NEXTPATCHETA,0) + "s to encounter.".
        }
        
        LOCAL mun_relative_velocity IS SHIP:VELOCITY:ORBIT - MUN:VELOCITY:ORBIT.
        LOCAL desired_direction IS V(0,0,0).
        IF mun_periapsis < OPTIMAL_PERIAPSIS {
            SET desired_direction TO mun_relative_velocity:NORMALIZED.
        } ELSE {
            SET desired_direction TO -mun_relative_velocity:NORMALIZED.
        }
        LOCK STEERING TO desired_direction.
        
        LOCAL align_start IS TIME:SECONDS.
        PRINT "Aligning to desired direction for Mun assist burn...".
        WAIT UNTIL VANG(SHIP:FACING:VECTOR, desired_direction) < 5 OR TIME:SECONDS > align_start + 30.
        WAIT 2.
        IF VANG(SHIP:FACING:VECTOR, desired_direction) >= 5 {
            PRINT "Warning: Failed to achieve proper alignment!".
            UNLOCK STEERING.
            RETURN.
        }
        
        // Final assist burn - calculate time to Mun periapsis
        // LOCAL pe_time IS TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS.
        // PRINT "Timewarping until 1 minute before Munar periapsis burn...".
        // KUNIVERSE:TIMEWARP:WARPTO(pe_time - 20). 
        // WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
        // WAIT 0.5.  // Increased settle time
        
        LOCK STEERING TO PROGRADE.
        SET align_start TO TIME:SECONDS.
        WAIT UNTIL VANG(SHIP:FACING:VECTOR, PROGRADE:VECTOR) < 5 OR TIME:SECONDS > align_start + 30.
        IF VANG(SHIP:FACING:VECTOR, PROGRADE:VECTOR) >= 5 {
            PRINT "Warning: Failed to achieve proper alignment for Munar assist burn!".
            UNLOCK STEERING.
            RETURN.
        }
        
        LOCK THROTTLE TO 1.0.
        PRINT "Beginning gravity assist burn...".

        // Continue burn until we achieve one of:
        // 1. Sufficient energy gain (apoapsis increase)
        // 2. Risk of escape (eccentricity too high)
        // 3. Risk of capture (periapsis too low)
        UNTIL SHIP:ORBIT:APOAPSIS > TARGET_APOAPSIS OR 
            SHIP:ORBIT:ECCENTRICITY > 0.95 OR
            (DEFINED mun_patch AND mun_patch:PERIAPSIS < MUN:RADIUS + IMPACT_THRESHOLD) {
            
            PRINT "  Current apoapsis: " + ROUND(SHIP:ORBIT:APOAPSIS/1000,0) + " km    " AT (0,12).
            PRINT "  Eccentricity: " + ROUND(SHIP:ORBIT:ECCENTRICITY,3) + "    " AT (0,13).
            IF DEFINED mun_patch {
                PRINT "  Mun periapsis: " + ROUND((mun_patch:PERIAPSIS-MUN:RADIUS)/1000,1) + " km    " AT (0,14).
            }
            WAIT 0.1.
        }

        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        
        SET success TO TRUE.
    }
    
    success.
}

// Periapsis burn function
DECLARE FUNCTION PERFORM_PERIAPSIS_BURN {
    LOCAL success IS TRUE.
    
    IF SHIP:DELTAV:CURRENT < 10 {
        PRINT "Warning: Low delta-v remaining!".
        UNLOCK STEERING.
        RETURN FALSE.
    }
    
    IF SHIP:AVAILABLETHRUST < 0.1 {
        PRINT "Error: No thrust available!".
        UNLOCK STEERING.
        RETURN FALSE.
    }

    IF SHIP:OBT:ETA:PERIAPSIS > 30 {
        PRINT "Timewarping to periapsis...".
        KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + SHIP:OBT:ETA:PERIAPSIS - 5).
        WAIT UNTIL KUNIVERSE:TIMEWARP:RATE = 1.
        WAIT 0.5.  // Increased settle time
    }

    WAIT UNTIL SHIP:OBT:ETA:PERIAPSIS <= 2.
    LOCK STEERING TO PROGRADE.
    LOCAL align_start IS TIME:SECONDS.
    WAIT UNTIL VANG(SHIP:FACING:VECTOR, PROGRADE:VECTOR) < 5 OR TIME:SECONDS > align_start + 30.
    IF VANG(SHIP:FACING:VECTOR, PROGRADE:VECTOR) >= 5 {
        PRINT "Warning: Failed to achieve proper alignment!".
        UNLOCK STEERING.
        RETURN FALSE.
    }

    SET BURN_DURATION TO MIN(BASE_BURN_DURATION * (BURN_GROWTH_RATE ^ burn_count), MAX_BURN_DURATION).
    PRINT "Burning at periapsis (" + ROUND(BURN_DURATION, 0) + "s)...".
    
    LOCK THROTTLE TO THRUST_LEVEL.
    SET KUNIVERSE:TIMEWARP:MODE TO "PHYSICS".
    SET KUNIVERSE:TIMEWARP:WARP TO 2.
    
    LOCAL start_time IS TIME:SECONDS.
    UNTIL (TIME:SECONDS - start_time) >= BURN_DURATION OR SHIP:ORBIT:ECCENTRICITY >= 0.90 {
        // Check for Mun encounters during burn
        IF SHIP:PATCHES:LENGTH > 1 {
            LOCAL future_patch IS SHIP:PATCHES[1].
            IF future_patch:BODY:NAME = "Mun" {
                LOCAL future_periapsis IS future_patch:PERIAPSIS - MUN:RADIUS.
                IF future_periapsis <= IMPACT_THRESHOLD {
                    PRINT "Warning: Burn creating Mun collision! Stopping burn...".
                    SET success TO FALSE.
                    BREAK.
                }
            }
        }
        
        // Existing safety checks
        IF SHIP:ORBIT:ECCENTRICITY >= 1 {
            PRINT "Warning: Orbit is hyperbolic! Cutting thrust.".
            SET success TO FALSE.
            BREAK.
        }
        
        // Progress updates
        IF FLOOR((TIME:SECONDS - start_time) / 10) <> FLOOR((TIME:SECONDS - start_time - 0.1) / 10) {
            LOCAL progress IS MIN(100 * (TIME:SECONDS - start_time) / BURN_DURATION, 100).
            PRINT "  Burn progress: " + ROUND(progress, 1) + "%".
        }
        
        WAIT 0.1.
    }
    
    // Cleanup
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    
    IF NOT success {
        // Perform small retrograde burn to clear potential encounter
        LOCK STEERING TO RETROGRADE.
        WAIT UNTIL VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR) < 5.
        LOCK THROTTLE TO 1.0.
        WAIT 5.
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
    }
    
    success.
}



