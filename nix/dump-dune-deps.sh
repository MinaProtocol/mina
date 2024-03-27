#!/usr/bin/env bash

            deps_expr='\(\s*libraries\s\s*([^\)]*)\)'
            name_expr='\(\s*public_name\s\s*([^\)]*)\)'
            find app lib -mindepth 2 -name dune | while read dune; do
              sed 's/;.*$//g' "$dune" | tr "\n" " " > tmp_file

              IFS=';' read -ra names < <( grep -oE "$name_expr" tmp_file | sed -r "s/$name_expr/\1/g" | tr "\n" ';')
              IFS=';' read -ra depss < <( grep -oE "$deps_expr" tmp_file | sed -r "s/$deps_expr/\1/g" | sed 's/\s*$//g' | sed 's/\s\s*/\",\"/g' | tr "\n" ';')

              ix=0
              for name in "${names[@]}"; do
                deps="${depss[$ix]}"
                ix=$((ix+1))
                echo "\"$name\":[\"$deps\"]"
              done
            done | tr "\n" "," | sed 's/^/{/g' | sed 's/,$/}/g' > deps.json
