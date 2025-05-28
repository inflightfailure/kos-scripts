// main_transfer.ks

// --- Mission Overview ---
// Uses high-thrust engine for Oberth burn if delta-v is sufficient,
// then transitions to low-thrust spiral trajectory using ion engines.

IF SAS {
    SAS OFF.
    PRINT "SAS disabled.".
}


PRINT "Initializing interplanetary transfer...".

// --- Constants ---
SET SAFE_PERI TO 70000.
SET MU TO BODY:MU.
SET DV_STEP TO 1.0.

// --- Detect Thrust Environment ---
SET HIGH_THRUST_ENGINES TO LIST().
SET LOW_THRUST_ENGINES TO LIST().

FOR eng IN SHIP:ENGINES {
  IF eng:ISP > 800 {
    LOW_THRUST_ENGINES:ADD(eng).
  } ELSE {
    HIGH_THRUST_ENGINES:ADD(eng).
  }
}

SET high_thrust TO HIGH_THRUST_ENGINES:LENGTH > 0.
SET low_thrust TO LOW_THRUST_ENGINES:LENGTH > 0.

SET BOOSTER_DV_LIMIT TO STAGE:DELTAV:CURRENT.

IF high_thrust {
  PRINT "High-thrust phase active. Executing Oberth maneuver...".
  RUNPATH("boost_burn.ks", BOOSTER_DV_LIMIT, SAFE_PERI, DV_STEP).
} ELSE {
  PRINT "Skipping Oberth phase: no high-thrust engine available.".
}

// Stage until low-thrust engines are available
WAIT 2.
LOCAL low_thrust_ready IS FALSE.
UNTIL low_thrust_ready {
  SET low_thrust_ready TO FALSE.
  FOR eng IN SHIP:ENGINES {
    IF eng:ISP > 800 {
      SET low_thrust_ready TO TRUE.
    }
  }
  IF NOT low_thrust_ready {
    PRINT "Staging to activate low-thrust engines...".
    STAGE.
    WAIT 2.
  }
}

PRINT "Low-thrust engines detected. Switching to spiral escape profile.".
RUNPATH("spiral_out.ks").

// --- Compute and execute interplanetary transfer ---
PRINT "Planning interplanetary burn to Duna...".
RUN plan_duna_transfer.ks.


PRINT "Interplanetary transfer to Duna initiated.".
