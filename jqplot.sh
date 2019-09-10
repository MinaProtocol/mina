#!/bin/sh

num_fields=$(($#-1))
field_filters=${@:1:$num_fields}
input_file=${@:$#}
tmp="$(mktemp /tmp/dat.XXXXXX)"

filter=''
plots=''
i=1
for field_filter in $field_filters; do
  filter="$filter$(if [ -n "$filter" ]; then echo ' '; fi)\\($field_filter)"
  plots="$plots$(if [ -n "$plots" ]; then echo ', '; fi)'$tmp' using 0:$i with lines"
  i=$(($i+1))
done
filter="\"$filter\""

jq -r "$filter" "$input_file" > $tmp
gnuplot -p -e "plot $plots"
rm $tmp
