from tinydb import TinyDB, Query
from tinydb.table import Document
from typing import List, Optional

class KerbalDB:
    def __init__(self, db_path='kerbals.json'):
        self.db = TinyDB(db_path)
        self.kerbals = self.db.table('kerbals')
        self.missions = self.db.table('missions')
        self.Kerbal = Query()
        self.Mission = Query()

    # --- Kerbal Methods ---

    def add_kerbal(self, name: str, trait: str, personality: Optional[str] = None, quirks: Optional[List[str]] = None):
        if self.kerbals.contains(self.Kerbal.name == name):
            print(f"Kerbal '{name}' already exists.")
            return
        self.kerbals.insert({
            'name': name,
            'trait': trait,
            'personality': personality,
            'quirks': quirks or [],
            'missions': 0
        })
        print(f"Added Kerbal: {name}")

    def update_kerbal(self, name: str, **kwargs):
        self.kerbals.update(kwargs, self.Kerbal.name == name)

    def get_kerbal(self, name: str):
        return self.kerbals.get(self.Kerbal.name == name)

    def list_kerbals(self):
        return self.kerbals.all()

    def increment_missions(self, name: str):
        kerbal = self.get_kerbal(name)
        if kerbal:
            new_count = kerbal['missions'] + 1
            self.update_kerbal(name, missions=new_count)

    def kerbals_by_trait(self, trait: str):
        return self.kerbals.search(self.Kerbal.trait == trait)

    # --- Mission Methods ---

    def add_mission(self, name: str, crew: List[str], success: bool, notes: str = ""):
        for k in crew:
            self.increment_missions(k)
        self.missions.insert({
            'name': name,
            'crew': crew,
            'success': success,
            'notes': notes
        })
        print(f"Added Mission: {name}")

    def list_missions(self):
        return self.missions.all()

    def missions_by_kerbal(self, kerbal_name: str):
        return self.missions.search(self.Mission.crew.any(kerbal_name))
