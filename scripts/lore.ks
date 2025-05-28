// lore.ks — Kerbal Lore Sync Script for kOS

// Writes crewlist.txt to ARCHIVE
FUNCTION write_crewlist {
    // Write the first line (or create the file)
    LOG SHIP:CREW[0]:NAME TO "crewlist.txt".

    // Append the rest of the crew
    LOCAL i IS 1.
    LOCAL f IS ARCHIVE:OPEN("crewlist.txt").
    UNTIL i >= SHIP:CREW:LENGTH {
        LOG SHIP:CREW[i]:NAME to crewlist.txt. 
        SET i TO i + 1.
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
    LOCAL f IS ARCHIVE:OPEN("crew_lore.txt").
    PRINT "📚 Crew Lore:".
    LOCAL lines IS f:READALL().
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
