import json
import re
import os

# Paths to files
json_file = 'TS_Save_54.json'
card_links_file = 'card_links.txt'

# Load GitHub URLs from card_links.txt
github_urls = {}
with open(card_links_file, 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            # Extract the Pokémon name from the URL
            match = re.search(r'cards/([^/]+)\.png$', line)
            if match:
                pokemon_name = match.group(1)
                # Normalize the name (lowercase, replace underscores with spaces)
                normalized_name = pokemon_name.replace('_', ' ').lower()
                github_urls[normalized_name] = line

# Load the Tabletop Simulator save file
with open(json_file, 'r', encoding='utf-8') as f:
    save_data = json.load(f)

# Function to normalize Pokémon names


def normalize_name(name):
    return name.lower().replace('_', ' ')

# Process all objects in the save file


def process_objects(objects):
    replacements_made = 0

    for obj in objects:
        if isinstance(obj, dict):
            # Check if it's a CardCustom object
            if obj.get('Name') == 'CardCustom' and 'Nickname' in obj:
                nickname = obj['Nickname']
                normalized_nickname = normalize_name(nickname)

                # Check if we have a GitHub URL for this Pokémon
                matching_key = None
                for key in github_urls:
                    if key in normalized_nickname or normalized_nickname in key:
                        matching_key = key
                        break

                # If we found a matching GitHub URL, replace the FaceURL if it exists
                if matching_key and 'CustomDeck' in obj:
                    for deck_id, deck in obj['CustomDeck'].items():
                        if 'FaceURL' in deck:
                            # Check if it's a Steam URL (don't replace already correct GitHub URLs)
                            if 'steamusercontent' in deck['FaceURL']:
                                deck['FaceURL'] = github_urls[matching_key]
                                replacements_made += 1

            # Recursively process nested objects and arrays
            for key, value in obj.items():
                if isinstance(value, (dict, list)):
                    replacements_made += process_objects([value])

        elif isinstance(obj, list):
            for item in obj:
                if isinstance(item, (dict, list)):
                    replacements_made += process_objects([item])

    return replacements_made


# Process all objects in the save file
print("Starting URL replacements...")
replacements = process_objects(save_data.get('ObjectStates', []))
print(f"Made {replacements} URL replacements")

# Write the updated save file
with open(json_file, 'w', encoding='utf-8') as f:
    json.dump(save_data, f, indent=2)

print(f"Updated {json_file} successfully!")
