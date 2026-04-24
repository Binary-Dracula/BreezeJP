import re
import sys
import fugashi
import jaconv
from functools import lru_cache

tagger = fugashi.Tagger()


@lru_cache(maxsize=10000)
def generate_ruby(text):
    if not text:
        return ""

    out = []

    for word in tagger(text):
        orig = word.surface

        if not re.search(r'[\u4e00-\u9fff]', orig):
            out.append(orig)
            continue

        kana = getattr(word.feature, 'kana', None)
        if not kana:
            out.append(orig)
            continue

        hira = jaconv.kata2hira(kana)
        orig_len, hira_len = len(orig), len(hira)

        suffix = ""
        i = 1
        while i <= orig_len and i <= hira_len:
            if orig[-i] == hira[-i]:
                suffix = orig[-i] + suffix
                i += 1
            else:
                break

        prefix = ""
        j, hira_start, orig_start = 0, 0, 0
        while j < (orig_len - len(suffix)) and j < (hira_len - len(suffix)):
            if orig[j] == hira[j]:
                prefix += orig[j]
                j += 1
                hira_start += 1
                orig_start += 1
            else:
                break

        kanji_part = orig[orig_start: orig_len - len(suffix)]
        ruby_part = hira[hira_start: hira_len - len(suffix)]

        if kanji_part and ruby_part and kanji_part != ruby_part:
            out.append(f"{prefix}{kanji_part}[{ruby_part}]{suffix}")
        else:
            out.append(orig)

    return "".join(out)


def main():
    if len(sys.argv) > 1:
        print(generate_ruby(" ".join(sys.argv[1:])))
    else:
        for line in sys.stdin:
            print(generate_ruby(line.rstrip("\n")))


if __name__ == "__main__":
    main()

