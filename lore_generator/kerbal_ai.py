import os
import json
from typing import Dict
import openai

# Load API key from environment variable
openai.api_key = os.getenv("OPENAI_API_KEY")

def generate_kerbal_personality(name: str, role: str) -> Dict:
    prompt = f"""
Create a personality profile for a Kerbal named {name}, who is a {role}.
Respond in JSON format with the following keys:
- "role": (repeat the input role)
- "personality": a one-sentence summary of their personality
- "quirks": a list of 3 amusing quirks
- "fears": a list of 2 fears
- "catchphrase": a one-liner catchphrase
- "hobby": a silly hobby
    """

    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt.strip()}],
        temperature=0.8
    )

    try:
        content = response.choices[0].message.content
        return json.loads(content)
    except Exception as e:
        print("Error parsing response:", e)
        print("Raw response:", content)
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
