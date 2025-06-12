RUN "execute_maneuver.ks".
LIST NODES IN mynodes.
IF mynodes:LENGTH > 0 {
    execute_maneuver_node(mynodes[0]).
}