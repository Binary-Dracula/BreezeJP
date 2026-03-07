import json
import os
import requests
from bs4 import BeautifulSoup
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

# Known tags to normalize against to avoid garbage text
VALID_TAGS = {"FAIRLY COMMON", "FREQUENT", "ESSENTIAL"}

def fetch_frequency_tag(item):
    url = item.get('url')
    if not url:
        return item, None
        
    try:
        response = requests.get(url, timeout=10, headers={'User-Agent': 'Mozilla/5.0'})
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Strategy: find all links that point to /tag/
        tag_links = soup.find_all('a', href=lambda h: h and '/tag/' in h)
        
        for link in tag_links:
            text = link.text.strip().upper()
            if text in VALID_TAGS:
                return item, text
                
        # Fallback strategy: find spans inside the post-tags section
        post_tags = soup.find('p', class_='post-tags')
        if post_tags:
            for span in post_tags.find_all('span'):
                text = span.text.strip().upper()
                if text in VALID_TAGS:
                    return item, text
                    
        return item, None
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return item, None

def process_single(item, idx, total, lock, file_path, data):
    if 'frequency_tag' in item and item['frequency_tag'] is not None:
        return True
        
    print(f"Fetching tag [{idx+1}/{total}]: {item['grammar']}")
    
    _, tag = fetch_frequency_tag(item)
    
    if tag:
        # We successfully grabbed the tag text
        item['frequency_tag'] = tag
        # Remove the old incorrect boolean
        if 'essential' in item:
            del item['essential']
            
        with lock:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--> Saved progress after item {item['grammar']} ({idx+1}/{total}) -> Tag: {tag}")
            
        return True
    else:
        # If it genuinely doesn't have a frequency tag on the site
        item['frequency_tag'] = None
        if 'essential' in item:
            del item['essential']
            
        with lock:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Failed to find frequency tag for {item['grammar']}, set to None")
        return False

def main():
    file_path = 'raw_grammar_data.json'
    if not os.path.exists(file_path):
        print(f"File {file_path} not found.")
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    total = len(data)
    lock = Lock()
    
    print(f"Starting to fetch frequency tags for {total} items...")
    
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = []
        for i, item in enumerate(data):
            futures.append(executor.submit(process_single, item, i, total, lock, file_path, data))
                
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:
                print(f"Exception: {exc}")

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Frequency tag fetching completed.")

if __name__ == "__main__":
    main()
