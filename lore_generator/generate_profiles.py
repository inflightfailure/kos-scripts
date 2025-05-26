from tinydb import TinyDB, Query
from kerbal_ai import generate_kerbal_profile

def enrich_kerbals_with_profiles(db_path="kerbals.json"):
    db = TinyDB(db_path)
    kerbals = db.table("kerbals")
    Kerbal = Query()

    for k in kerbals.all():
        name = k["name"]
        role = k.get("trait", "Unknown")

        # Check if already profiled (use any key from the profile template)
        if "alignment" in k:
            print(f"Skipping {name}, profile already exists.")
            continue

        print(f"Generating profile for {name} ({role})...")
        try:
            profile = generate_kerbal_profile(name, role)
            kerbals.update(profile, Kerbal.name == name)
            print(f"Profile for {name} added.")
        except Exception as e:
            print(f"Error generating profile for {name}: {e}")

if __name__ == "__main__":
    enrich_kerbals_with_profiles()
    print("Kerbal profiles enrichment complete.")