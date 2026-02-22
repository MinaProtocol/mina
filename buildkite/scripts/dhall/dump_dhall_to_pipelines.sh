#!/bin/bash

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <dhall_root_dir> <output_dir>"
    exit 1
fi

ROOT=$1
OUTPUT=$2



mkdir -p "$OUTPUT"

shopt -s globstar nullglob

echo "Dumping pipelines from '$ROOT' to '$OUTPUT'"

COUNTER=0

for file in "$ROOT"/Jobs/**/*.dhall
do
    filename=$(basename "$file")
    filename="${filename%.*}"

    dhall-to-yaml --quoted --file "$file" > "$OUTPUT"/"$filename".yml

    dhall-to-yaml <<< "let SelectFiles = $ROOT/Lib/SelectFiles.dhall in SelectFiles.compile (./$file).spec.dirtyWhen " > "$OUTPUT"/"$filename".dirtywhen


    COUNTER=$((COUNTER+1))
done

echo "Done. $COUNTER jobs exported"
