// capture_node.ks
// Function to capture parameters from a maneuver node

DECLARE FUNCTION capture_node_parameters {
    PARAMETER original_node.

    LOCAL captured_params IS LIST().
    captured_params:ADD(original_node:TIME).
    captured_params:ADD(original_node:PROGRADE).
    captured_params:ADD(original_node:NORMAL).
    captured_params:ADD(original_node:RADIALOUT).
    RETURN captured_params.
}