// time_at_true_anomaly.ks
//
// This function calculates the UT (Universal Time) at which a spacecraft
// in an elliptical orbit will reach a specified true anomaly (in degrees).
//
// This is useful for timing burns at precise orbital locations like maneuver nodes,
// even with low-thrust engines or multi-pass burn strategies.
//
// Example usage:
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
