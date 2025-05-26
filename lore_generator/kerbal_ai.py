import os
import json
from typing import Dict
import openai

# Load API key from environment variable
openai.api_key = os.getenv("OPENAI_API_KEY")

def generate_kerbal_profile(name: str, role: str, model="gpt-4o") -> Dict:
    prompt = f"""
You are helping to generate personality profiles for Kerbonauts in a humorous and slightly absurd space program. For each Kerbal, produce a unique, colorful character profile with the following attributes.

Use a light narrative tone that matches the quirky, bold spirit of the Kerbal universe. The responses should be imaginative, cohesive, and playable in a character-driven simulation. If needed, invent creative backstories or traits that still feel grounded in Kerbal Space Program lore.

Only use plain ASCII characters (e.g., ' instead of ’).

### Input
Name: {name}
Role: {role}

### Output
{{
  "alignment": "",
  "ego": "",
  "impulsiveness": "",
  "curiosity": "",
  "patience": "",
  "expertise_area": "",
  "training_level": "",
  "flight_style": "",
  "leadership_style": "",
  "nightmares": "",
  "preferred_environment": "",
  "beliefs": "",
  "theme_music": "",
  "quotes": "",
  "pet_peeve": "",
  "snack_preference": "",
  "appearance": "",
  "quirks": [],
  "fears": [],
  "hobby": "",
  "hearts_desire": "",
  "past_secret": "",
  "retirement_plans": "",
  "previous_job": "",
  "university_attended": "",
  "favorite_vacation_spot": "",
  "stress_response": "",
  "famous_for": "",
  "nickname": ""
}}
    """

    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "user", "content": prompt}
        ],
        temperature=1.0,
    )

    try:
        content = response.choices[0].message.content
        if content:
            return json.loads(content)
    except Exception as e:
        print("Error parsing response:", e)
        print("Raw response:", response)
    return {}

def generate_kerbal_story(crew_traits: Dict[str, Dict], event: str, summary: str) -> str:
    crew_descriptions = "\n".join(
        [f"- {name} ({traits['role']}): {traits.get('personality', '')}" for name, traits in crew_traits.items()]
    )
    prompt = f"""
Using the following crew details, write a short, funny, lore-friendly story (1 paragraph max) about the incident below:

Crew:
{crew_descriptions}

Event: {event}
Summary: {summary}

Only return the story paragraph as plain text.
    """

    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt.strip()}],
        temperature=0.9
    )

    return response.choices[0].message.content.strip()


if __name__ == "__main__":
    # Example usage
    kerbal_name = "Jebediah Kerman"
    kerbal_role = "Pilot"
    profile = generate_kerbal_profile(kerbal_name, kerbal_role)
    print(json.dumps(profile, indent=2))

    # crew_traits = {
    #     "Jebediah Kerman": {"role": "Pilot", "personality": "Fearless and slightly reckless"},
    #     "Bill Kerman": {"role": "Engineer", "personality": "Cautious and methodical"},
    #     "Bob Kerman": {"role": "Scientist", "personality": "Curious and adventurous"}
    # }
    # event = "A mishap during a routine launch"
    # summary = "The rocket almost tipped over but was saved at the last second."
    # story = generate_kerbal_story(crew_traits, event, summary)
    # print(story)