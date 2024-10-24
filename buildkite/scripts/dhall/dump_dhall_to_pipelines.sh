#!/bin/bash

ROOT=$1
OUTPUT=$2

mkdir -p "$OUTPUT"

shopt -s globstar nullglob

echo "Dumping pipelines from '$ROOT' to '$OUTPUT'"

COUNTER=0

for file in "$ROOT"/**/*.dhall
do
    filename=$(basename "$file")
    filename="${filename%.*}"

    dhall-to-yaml --quoted --file "$file" > "$OUTPUT"/"$filename".yml

    COUNTER=$((COUNTER+1))
done

echo "Done. $COUNTER jobs exported"
