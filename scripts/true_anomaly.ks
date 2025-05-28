// true_anomaly.ks
//
// This function calculates the UT (Universal Time) at which a spacecraft
// in an elliptical orbit will reach a specified true anomaly (in degrees).
//
// This is useful for timing burns at precise orbital locations like maneuver nodes,
// even with low-thrust engines or multi-pass burn strategies.
//
// Example usage:
// RUN "time_at_true_anomaly.ks".
// SET TA_TARGET TO NODE:ORBIT:TRUEANOMALY.
// SET NEXT_PASS_UT TO time_at_true_anomaly(TA_TARGET, SHIP:ORBIT, BODY:MU).
// PRINT "Will reach true anomaly " + TA_TARGET + " deg at UT: " + NEXT_PASS_UT.

DECLARE FUNCTION time_at_true_anomaly {
    PARAMETER true_anomaly_deg. // Desired orbital angle (degrees from periapsis)
    PARAMETER orbit_struct.     // The ORBIT structure to analyze (e.g., SHIP:ORBIT)
    PARAMETER mu_val.           // Standard gravitational parameter of the body (e.g., BODY:MU)

    // === Orbital Elements ===
    SET ecc TO orbit_struct:ECCENTRICITY.       // Orbital eccentricity
    SET sma TO orbit_struct:SEMIMAJORAXIS.      // Semi-major axis (in meters)
    SET T0 TO orbit_struct:EPOCH.               // Time (UT) of reference epoch
    SET M0 TO orbit_struct:MEANANOMALYATEPOCH.  // Mean anomaly at epoch (degrees)

    // === Step 1: Convert True Anomaly to Eccentric Anomaly ===
    // This uses the trigonometric relation between true anomaly (ν) and eccentric anomaly (E)
    // for elliptical orbits: cos(E) = (e + cos(ν)) / (1 + e * cos(ν))
    SET ta_rad TO true_anomaly_deg * CONSTANT:DEGTORAD.
    SET cos_e TO (ecc + COS(ta_rad)) / (1 + ecc * COS(ta_rad)).
    SET ecc_anom_rad TO ARCCOS(cos_e). // Result in radians

    // === Step 2: Convert Eccentric Anomaly to Mean Anomaly ===
    // Kepler's equation (in radians): M = E - e * sin(E)
    SET mean_anom_rad TO ecc_anom_rad - ecc * SIN(ecc_anom_rad).
    SET mean_anom_deg TO mean_anom_rad * CONSTANT:RADTODEG.

    // === Step 3: Calculate Mean Motion (n) ===
    // n = average angular speed in degrees per second: √(μ / a³)
    SET n TO SQRT(mu_val / (sma ^ 3)) * CONSTANT:RADTODEG.

    // === Step 4: Compute Time Since Epoch to Reach Desired Mean Anomaly ===
    // ΔM = target mean anomaly - M0 (wrap if negative)
    SET delta_m TO mean_anom_deg - M0.
    IF delta_m < 0 {
        SET delta_m TO delta_m + 360. // Wrap around orbit
    }

    // Time to traverse ΔM degrees at mean motion n
    SET time_since_epoch TO delta_m / n.

    // === Step 5: Final Absolute Time (UT) ===
    // Add elapsed time to epoch to get target UT
    SET target_ut TO T0 + time_since_epoch.

    RETURN target_ut.
}

// Example usage:
// SET TGO TO TIME:SECONDS + 240. // 4 minutes from now
// SET TA_AT_TGO TO true_anomaly_at_time(TGO, SHIP:ORBIT, BODY:MU).
// PRINT "True anomaly at UT " + TGO + ": " + ROUND(TA_AT_TGO, 2) + " degrees".


DECLARE FUNCTION true_anomaly_at_time {
    PARAMETER target_ut.         // Desired time (UT)
    PARAMETER orbit_struct.      // e.g., SHIP:ORBIT
    PARAMETER mu_val.            // e.g., BODY:MU

    // Orbital elements
    SET ecc TO orbit_struct:ECCENTRICITY.
    SET sma TO orbit_struct:SEMIMAJORAXIS.

    // Mean anomaly at time
    SET M_RAD TO orbit_struct:MEANANOMALYATEPOCH * CONSTANT:DEGTORAD.

    // === Solve Kepler's Equation numerically: M = E - e*sin(E) ===
    // Use Newton-Raphson iteration to find Eccentric Anomaly (E)
    SET E TO M_RAD. // initial guess
    SET delta TO 1.
    SET threshold TO 0.00001.

    UNTIL ABS(delta) < threshold {
        SET f TO E - ecc * SIN(E) - M_RAD.
        SET f_prime TO 1 - ecc * COS(E).
        SET delta TO f / f_prime.
        SET E TO E - delta.
    }

    // === Convert Eccentric Anomaly to True Anomaly ===
    SET cos_TA TO (COS(E) - ecc) / (1 - ecc * COS(E)).
    SET sin_TA TO (SQRT(1 - ecc^2) * SIN(E)) / (1 - ecc * COS(E)).
    SET true_anomaly_rad TO ARCTAN2(sin_TA, cos_TA).

    // Normalize angle to 0–360 degrees
    IF true_anomaly_rad < 0 {
        SET true_anomaly_rad TO true_anomaly_rad + (2 * CONSTANT:PI).
    }

    SET true_anomaly_deg TO true_anomaly_rad * CONSTANT:RADTODEG.

    RETURN true_anomaly_deg.
}
