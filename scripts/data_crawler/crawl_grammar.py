import requests
from bs4 import BeautifulSoup
import json
import time

BASE_URL = "https://jlptbenkyo.com"
LEVELS = ["n5", "n4", "n3", "n2", "n1"]

def get_grammar_links_for_level(level):
    links = []
    page = 1
    while True:
        url = f"{BASE_URL}/grammar/jlpt-{level}/"
        if page > 1:
            url += f"page{page}/"
        
        print(f"Fetching {url}...")
        response = requests.get(url)
        if response.status_code != 200:
            break
            
        soup = BeautifulSoup(response.text, 'html.parser')
        
        main_content = soup.find('main') or soup.find('body')
        found_links_on_page = False
        for a_tag in main_content.find_all('a', href=True):
            href = a_tag['href']
            if '/japanese-grammar/' in href and href not in links:
                links.append(href)
                found_links_on_page = True
                
        if not found_links_on_page:
            break
            
        page += 1
        time.sleep(1)
        
    return links

def parse_grammar_page(url, level):
    print(f"  Parsing {url}...")
    try:
        response = requests.get(url)
        if response.status_code != 200:
            return None
            
        soup = BeautifulSoup(response.text, 'html.parser')
        data = {}
        
        # Level
        data['level'] = level

        # Title
        h1 = soup.find('h1')
        data['grammar'] = h1.text.strip() if h1 else ''
        data['url'] = url

        # Essential Tag and Usage Frequency
        essential_div = soup.find('div', string=lambda text: text and 'ESSENTIAL' in text)
        data['essential'] = True if essential_div else False

        usage_dots = soup.find_all('div', class_='usage-dot')
        data['usage_frequency'] = len(usage_dots)

        info_cards = soup.find_all('div', class_='info-card')
        for card in info_cards:
            h2 = card.find('h2')
            if not h2: continue
            heading_text = h2.text.strip().lower()
            
            if 'definition' in heading_text:
                content_div = card.find('div', class_='text-gray-700')
                data['definition_en'] = content_div.text.strip() if content_div else ''
                
            elif 'how to use' in heading_text:
                content_div = card.find('div', class_='text-gray-700')
                data['how_to_use_en'] = content_div.text.strip() if content_div else ''
                grid = card.find('div', class_='grid-cols-1')
                if grid and not data.get('how_to_use_en'):
                    parts = [item.text.strip().replace('\n', ' ') for item in grid.find_all('div', class_='bg-gray-50')]
                    data['how_to_use_en'] = ' | '.join(parts)
                    
            elif 'context' in heading_text or 'limitations' in heading_text:
                when_to_use = ''
                limitations = []
                
                when_to_use_label = card.find('div', string=lambda t: t and 'When to use?' in t)
                if when_to_use_label:
                     parent_div = when_to_use_label.find_parent('div')
                     if parent_div:
                         next_div = parent_div.find('div', class_='text-gray-700')
                         if next_div:
                             when_to_use = next_div.text.strip()
                             
                limitations_label = card.find('div', string=lambda t: t and 'Limitations' in t)
                if limitations_label:
                     parent_div = limitations_label.find_parent('div')
                     if parent_div:
                         items = parent_div.find_all('div', class_='text-gray-700')
                         for item in items:
                             txt = item.text.strip()
                             if txt:
                                 limitations.append(txt)

                data['context_en'] = {
                    'when_to_use': when_to_use,
                    'limitations': limitations
                }

        examples = []
        header = soup.find(lambda t: t.name in ['h2', 'h3'] and 'Example Sentences' in t.text)
        if header:
            parent = header.find_parent('div')
            if parent:
                for jp_val in parent.find_all('div', class_='japanese-text'):
                     jp_text = jp_val.text.strip()
                     en_text = ''
                     block = jp_val.find_parent('div', class_=lambda c: c and ('space-y' in c or 'flex' in c))
                     if block:
                         for t in block.find_all('div', class_=lambda c: c and 'text-gray-' in c):
                             if 'italic' not in t.get('class', []) and 'hiragana-text' not in t.get('class', []):
                                 txt = t.text.strip()
                                 if txt and txt != jp_text:
                                     en_text = txt
                                     break
                     if jp_text:
                         examples.append({'japanese': jp_text, 'english': en_text})

        data['examples'] = examples
        return data
    except Exception as e:
        print(f"  Error parsing {url}: {e}")
        return None

def main():
    all_grammar_data = []
    
    for level in LEVELS:
        print(f"\nStarting level {level.upper()}...")
        links = get_grammar_links_for_level(level)
        print(f"Found {len(links)} grammar points for {level.upper()}")
        
        for link in links:
            full_link = BASE_URL + link if link.startswith('/') else link
            data = parse_grammar_page(full_link, level)
            if data:
                all_grammar_data.append(data)
            time.sleep(1) # Rate limiting
            
        # Save intermediate results
        with open('raw_grammar_data.json', 'w', encoding='utf-8') as f:
            json.dump(all_grammar_data, f, ensure_ascii=False, indent=2)
            
    print(f"\nDone! Scraped {len(all_grammar_data)} grammar points total.")

if __name__ == "__main__":
    main()
