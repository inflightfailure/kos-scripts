RUN "execute_maneuver.ks".
IF ALLNODES:LENGTH > 0 {
    execute_maneuver_node(ALLNODES[0]).
}