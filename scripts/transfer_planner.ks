// Main interplanetary transfer planner
// Depends on: lambert.ks (place in same directory)

RUNPATH("lambert.ks").

// Function to plan the transfer
FUNCTION PLAN_TRANSFER {
  PARAMETER destinationName. // Destination body name as a parameter

  // Set the origin to the current body
  SET origin TO BODY(SHIP:BODY:NAME).

  // Set the target to the destination body provided as a parameter
  SET target TO BODY(destinationName).

  SET max_dv TO 2000. // m/s
  SET latest_arrival TO TIME:SECONDS + 3*365*24*3600 + 100*24*3600. // Year 3 Day 100

  SET transferOptions TO LIST().
  SET optionNum TO 0.

  PRINT "Scanning transfer options from " + origin:NAME + " to " + target:NAME + "...".

  FROM {LOCAL departureOffset IS 10*24*3600.} UNTIL departureOffset > 60*24*3600 STEP {SET departureOffset TO departureOffset + 3*24*3600.} DO {
    SET departure TO TIME:SECONDS + departureOffset.

    FROM {LOCAL flightTime IS 120*24*3600.} UNTIL flightTime > 280*24*3600 STEP {SET flightTime TO flightTime + 10*24*3600.} DO {
      SET arrival TO departure + flightTime.

      // Skip this iteration if arrival is after the latest arrival time
      IF arrival > latest_arrival {
        // Skip to the next iteration
        LOCK flightTime TO flightTime + 10*24*3600.
        LOCK departureOffset TO departureOffset + 3*24*3600.
      }
      SET r1 TO VESSEL:ORBIT:POSITIONAT(departure).
      SET r2 TO target:ORBIT:POSITIONAT(arrival).

      SET desiredVel TO LAMBERT_TRANSFER(r1, r2, flightTime).
      IF desiredVel = FALSE {
        // Skip to the next iteration
        LOCK flightTime TO flightTime + 10*24*3600.
        LOCK departureOffset TO departureOffset + 3*24*3600.
      }

      SET currentVel TO VESSEL:ORBIT:VELOCITYAT(departure).
      SET burnVec TO desiredVel - currentVel.
      SET dv TO burnVec:MAG.

      // Skip this iteration if delta-v exceeds the maximum allowed
      IF dv > max_dv {
        // Skip to the next iteration
        LOCK flightTime TO flightTime + 10*24*3600.
        LOCK departureOffset TO departureOffset + 3*24*3600.
      }

      SET option TO LEXICON().
      option:Add("index", optionNum).
      option:Add("departure", departure).
      option:Add("arrival", arrival).
      option:Add("dv", dv).
      option:Add("flightTime", flightTime).
      option:Add("burnVec", burnVec).
      transferOptions:PUSH(option).
      SET optionNum TO optionNum + 1.
    }
  }

  IF transferOptions:LENGTH = 0 {
    PRINT "No valid transfer options found within constraints.".
    PRINT "Exiting script due to no valid transfer options.".
    WAIT 0. // Prevent further execution
  }
  PRINT "Done. " + transferOptions:LENGTH + " options found.".
  RETURN transferOptions.
}

// Main script execution
PARAMETER destinationName. // Destination body name as a parameter

SET transferOptions TO PLAN_TRANSFER(destinationName).
IF transferOptions = FALSE {
  PRINT "No valid transfer options found. Exiting.".
  WAIT 0. // Prevent further execution
}

PRINT "---------------------------".
FOR opt IN transferOptions {
  PRINT "[" + opt["index"] + "] Depart in: " + ROUND((opt["departure"] - TIME:SECONDS)/3600/24,1) + " days, "
        + "Flight time: " + ROUND(opt["flightTime"]/3600/24,1) + " days, "
        + "DV: " + ROUND(opt["dv"],1) + " m/s".
}

PRINT "---------------------------".
PRINT "Enter option number to select:".
SET sel TO -1.
UNTIL sel >= 0 AND sel < transferOptions:LENGTH {
  SET sel TO FLOOR(TERMINAL:INPUT("Option number:")).
}

SET chosen TO transferOptions[sel].
PRINT "Chosen transfer: depart in " + ROUND((chosen["departure"] - TIME:SECONDS)/3600/24,1) + " days, "
    + "arrive in " + ROUND(chosen["flightTime"]/3600/24,1) + " days, "
    + "DV: " + ROUND(chosen["dv"],1) + " m/s".

SET burnEta TO chosen["departure"] - TIME:SECONDS.
SET burnNode TO NODE(burnEta, chosen["burnVec"]).
VESSEL:NODES:ADD(burnNode).
PRINT "Maneuver node created.".
