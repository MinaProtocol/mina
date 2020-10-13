#!/bin/sh

# please forgive the hackiness of this script (I know I could have just used 1 csv)

cat /dev/null > scan_state_memory_usage.csv
cat /dev/null > scan_state_memory_usage_depth_6.csv
cat /dev/null > scan_state_memory_usage_depth_9.csv

for delay in 0 1 2 3 4 5 6; do
  mem6=$(./scan_state_memory_usage.py 6 $delay \
    | grep Scan \
    | cut -d= -f2)
  mem9=$(./scan_state_memory_usage.py 9 $delay \
    | grep Scan \
    | cut -d= -f2)
  echo "$delay, $mem6, $mem9" >> scan_state_memory_usage.csv
  echo "$delay, $mem6" >> scan_state_memory_usage_depth_6.csv
  echo "$delay, $mem9" >> scan_state_memory_usage_depth_9.csv
done

plot() {
  csv=$1
  plot_cmd=$2
  gnuplot -p -e "\
    set datafile separator \",\";\
    set term png;\
    set output \"${csv%.csv}.png\";\
    set format y '%.0s%cB';\
    plot '$csv' $plot_cmd"
}

plot scan_state_memory_usage.csv "using 1:2 title 'depth = 6' with lines, '' using 1:3 title 'depth = 9' with lines"
plot scan_state_memory_usage_depth_6.csv "using 1:2 title 'depth = 6' with lines"
plot scan_state_memory_usage_depth_9.csv "using 1:2 title 'depth = 9' with lines"
