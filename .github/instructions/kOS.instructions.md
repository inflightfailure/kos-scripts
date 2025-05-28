---
applyTo: '*.ks'
---

# kOS Instructions
This file contains instructions for the kOS mod in Kerbal Space Program. 

- Ensure all kOS scripts are fully compatible with kOS 1.4 or later.
- The only valid suffixes for `ETA` and `OrbitEta` are `APOAPSIS`, `PERIAPSIS`, `NEXTNODE`, and `TRANSITION`. Do not attempt to use `SECONDS` or `NEXTPATCH` as suffixes for `ETA`.
- All user defined variables should be lowercase.
- Do not clobber built-in variables. For example, do not create variables named `node`, `altitude`, `target`, or `ship`.
- Initialize variables as empty strings or with a default value to avoid unexpected behavior.
- `ALTITUDE` is never a valid suffix for `ORBIT` and should not be used as such.
- Use time warping to avoid having the player wait longer than 30 seconds for the next action to occur.