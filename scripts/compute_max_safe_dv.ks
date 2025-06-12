// compute_max_safe_dv.ks
// Function to compute the maximum safe delta-v for a periapsis burn

DECLARE FUNCTION compute_max_safe_dv {
    PARAMETER burn_dv_limit.
    PARAMETER mu_val.
    PARAMETER r_per_val.
    PARAMETER v_per_vector.
    PARAMETER burn_dir_vector.
    PARAMETER dv_step.
    PARAMETER safe_periapsis.

    SET sim_dv TO 0.

    UNTIL sim_dv >= burn_dv_limit {
        SET scaled_burn TO burn_dir_vector * sim_dv.
        SET test_velocity_vector TO v_per_vector + scaled_burn.
        SET speed TO test_velocity_vector:MAG.
        SET energy TO (speed^2 / 2) - (mu_val / r_per_val).
        SET sma TO -mu_val / (2 * energy).
        SET ecc TO ABS(1 - (r_per_val * speed^2) / mu_val).
        SET peri TO sma * (1 - ecc).

        IF peri < safe_periapsis {
            BREAK.
        }

        SET sim_dv TO sim_dv + dv_step.
    }

    RETURN sim_dv.
}