from pathlib import Path
from datetime import datetime
import shutil

def backup_kerbals_db(db_path="kerbals.json", backup_dir="../backups"):
    backup_dir = Path(backup_dir)
    backup_dir.mkdir(exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup_file = backup_dir / f"kerbals_backup_{timestamp}.json"

    shutil.copy2(db_path, backup_file)
    print(f"Backup created at {backup_file}")

if __name__ == "__main__":
    backup_kerbals_db()
    print("Kerbal database backup complete.")