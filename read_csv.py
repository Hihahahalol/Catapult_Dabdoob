#! coding: utf-8
import os
import json

english_csv_contents = {}
english_csv_files = [f for f in os.listdir('text/en/') if f.endswith('.csv')]

for f in english_csv_files:
    with open(os.path.join('text/en/', f), 'r', encoding='utf-8') as infile:
        english_csv_contents[f] = infile.read()

print(json.dumps(english_csv_contents))
