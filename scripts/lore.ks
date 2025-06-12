// lore.ks — Kerbal Lore Sync Script for kOS

// Writes crewlist.txt to ARCHIVE using VolumeFile methods
FUNCTION write_crewlist {
    LOCAL crewfile IS ARCHIVE:OPEN("crewlist.txt").
    crewfile:CLEAR(). // Overwrite the file

    // Write each crew member's name, one per line
    FOR crew IN SHIP:CREW {
        crewfile:WRITE(crew:NAME + CHAR(13) + CHAR(10)).
    }

    PRINT "📄 crewlist.txt written with " + SHIP:CREW:LENGTH + " names.".
}


// Waits for crew_lore.txt to appear in ARCHIVE
FUNCTION wait_for_lore {
    PRINT "⌛ Waiting for crew_lore.txt to appear...".
    UNTIL ARCHIVE:EXISTS("crew_lore.txt") {
        WAIT 1.
    }
    PRINT "✅ Lore file detected!".
}

// Prints the content of crew_lore.txt
FUNCTION print_lore {
    IF NOT ARCHIVE:EXISTS("crew_lore.txt") {
        PRINT "⚠️ No lore file found.".
        RETURN.
    }
    LOCAL lorefile IS ARCHIVE:OPEN("crew_lore.txt").
    PRINT "📚 Crew Lore:".
    LOCAL lines IS lorefile:READALL().
    FOR line IN lines {
        PRINT line.
    }
}

// Complete lore sync in one call
FUNCTION show_lore {
    write_crewlist().
    wait_for_lore().
    print_lore().
}
