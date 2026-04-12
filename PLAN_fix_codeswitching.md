# Plan: Fix Code-Switching in Urdu → Roman Urdu Transliteration Pipeline

## Problem
m2m100 mangles English loanwords written in Urdu script. Example:
- Input (Urdu): سپروائزر → Output: "spryzr" → Should be: "supervisor"
- Input (Urdu): پروفیشنلز → Output: "profishnlz" → Should be: "professionals"
- Pure Urdu words transliterate fine. Only English words in Urdu script break.

## Solution: 3-Layer Fix (Pre-processing → Model → Post-processing)

---

## Layer 1: Pre-Processing — Loanword Dictionary Replacement

### Step 1.1: Build an English Loanword Dictionary
Create a JSON file: `loanword_dict.json`
- Keys: English words written in Urdu script
- Values: The English word in Latin script
- Start with 500-1000 most common English loanwords used in Pakistani Urdu
- Categories to cover:
  - Tech: کمپیوٹر→computer, سافٹویئر→software, ویبسائٹ→website, پاسورڈ→password
  - Education: یونیورسٹی→university, پروفیسر→professor, سپروائزر→supervisor, اسائنمنٹ→assignment
  - Professional: پروفیشنل→professional, مینیجر→manager, آفس→office, میٹنگ→meeting
  - Daily: ٹیکسی→taxi, بس→bus, ہسپتال→hospital, ڈاکٹر→doctor, واشروم→washroom
  - Legal/Govt: کیس→case, کورٹ→court, پولیس→police, رپورٹ→report
  - Food: ریستوران→restaurant, مینیو→menu, بسکٹ→biscuit
  - Shortcuts/slang: شارٹکٹ→shortcut, کنفرم→confirm, میسج→message

### Step 1.2: Build the Pre-Processor Function
```python
def preprocess_urdu_text(urdu_text, loanword_dict):
    """
    Before sending to m2m100:
    1. Tokenize Urdu text by spaces
    2. For each token, check if it exists in loanword_dict
    3. If match found, replace with placeholder: <EN_0>, <EN_1>, etc.
    4. Store mapping: {placeholder: english_word}
    5. Return modified Urdu text + mapping
    """
    # Handle partial matches too — some loanwords appear with Urdu suffixes
    # e.g., سپروائزرز (supervisors) = سپروائزر + ز (plural marker)
    # Strip common Urdu suffixes before lookup: وں، یں، ات، ے، ی، ز
```

### Step 1.3: Build Suffix-Aware Matching
Common Urdu suffixes attached to English loanwords:
- Plural: وں، ز، یں، ات
- Possessive: کا، کی، کے
- Case: نے، کو، سے، میں

Strip these before dictionary lookup, preserve them for reconstruction.

---

## Layer 2: Post-Processing — Phonetic Fuzzy Matching

For loanwords NOT caught by the dictionary (the dictionary won't cover everything):

### Step 2.1: Build a Phonetic Correction Function
```python
def fix_mangled_english(roman_urdu_text, english_vocab):
    """
    After m2m100 output:
    1. Split into words
    2. For each word, check if it looks like mangled English:
       - Contains no standard Urdu phonetic patterns
       - Has consonant clusters unusual in Urdu (spr, str, ngl, etc.)
       - Has no vowels or very few vowels relative to length
    3. If flagged, run phonetic similarity against english_vocab:
       - Use Soundex or Metaphone algorithm
       - Also use edit distance (Levenshtein) with threshold
       - Use jellyfish or fuzzy wuzzy library
    4. If confidence > threshold, replace with English word
    """
```

### Step 2.2: English Vocabulary Source
- Use NLTK's `words` corpus (~235K English words) as base
- Add domain-specific terms (tech, education, medical)
- Weight common Pakistani-English vocabulary higher

### Step 2.3: Detection Heuristics for "Mangled English"
A word is likely mangled English if:
- 3+ consonants in a row with no vowel (spryzr, shrtkts)
- Word length > 4 and vowel ratio < 0.2
- Contains patterns like: zr, shn, fsh, kts, mnt
- Does NOT match common Roman Urdu patterns

---

## Layer 3: Placeholder Reconstruction

### Step 3.1: Reconstruct Final Output
```python
def reconstruct_output(roman_urdu_output, placeholder_mapping):
    """
    1. Replace <EN_0>, <EN_1>, etc. with stored English words
    2. Run Layer 2 (phonetic fix) on remaining words
    3. Return final clean Roman Urdu text
    """
```

---

## Implementation Order

### File Structure
```
romasub_ai/
├── transliteration/
│   ├── __init__.py
│   ├── loanword_dict.json          # 500-1000 entries
│   ├── preprocess.py               # Layer 1: dictionary replacement
│   ├── postprocess.py              # Layer 2: phonetic fuzzy matching
│   ├── pipeline.py                 # Full pipeline: preprocess → m2m100 → postprocess
│   └── utils.py                    # Suffix stripping, detection heuristics
```

### Task 1: Generate loanword_dict.json
- Generate a comprehensive dictionary of 500-1000 common English words used in Pakistani Urdu
- Format: {"Urdu_script": "english_word"}
- Use web search or your knowledge of Pakistani English loanwords
- Include spelling variants (some loanwords have multiple Urdu spellings)

### Task 2: Build preprocess.py
- `load_loanword_dict()` — load JSON
- `strip_urdu_suffix(word)` — remove common suffixes
- `preprocess_urdu_text(text, dict)` — returns (modified_text, placeholder_map)
- Handle edge cases: words at sentence boundaries, punctuation

### Task 3: Build postprocess.py
- `is_mangled_english(word)` — heuristic detection
- `find_closest_english(word, vocab)` — phonetic + edit distance matching
- `postprocess_roman_urdu(text, vocab)` — fix remaining mangled words
- Use `jellyfish` library for Soundex/Metaphone
- Use `rapidfuzz` for fast fuzzy matching

### Task 4: Build pipeline.py
- `transliterate(urdu_text, model, tokenizer)` — full pipeline
- Integrate with existing m2m100 inference code
- Add confidence scores for replacements
- Add logging so user can see what was auto-corrected

### Task 5: Test with the sample text from the user
Test input:
```
ںیہ ںیقیرط نیت ےک ےنرک سیک کوب کیم وس ںیہ ےترک سیک کوب کیم ےہ وج گول مہ حرط سک ہک اگ ںؤاتب وک پآ ںیم جآ
```
Expected: loanwords like "case", "confirm", "professionals", "shortcuts", "supervisor", "washroom", "chamber" should come through correctly.

### Task 6: Evaluate improvement
- Run on same test set
- Compare BLEU/CER before and after post-processing
- Report percentage of words corrected

---

## Dependencies to Install
```
pip install jellyfish rapidfuzz nltk
```

## Notes
- The loanword dictionary is the highest ROI fix — it handles 60-70% of errors
- Phonetic matching is the safety net for words not in the dictionary
- This is a PRACTICAL fix suitable for an FYP, not a research contribution
- In the FYP report, frame this as a "code-switching aware transliteration pipeline"
