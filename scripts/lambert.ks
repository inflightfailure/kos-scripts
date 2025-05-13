FUNCTION LAMBERT_TRANSFER {
  PARAMETER r1, r2, tof.

  SET mu TO BODY("Sun"):MU.
  SET r1mag TO r1:MAG.
  SET r2mag TO r2:MAG.
  SET cosTheta TO VDOT(r1, r2) / (r1mag * r2mag).
  SET theta TO ARCCOS(cosTheta).

  SET A TO SIN(theta) * SQRT(r1mag * r2mag / (1 - COS(theta))).

  IF A = 0 OR r1mag = 0 OR r2mag = 0 {
    RETURN NONE. // Invalid geometry
  }

  // Iterative solution
  SET x TO 0.5.
  SET maxIters TO 20.
  SET epsilon TO 0.0001.

  LOCAL solved TO FALSE.
  LOCAL y IS 0.

  FOR i IN RANGE(0, maxIters) {
    SET z TO x^2.

    IF z > 0 {
      SET C TO (1 - COS(SQRT(z))) / z.
      SET S TO (SQRT(z) - SIN(SQRT(z))) / (SQRT(z)^3).
    } ELSE IF z < 0 {
      SET C TO (1 - COSH(SQRT(-z))) / z.
      SET S TO (SINH(SQRT(-z)) - SQRT(-z)) / ((-SQRT(-z))^3).
    } ELSE {
      SET C TO 0.5.
      SET S TO 1/6.
    }

    SET y TO r1mag + r2mag + A * (z * S - 1) / SQRT(C).
    IF y < 0 OR C = 0 {
      RETURN NONE. // Divergence or singularity
    }

    SET F TO (y / C)^1.5 * S + A * SQRT(y) - SQRT(mu) * tof.
    SET dFdx TO (y / C)^1.5 * (0.5 / x * (C - 3*S / (2*C))) + A / 8 * (3*S / C - 1) * SQRT(y).

    IF dFdx = 0 {
      RETURN NONE. // Derivative singularity
    }

    SET dx TO F / dFdx.
    SET x TO x - dx.

    IF ABS(dx) < epsilon {
      SET solved TO TRUE.
      BREAK.
    }
  }

  IF NOT solved OR y <= 0 {
    RETURN NONE. // Did not converge
  }

  // Final solve
  SET f TO 1 - y / r1mag.
  SET g TO A * SQRT(y / mu).
  SET gdot TO 1 - y / r2mag.

  IF g = 0 {
    RETURN NONE. // Invalid result
  }

  SET v1 TO (r2 - (r1 * f)) / g.
  RETURN v1.
}
