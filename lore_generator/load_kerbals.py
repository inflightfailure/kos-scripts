from pathlib import Path
import re

from kerbal_db import KerbalDB

KERBATTRIBUTES = [
    "name",               # Kerbal's full name (e.g. "Jebediah Kerman")
    "gender",             # "Male" or "Female"
    "type",               # "Crew", "Tourist", or "Unowned" (some may be "Applicant" in career mode)
    "trait",              # Kerbal class: "Pilot", "Engineer", "Scientist"
    "brave",              # Float (0.0 to 1.0): bravery level (affects panic/stability)
    "dumb",               # Float (0.0 to 1.0): stupidity level (humor stat, no known gameplay effect)
    "badS",               # Boolean: "Badass" flag — if True, Kerbal never panics (e.g. Jebediah)
    "veteran",            # Boolean: has the orange suit; immune to certain deaths in older versions
    "tour",               # Boolean: true if currently a tourist (e.g. after GLOC or contract tourism)
    "state",              # Status: "Available", "Assigned", "Dead", "Missing", etc.
    "inactive",           # Boolean: temporarily grounded (e.g. from G-force trauma)
    "inactiveTimeEnd",    # Time (UT) when Kerbal becomes active again
    "gExperienced",       # Boolean: has experienced high G-forces
    "outDueToG",          # Boolean: is currently incapacitated due to G-forces
    "ToD",                # Time of death (UT), if dead
    "idx",                # Internal game index (order of creation?)
    "extraXP",            # Additional experience not gained from missions
    "hasHelmetOn",        # Boolean: whether the Kerbal has helmet on during EVA
    "hasNeckRingOn",      # Boolean: suit configuration option (used in IVA/EVA rendering)
    "hasVisorDown",       # Boolean: visor state (useful for visual mods)
    "lightR",             # EVA suit helmet light red component (0–1)
    "lightG",             # Green component
    "lightB",             # Blue component
    "completeFirstEVA",   # Boolean: first-EVA tutorial/completion flag
    "suit",               # Suit type: "Default", "Vintage", "Future", etc.
    "hero"                # Boolean: True if originally one of the 4 heroic Kerbals (Jeb, Val, Bill, Bob)
]


def extract_roster_block(content: str) -> str:
    start = content.find("\tROSTER\n")
    end = content.find("\tMESSAGESYSTEM\n", start)
    if start == -1 or end == -1:
        return ""
    return content[start:end].strip()


def parse_kerbals_from_sfs(filepath):
    kerbals = []
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    roster_block = extract_roster_block(content)
    if not roster_block:
        print("ROSTER block not found or malformed.")
        return kerbals

    # Split into individual KERBAL blocks
    kerbal_blocks = re.findall(r'KERBAL\s*\{([\s\S]*?)^\s*EVACHUTE', roster_block, re.MULTILINE)

    for block in kerbal_blocks:
        kerbal = {}
        for line in block.strip().splitlines():
            for attr in KERBATTRIBUTES:
                if attr in line:
                    key, val = attr, line.split('=')[1].strip()
                    kerbal[key] = val
                    break
        kerbals.append(kerbal)
    return kerbals

# Load into DB
def import_kerbals_to_db(sfs_path):
    db = KerbalDB()
    kerbals = parse_kerbals_from_sfs(sfs_path)
    for k in kerbals:
        db.add_kerbal(k['name'], k['trait'])
    print(f"Imported {len(kerbals)} Kerbals.")

def parse_missions_from_sfs(filepath):
    missions = []
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Extract FLIGHTSTATE block
    flight_match = re.search(r'FLIGHTSTATE\s*\{([\s\S]+?)\n\}', content)
    if not flight_match:
        print("FLIGHTSTATE block not found.")
        return missions

    flight_block = flight_match.group(1)

    # Split into VESSEL blocks
    vessel_blocks = re.findall(r'VESSEL\s*\{([\s\S]*?)\n\s*\}', flight_block)

    for block in vessel_blocks:
        vessel = {}
        crew = []
        lines = block.strip().splitlines()
        for line in lines:
            line = line.strip()
            if '=' in line:
                key, val = map(str.strip, line.split('=', 1))
                if key == 'crew':
                    crew.append(val)
                else:
                    vessel[key] = val
        if crew:
            missions.append({
                'name': vessel.get('name', 'Unnamed Vessel'),
                'crew': crew,
                'landed': vessel.get('landed', 'False') == 'True',
                'body': vessel.get('ref', 'Unknown'),
                'notes': f"Status: {vessel.get('sit', 'n/a')}, Landed: {vessel.get('landed')}"
            })
    return missions

def import_missions_to_db(sfs_path):
    db = KerbalDB()
    missions = parse_missions_from_sfs(sfs_path)
    for m in missions:
        db.add_mission(
            name=m['name'],
            crew=m['crew'],
            success=m['landed'],
            notes=m['notes']
        )
    print(f"Imported {len(missions)} missions.")


# Example usage:
sfs_path = Path.home() / ".local" / "share" / "Steam" / "steamapps" / "common" / "Kerbal Space Program" / "saves" / "2025 Pre-Apocalypse" / "persistent.sfs"
import_kerbals_to_db(sfs_path)
import_missions_to_db(sfs_path)