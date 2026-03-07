import json
import os
import requests
from bs4 import BeautifulSoup
import time

def fetch_tags_for_level(level_n):
    # Depending on the website, it might be /jlpt-n5-grammar/ or /grammar/jlpt-n5/
    url = f'https://jlptbenkyo.com/jlpt-n{level_n}-grammar/'
    print(f"Fetching list for N{level_n} from {url}")
    
    # We will build a mapping of { 'grammar title': 'frequency_tag' }
    mapping = {}
    
    try:
        response = requests.get(url, timeout=10, headers={'User-Agent': 'Mozilla/5.0'})
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # The grammar lists are usually in tables (<tr> elements) or lists
        rows = soup.find_all('tr')
        for row in rows:
            title_elem = row.find('a')
            if not title_elem:
                continue
                
            grammar_title = title_elem.text.strip()
            
            # The frequency is inside a span inside the row
            tag_elem = row.find('span', class_=lambda c: c and 'tag' in c)
            if tag_elem:
                tag_text = tag_elem.text.strip().upper()
                if 'JLPT' not in tag_text:
                    mapping[grammar_title] = tag_text
                    
        print(f"✅ Found {len(mapping)} tagged items in N{level_n}")
        return mapping
    except Exception as e:
        print(f"Error fetching N{level_n} list: {e}")
        return mapping

def main():
    file_path = 'raw_grammar_data.json'
    if not os.path.exists(file_path):
        print(f"File {file_path} not found.")
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    print(f"Loaded {len(data)} items to patch.")
    
    master_tag_mapping = {}
    for level in range(1, 6):
        level_map = fetch_tags_for_level(level)
        master_tag_mapping.update(level_map)
        time.sleep(2)
        
    print(f"\nTotal mappings found across all levels: {len(master_tag_mapping)}")
    
    patched_count = 0
    for item in data:
        # Check by exact string, or you could do a more fuzzy match if needed
        g_title = item.get('grammar')
        
        # Cleanup old boolean if it exists
        if 'essential' in item:
            del item['essential']
            
        # Default value
        item['frequency_tag'] = None
            
        # Try to find the tag
        if g_title in master_tag_mapping:
            item['frequency_tag'] = master_tag_mapping[g_title]
            patched_count += 1
            
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print(f"\nSuccessfully patched {patched_count} items with string frequency tags.")
    print("Items without tags were set to null.")

if __name__ == "__main__":
    main()
