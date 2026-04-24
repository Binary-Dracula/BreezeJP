import json
import os

source_file = "data/test_output.json"
aligned_file = "data/test_output_aligned.json"

print("Reading source JSON with original text...")
with open(source_file, "r", encoding="utf-8") as f:
    source_data = json.load(f)

print("Reading aligned JSON with translations...")
with open(aligned_file, "r", encoding="utf-8") as f:
    aligned_data = json.load(f)

for aligned_article in aligned_data:
    aid = aligned_article["id"]
    # Find matching source article
    source_article = next((a for a in source_data if a["id"] == aid), None)
    if not source_article:
        continue
    
    paragraphs = source_article["paragraphs"]
    items = aligned_article.get("items", [])
    
    # Restore the exact original text string from the paragraphs
    for i, item in enumerate(items):
        if i < len(paragraphs):
            original_text = paragraphs[i]
            if item["text"] != original_text:
                print(f"Fixing text mismatch in {aid} index {i}:")
                print(f"  Old (corrupted): {item['text']}")
                print(f"  New (original):  {original_text}")
                item["text"] = original_text

with open(aligned_file, "w", encoding="utf-8") as f:
    json.dump(aligned_data, f, ensure_ascii=False, indent=2)

print("Text restored successfully.")
