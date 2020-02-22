#!/bin/bash
# Renames generated *.gen.tsx typescript files to *.ts
mv ${1%.bs.js}.gen.tsx ${1%.bs.js}.ts
