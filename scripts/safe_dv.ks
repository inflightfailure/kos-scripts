DECLARE FUNCTION compute_max_safe_dv {
    PARAMETER burn_dv_limit.
    PARAMETER mu_val.
    PARAMETER r_per_val.
    PARAMETER v_per_vector.
    PARAMETER burn_dir_vector.
    PARAMETER dv_step.
    PARAMETER safe_periapsis.

    PRINT "Computing maximum safe Δv...".

    SET safe_periapsis TO safe_periapsis + BODY:RADIUS.
    SET r_per_val TO MIN(SHIP:PERIAPSIS + BODY:RADIUS, r_val).

    SET sim_dv TO 0.

    UNTIL sim_dv >= burn_dv_limit {
        SET scaled_burn TO burn_dir_vector * sim_dv.
        SET test_velocity_vector TO v_per_vector + scaled_burn.
        SET speed TO test_velocity_vector:MAG.

        IF r_per_val <= 0 {
        PRINT "Error: invalid radius value r_per_val = " + r_per_val.
        RETURN 0.
        }

        SET energy TO (speed^2 / 2) - (mu_val / r_per_val).
        SET sma TO -mu_val / (2 * energy).
        SET ecc TO ABS(1 - (r_per_val * speed^2) / mu_val).
        SET peri TO sma * (1 - ecc).

        // Mid-burn simulation
        SET mid_dv TO sim_dv / 2.
        SET mid_velocity_vector TO v_per_vector + (burn_dir_vector * mid_dv).
        SET mid_speed TO mid_velocity_vector:MAG.
        SET mid_energy TO (mid_speed^2 / 2) - (mu_val / r_per_val).
        SET mid_sma TO -mu_val / (2 * mid_energy).
        SET mid_ecc TO ABS(1 - (r_per_val * mid_speed^2) / mu_val).
        SET mid_peri TO mid_sma * (1 - mid_ecc).

        // PRINT "Δv: " + sim_dv + ", peri: " + (peri - BODY:RADIUS) + ", mid-peri: " + (mid_peri - BODY:RADIUS).

        IF peri < safe_periapsis OR mid_peri < safe_periapsis {
            BREAK.
        }

        SET sim_dv TO sim_dv + dv_step.
    }

    RETURN sim_dv.
}