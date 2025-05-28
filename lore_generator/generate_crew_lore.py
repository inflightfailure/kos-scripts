from tinydb import TinyDB, Query
from pathlib import Path
import time

# Update these paths to match your KSP save structure
SCRIPT_DIR = Path(".") / "scripts"
CREW_FILE = SCRIPT_DIR / "crewlist.txt"
LORE_FILE = SCRIPT_DIR / "crew_lore.txt"
KERBAL_DB_PATH = Path("kerbals.json")  # Your TinyDB path
POLL_INTERVAL = 1.0  # seconds


def load_crew_names(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]

def load_kerbal_profile(db: TinyDB, name: str):
    Kerbal = Query()
    return db.table("kerbals").get(Kerbal.name == name)

def write_crew_lore(path: Path, crew_data):
    with path.open("w", encoding="utf-8") as f:
        for name, profile in crew_data:
            if profile:
                f.write(f"=== {name} ({profile.get('trait', 'Unknown')}) ===\n")
                f.write(f"Quotes: {profile.get('quotes', 'N/A')}\n")
                f.write(f"Hobby: {profile.get('hobby', 'N/A')}\n")
                f.write(f"Fears: {', '.join(profile.get('fears', []))}\n")
                f.write(f"Quirks: {', '.join(profile.get('quirks', []))}\n")
                f.write(f"Famous for: {profile.get('famous_for', 'N/A')}\n")
                f.write("\n")
            else:
                f.write(f"=== {name} ===\n")
                f.write("⚠️ No profile found in kerbals.json\n\n")
    print(f"✅ Lore written to: {path}")

# --- WATCH LOOP ---

def watch_for_crewlist():
    db = TinyDB(KERBAL_DB_PATH)

    print(f"📡 Watching for {CREW_FILE} ...")
    try:
        while True:
            if CREW_FILE.exists():
                print(f"📄 Found {CREW_FILE.name}, generating lore...")
                try:
                    crew_names = load_crew_names(CREW_FILE)
                    crew_data = [(name, load_kerbal_profile(db, name)) for name in crew_names]
                    write_crew_lore(LORE_FILE, crew_data)
                except Exception as e:
                    print(f"❌ Error: {e}")
                print(f"🕓 Waiting for {CREW_FILE.name} to be deleted before next round...")
                while CREW_FILE.exists():
                    time.sleep(POLL_INTERVAL)
                print(f"🗑️ {CREW_FILE.name} deleted. Ready to watch again.")
            time.sleep(POLL_INTERVAL)
    except KeyboardInterrupt:
        print("👋 Exiting watcher.")

if __name__ == "__main__":
    watch_for_crewlist()
