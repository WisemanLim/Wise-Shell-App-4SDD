#!/usr/bin/env python3
# Redact absolute paths (anything under /Users/...) and GitHub tokens from an
# asciicast file. Works as a plain text substitution so it is independent of the
# asciicast version (v2/v3). Matches even partial paths produced frame-by-frame
# by the line editor, because every fragment still starts with "/Users/".
import re
import sys

src, dst = sys.argv[1], sys.argv[2]

# A path token = /Users/ followed by run of chars that are not whitespace,
# not a JSON string terminator ("), and not a backslash (start of an escape
# like \r, ). This stops cleanly at the end of each printed path.
PATH = re.compile(r'/Users/[^\s"\\]*')
# GitHub tokens (defensive; gh already masks them in `gh auth status`).
TOKENS = re.compile(r'\b(?:gho|ghp|ghs|ghr|ghu)_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+')

with open(src, "r", encoding="utf-8") as f:
    text = f.read()

text = PATH.sub("<path>", text)
text = TOKENS.sub("***REDACTED***", text)

with open(dst, "w", encoding="utf-8") as f:
    f.write(text)

print(f"redacted -> {dst}")
