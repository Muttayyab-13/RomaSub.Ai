# Plan: Integrate IndicXlit Word-Level Backup + Roman Urdu N-gram Spell-Checker

## Context

The RomaSub.AI pipeline currently has:
- Loanword dictionary bypass (Layer 1)
- m2m100 transliteration (Layer 2)
- Reconstruction (Layer 3)
- Post-processing fuzzy English matcher (Layer 4)

We're adding two new layers between reconstruction and fuzzy matching:
- **IndicXlit word-level backup** — re-transliterates individual suspicious Urdu words
- **N-gram spell-checker** — catches remaining misspellings in the Roman Urdu output

These are the two lowest-hanging improvements left after the loanword fix.

---

## Architecture After Integration

```
Input Urdu sentence
    │
    ├── Layer 1: Loanword dictionary (extract English words, names, multi-word)
    │             [EXISTING - no changes]
    │
    ├── Layer 2: m2m100 (transliterate pure Urdu chunks)
    │             [EXISTING - no changes]
    │
    ├── Layer 3: Reconstruct (stitch English back at original positions)
    │             [EXISTING - no changes]
    │
    ├── Layer 4: IndicXlit backup  ← NEW
    │             Uses ORIGINAL Urdu source words to re-transliterate
    │             suspicious words in m2m100 output
    │
    ├── Layer 5: N-gram spell-checker  ← NEW
    │             Scores each Roman Urdu word against learned patterns
    │             Corrects low-scoring words via vocabulary lookup
    │
    ├── Layer 6: Fuzzy English matcher (safety net for missed loanwords)
    │             [EXISTING - no changes]
    │
    └── Final Roman Urdu output
```

---

## Part A: IndicXlit Word-Level Backup

### A1. Install dependency

```
pip install ai4bharat-transliteration
```

Add `ai4bharat-transliteration` to requirements.txt

### A2. Create `app/services/indicxlit_backup.py`

This module provides word-level re-transliteration as a backup for m2m100.

#### Class: `IndicXlitBackup`

```python
class IndicXlitBackup:
    def __init__(self):
        self.engine = None  # lazy load

    def _load_engine(self):
        """Lazy-load IndicXlit engine on first use (takes a few seconds)."""
        from ai4bharat.transliteration import XlitEngine
        self.engine = XlitEngine(src_script_type="indic", beam_width=10, rescore=False)

    def transliterate_word(self, urdu_word: str, topk: int = 5) -> list[str]:
        """
        Get top-k Roman transliteration candidates for a single Urdu word.
        Returns list of candidates, e.g. ['university', 'yuniversity', 'universiti']
        """
        if self.engine is None:
            self._load_engine()
        try:
            results = self.engine.translit_word(urdu_word, lang_code="ur", topk=topk)
            return results if isinstance(results, list) else []
        except Exception:
            return []

    def should_recheck(self, roman_word: str) -> bool:
        """
        Decide if a Roman Urdu word from m2m100 looks suspicious enough
        to re-transliterate with IndicXlit.

        Suspicious signals:
        1. Very low vowel ratio (< 0.2) for words with 4+ chars
        2. 3+ consecutive consonants
        3. Single character words that aren't common (a, o, e, k, etc.)
        4. Contains unusual character sequences rarely seen in Roman Urdu
        """
        # Implementation details:
        # - vowels = set('aeiou')
        # - common_single = {'a', 'o', 'e', 'k', 'w', 'is', 'ka', 'ki', 'ke', 'na', 'ye'}
        # - Don't flag words that are in the loanword dictionary (already handled)
        # - Don't flag words shorter than 3 characters
        # - Don't flag words that are in a Roman Urdu common words whitelist

    def get_best_candidate(self, urdu_word: str, m2m100_word: str) -> str:
        """
        Compare m2m100's output with IndicXlit's candidates.

        Logic:
        1. Get top-5 candidates from IndicXlit
        2. If m2m100_word is in the candidates → m2m100 is fine, return it
        3. If m2m100_word is very similar (>85%) to top candidate → keep m2m100
        4. If m2m100_word is very different from all candidates → prefer IndicXlit top-1
        5. If IndicXlit returns empty → keep m2m100 (don't break things)

        Use rapidfuzz.fuzz.ratio for similarity comparison.
        """
```

#### Key design decisions:
- **Lazy loading**: IndicXlit engine loads on first call, not at startup. It takes a few seconds and we don't want to slow down app startup.
- **Conservative replacement**: Only replace m2m100's word if IndicXlit strongly disagrees. Default is to trust m2m100.
- **Skip words already handled**: If a word came from the loanword dictionary or names dictionary, don't touch it.

### A3. Integration into the pipeline

Modify `loanword_processor.py` (or wherever the pipeline orchestration lives):

```python
def apply_indicxlit_backup(self, roman_words: list[str], urdu_words: list[str],
                            english_positions: set[int]) -> list[str]:
    """
    For each word in the m2m100 output:
    1. Skip if position is in english_positions (already from dictionary)
    2. Skip if word looks normal (should_recheck returns False)
    3. Otherwise, get IndicXlit's opinion using the original Urdu word
    4. Replace if IndicXlit strongly disagrees with m2m100

    Parameters:
        roman_words: list of words from m2m100 output (split by space)
        urdu_words: list of original Urdu words (split by space)
        english_positions: set of indices that were loanword-matched

    Returns:
        list of corrected Roman words

    IMPORTANT: urdu_words and roman_words may not be the same length
    because m2m100 can merge or split words. Handle length mismatch:
    - If len(roman_words) == len(urdu_words): 1:1 alignment, straightforward
    - If different: only process words where we can confidently align
      (e.g., use sequence alignment or skip backup for that sentence)
    """
```

### A4. Word alignment challenge

m2m100 operates at sentence level, so its output may have different word count than the input:
- Input: "میں یونیورسٹی جا رہا ہوں" (5 words)
- Output: "mein university ja raha hoon" (5 words) ← aligned, easy
- Output: "mein universty jaraha hoon" (4 words) ← merged "ja raha", misaligned

**Solution approach:**
1. First try simple positional alignment (works most of the time)
2. If word counts don't match, use character-level alignment:
   - Transliterate each Urdu word individually with IndicXlit
   - Match IndicXlit outputs to m2m100 words using fuzzy matching
   - This tells you which Urdu word corresponds to which Roman word
3. If alignment is ambiguous, skip IndicXlit for that sentence (safe fallback)

---

## Part B: N-gram Spell-Checker

### B1. Create `app/services/spell_checker.py`

#### Class: `RomanUrduSpellChecker`

```python
class RomanUrduSpellChecker:
    def __init__(self, n=3):
        self.n = n                    # character n-gram size
        self.ngram_counts = {}        # Counter of n-grams
        self.total_ngrams = 0
        self.vocabulary = set()       # all known Roman Urdu words
        self.word_frequencies = {}    # word → count
        self.is_trained = False

    def train(self, roman_urdu_sentences: list[str]):
        """
        Train the spell-checker on Roman Urdu text from RUP dataset.

        Steps:
        1. Split each sentence into words
        2. For each word:
           a. Add to vocabulary
           b. Count word frequency
           c. Extract character n-grams with start/end markers
           d. Count n-gram frequencies
        3. Store total counts for probability calculation

        Use start marker '^^' and end marker '$$' for word boundaries.
        Example: "mein" → "^^mein$$" → trigrams: "^^m", "^me", "mei", "ein", "in$", "n$$"
        """

    def score_word(self, word: str) -> float:
        """
        Score how 'normal' a word looks in Roman Urdu. Returns 0.0 to 1.0.

        Uses average log probability of character n-grams with add-1 smoothing.
        Normalize to 0-1 range.

        High score (>0.5) = normal Roman Urdu word
        Low score (<0.3) = suspicious, possibly misspelled
        """

    def is_suspicious(self, word: str, threshold: float = 0.3) -> bool:
        """
        Returns True if word scores below threshold.

        Additional skip conditions:
        - Word length < 3 (too short to judge)
        - Word is a number or contains digits
        - Word is all uppercase (likely an acronym)
        """

    def suggest_correction(self, word: str, max_candidates: int = 5) -> str | None:
        """
        Find the closest known Roman Urdu word.

        Steps:
        1. If word is already in vocabulary → return None (no correction needed)
        2. Use rapidfuzz.process.extract against vocabulary
        3. Filter: only accept matches with similarity > 80%
        4. Among matches > 80%, prefer the one with highest word frequency
           (common words are more likely to be the intended word)
        5. Return best match, or None if no good candidate

        IMPORTANT: Limit vocabulary search to words with similar length (±2 chars)
        to speed up matching and reduce false positives.
        """

    def save(self, filepath: str):
        """Pickle the trained checker to disk."""

    @classmethod
    def load(cls, filepath: str) -> 'RomanUrduSpellChecker':
        """Load a pre-trained checker from disk."""
```

### B2. Pre-train the spell-checker (one-time script)

Create `scripts/train_spell_checker.py`:

```python
"""
One-time script to train the spell-checker on RUP data.
Run this once, saves the trained model to app/data/spell_checker.pkl

Steps:
1. Load Roman-Urdu-Parl dataset (train split only)
2. Extract all Roman-Urdu text sentences
3. Train RomanUrduSpellChecker on these sentences
4. Save to app/data/spell_checker.pkl
5. Print stats: vocabulary size, total n-grams, sample scores

This takes ~2-5 minutes on the full RUP training set.
Can also train on a subset (e.g., 500K sentences) for faster iteration.
"""
```

### B3. Create pre-trained data file

File: `app/data/spell_checker.pkl` (generated by the script above)

Alternative: If pickle is too large, store just the vocabulary + frequencies as JSON:
`app/data/roman_urdu_vocab.json`

```json
{
  "vocabulary": {
    "mein": 245000,
    "hai": 312000,
    "aap": 189000,
    "bataunga": 4500,
    ...
  }
}
```

Then build n-grams at startup from the vocabulary (lighter file, ~2-5MB vs potentially large pickle).

### B4. Integration into pipeline

Add to `loanword_processor.py`:

```python
def apply_spell_check(self, roman_text: str, english_positions: set[int]) -> str:
    """
    Score each word and correct suspicious ones.

    For each word at position i:
    1. Skip if i is in english_positions (loanword/name, don't touch)
    2. Skip if word was already corrected by IndicXlit
    3. Score with n-gram checker
    4. If score < threshold AND a good correction exists → replace
    5. Otherwise → leave as is

    Returns corrected Roman Urdu text.
    """
```

---

## Part C: Full Pipeline Flow (Updated)

Modify `transliterate_batch()` in `app/services/transliteration.py`:

```python
def transliterate_batch(texts, batch_size=8):
    processor = get_loanword_processor()
    indicxlit = get_indicxlit_backup()    # lazy-loaded singleton ← NEW
    spell_checker = get_spell_checker()    # loaded from pickle   ← NEW

    results = []
    for text in texts:
        # Layer 1: Pre-process — extract loanwords, names, multi-word
        tokens, urdu_chunks, english_map = processor.preprocess(text)

        # Layer 2: m2m100 — transliterate pure Urdu chunks
        transliterated_chunks = _m2m100_batch(urdu_chunks, batch_size)

        # Layer 3: Reconstruct — merge English words back in
        merged = processor.reconstruct(tokens, transliterated_chunks)

        # Layer 4: IndicXlit backup — re-check suspicious words ← NEW
        roman_words = merged.split()
        urdu_words = text.split()
        english_positions = set(english_map.keys())
        corrected_words = indicxlit.apply_backup(
            roman_words, urdu_words, english_positions
        )
        merged = ' '.join(corrected_words)

        # Layer 5: N-gram spell-check — fix remaining typos ← NEW
        merged = spell_checker.apply_corrections(merged, english_positions)

        # Layer 6: Fuzzy English matcher — catch remaining loanwords
        merged = processor.postprocess(merged)

        results.append(merged)

    return results
```

---

## Part D: Files to Create

| File | Purpose |
|---|---|
| `app/services/indicxlit_backup.py` | IndicXlit word-level backup class |
| `app/services/spell_checker.py` | N-gram spell-checker class |
| `scripts/train_spell_checker.py` | One-time script to train spell-checker on RUP data |
| `app/data/spell_checker.pkl` OR `app/data/roman_urdu_vocab.json` | Pre-trained spell-checker data |
| `tests/test_indicxlit_backup.py` | Tests for IndicXlit backup |
| `tests/test_spell_checker.py` | Tests for spell-checker |
| `tests/test_full_pipeline.py` | End-to-end integration tests |

## Files to Modify

| File | Change |
|---|---|
| `requirements.txt` | Add `ai4bharat-transliteration`, `rapidfuzz` (if not already) |
| `app/services/transliteration.py` | Hook new layers into `transliterate_batch()` |
| `app/services/loanword_processor.py` | Add singleton getters for new components |

---

## Part E: Tests

### E1. `tests/test_indicxlit_backup.py`

```python
"""
Test IndicXlit word-level backup.

Test cases:

1. test_normal_word_not_flagged
   - Input: roman_word="mein", urdu_word="میں"
   - Expected: should_recheck returns False (common word, leave it alone)

2. test_suspicious_word_flagged
   - Input: roman_word="btaunga"
   - Expected: should_recheck returns True (low vowel ratio)

3. test_correction_applied
   - Input: urdu_word="یونیورسٹی", m2m100_word="universty"
   - Expected: get_best_candidate returns "university"
   - IndicXlit should produce "university" as top candidate
   - Since "universty" differs from "university", correction applied

4. test_m2m100_output_preserved_when_correct
   - Input: urdu_word="پاکستان", m2m100_word="pakistan"
   - Expected: get_best_candidate returns "pakistan"
   - IndicXlit candidates should include "pakistan"
   - m2m100 output is in candidates, so keep it

5. test_empty_indicxlit_result_keeps_m2m100
   - Input: urdu_word="some_rare_word", m2m100_word="xyz"
   - Mock IndicXlit to return empty list
   - Expected: returns "xyz" (don't break things)

6. test_english_position_skipped
   - Input: english_positions={2}, word at position 2
   - Expected: word is not processed by IndicXlit (already from dictionary)

7. test_length_mismatch_handled
   - Input: urdu_words has 5 words, roman_words has 4
   - Expected: graceful handling (skip backup or partial alignment)

8. test_lazy_loading
   - Engine should not be loaded until first transliterate_word call
   - Verify self.engine is None before first call
   - Verify self.engine is not None after first call

9. test_names_not_corrupted
   - Input: urdu_word="فہد", m2m100_word="Fahad"
   - Expected: should not be changed (it's a name, already correct)

10. test_batch_performance
    - Process 100 words through should_recheck
    - Should complete in < 1 second (heuristic check is fast)
"""
```

### E2. `tests/test_spell_checker.py`

```python
"""
Test Roman Urdu n-gram spell-checker.

Setup: Train a small spell-checker on a sample corpus for testing:
sample_corpus = [
    "mein school ja raha hoon",
    "aaj mausam bohat acha hai",
    "pakistan aik khoobsurat mulk hai",
    "mujhe programming bohat pasand hai",
    "yeh hamara final year project hai",
    "aap kaise hain sab theek hai",
    "university mein bohat kaam hai",
    "mein aap ko bataunga",
    "kabhi kabhi mushkil hota hai",
    "woh ghar ja raha hai",
    # ... add ~100 more common sentences
]

Test cases:

1. test_common_word_scores_high
   - Words: "mein", "hai", "aap", "hoon"
   - Expected: score > 0.5 for each (very common)

2. test_suspicious_word_scores_low
   - Words: "spryzr", "kmbrh", "shrtkts", "btnga"
   - Expected: score < 0.3 for each (unusual character patterns)

3. test_known_word_not_corrected
   - Word: "mein" (in vocabulary)
   - Expected: suggest_correction returns None

4. test_misspelling_corrected
   - Word: "btaunga" (not in vocab, close to "bataunga")
   - Expected: suggest_correction returns "bataunga"

5. test_short_words_skipped
   - Words: "a", "e", "k"
   - Expected: is_suspicious returns False (too short to judge)

6. test_numbers_skipped
   - Words: "123", "4pm", "2025"
   - Expected: is_suspicious returns False

7. test_high_threshold_catches_more
   - With threshold=0.5, more words flagged than with threshold=0.3
   - Verify relative behavior

8. test_correction_prefers_frequent_words
   - Word: "haa" could match "hai" (freq=312000) or "haan" (freq=5000)
   - Expected: prefers "hai" due to higher frequency
   - Wait — actually "haa" is closer to "haan" by edit distance
   - Test should verify that BOTH similarity AND frequency are considered

9. test_length_filter_on_suggestions
   - Word: "bt" (2 chars)
   - Should not suggest "bataunga" (8 chars) — too different in length

10. test_save_and_load
    - Train checker, save to temp file
    - Load from temp file
    - Verify same scores and vocabulary

11. test_training_on_empty_corpus
    - Train on empty list
    - All words should score low, no crashes

12. test_unicode_handling
    - Words with accents or special chars don't crash the scorer
"""
```

### E3. `tests/test_full_pipeline.py`

```python
"""
End-to-end integration tests for the complete pipeline.
These test the full flow: Urdu text → all layers → final Roman Urdu.

IMPORTANT: These tests require:
- m2m100 model loaded (or mocked)
- Loanword dictionary loaded
- IndicXlit engine available
- Spell-checker trained

For CI/fast testing, mock m2m100 and IndicXlit. For real testing, use actual models.

Test cases:

1. test_pure_urdu_sentence
   - Input: "آج موسم بہت اچھا ہے"
   - Expected output should contain: "aaj", "mausam", "bohat", "acha", "hai"
   - No English words, all layers should pass through cleanly

2. test_loanword_preserved
   - Input: "میرے سپروائزر بہت اچھے ہیں"
   - Expected: "supervisor" appears in output (from dictionary)
   - NOT "spryzr" or any mangled form

3. test_mixed_urdu_english
   - Input: "میں یونیورسٹی میں کمپیوٹر سائنس پڑھ رہا ہوں"
   - Expected: "university" and "computer science" from dictionary
   - Remaining Urdu words transliterated correctly

4. test_indicxlit_fixes_m2m100_error
   - Setup: Mock m2m100 to return "universty" for "یونیورسٹی"
   - Also mock loanword dict to NOT contain this word
   - Expected: IndicXlit backup catches it and corrects to "university"

5. test_spell_checker_fixes_vowel_drop
   - Setup: Mock m2m100 to return "btaunga" for "بتاؤنگا"
   - Expected: spell-checker corrects to "bataunga"

6. test_english_words_not_spell_checked
   - Input contains "supervisor" from loanword dictionary
   - Spell-checker should NOT try to "correct" it to a Roman Urdu word
   - Verify english_positions are properly passed through

7. test_names_preserved
   - Input: "ڈاکٹر فیاض ہمارے سپروائزر ہیں"
   - Expected: "doctor" and "Fayaz" and "supervisor" all preserved
   - "doctor" from loanword dict, "Fayaz" from names dict, "supervisor" from loanword dict

8. test_user_sample_text
   - Use the actual sample from the user:
   - Input: "ںیہ ںیقیرط نیت ےک ےنرک سیک کوب کیم وس ںیہ ےترک سیک کوب کیم ےہ وج گول مہ حرط سک ہک اگ ںؤاتب وک پآ ںیم جآ"
   - Verify output is readable Roman Urdu
   - Key words to check: professionals, shortcuts, supervisor, washroom, doctor

9. test_empty_input
   - Input: ""
   - Expected: "" (no crash)

10. test_single_word_input
    - Input: "پاکستان"
    - Expected: "pakistan"

11. test_very_long_sentence
    - Input: 50+ word Urdu sentence
    - Expected: completes without timeout, output is same word count (approximately)

12. test_pipeline_performance
    - Process 10 sentences through full pipeline
    - Should complete in < 30 seconds (including model inference)
    - Log time taken per layer for profiling

13. test_layers_are_independent
    - Disabling IndicXlit (mock returns input unchanged) should not break other layers
    - Disabling spell-checker should not break other layers
    - Each layer should gracefully handle being the only active layer

14. test_no_double_correction
    - A word corrected by IndicXlit should NOT be re-corrected by spell-checker
    - Track which words were already fixed and pass that info downstream
"""
```

---

## Part F: Implementation Order

| Step | Task | Depends On |
|---|---|---|
| 1 | Install ai4bharat-transliteration, update requirements.txt | — |
| 2 | Create `app/services/indicxlit_backup.py` with full class | Step 1 |
| 3 | Create `app/services/spell_checker.py` with full class | — |
| 4 | Create `scripts/train_spell_checker.py` | Step 3 |
| 5 | Run `train_spell_checker.py` to generate `spell_checker.pkl` | Step 4 |
| 6 | Modify `transliterate_batch()` to hook in both new layers | Steps 2, 3 |
| 7 | Create `tests/test_indicxlit_backup.py` and run | Steps 2, 6 |
| 8 | Create `tests/test_spell_checker.py` and run | Steps 3, 5 |
| 9 | Create `tests/test_full_pipeline.py` and run | Steps 6, 7, 8 |
| 10 | Test with user's sample text end-to-end | Step 9 |

---

## Part G: Important Edge Cases to Handle

1. **ai4bharat-transliteration install issues**: The package has known numpy version conflicts. If install fails, try `pip install ai4bharat-transliteration --no-deps` then install missing deps manually.

2. **IndicXlit first-call latency**: First call loads the model (~3-5 seconds). Use lazy loading + singleton pattern so this only happens once.

3. **Spell-checker vocabulary size**: RUP has ~43K unique Roman Urdu words. The vocabulary set and n-gram counts should fit in <50MB RAM.

4. **Double correction prevention**: Pass a set of `already_corrected_positions` from IndicXlit to the spell-checker so it doesn't re-correct words IndicXlit already fixed.

5. **Confidence logging**: Log every correction made by IndicXlit and spell-checker with confidence scores. This helps debug issues and tune thresholds later.

6. **Graceful degradation**: If IndicXlit fails to load (install issues), the pipeline should continue without it. Same for spell-checker. Never let a backup layer crash the main pipeline.
