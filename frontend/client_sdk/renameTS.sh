#!/bin/bash
# Renames generated *.gen.tsx typescript files to *.ts
# Fails silently because it doesn't work properly as a dep but it doesn't matter
mv ${1%.bs.js}.gen.tsx ${1%.bs.js}.ts 2>/dev/null || true
