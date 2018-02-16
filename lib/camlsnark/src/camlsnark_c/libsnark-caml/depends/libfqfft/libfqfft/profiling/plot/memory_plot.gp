## Initialization ##
cd input_directory
set datafile separator ","

## Graph Formatting ##
set title 'Memory'
set xlabel 'Domain Size'
set ylabel 'Usage (in kilobytes)'
set logscale xy 2
set format xy "2^{%L}"
set size ratio -1
set grid x y
set key outside

set style line 1 lc rgb '#0072bd'
set style line 2 lc rgb '#d95319'
set style line 3 lc rgb '#edb120'
set style line 4 lc rgb '#7e2f8e'
set style line 5 lc rgb '#77ac30'
set style line 6 lc rgb '#a2142f'

## Output ##

set term postscript enhanced color solid
set output "memory.ps"

# set term png enhanced
# set output "memory.png"

## Plot ##
list = system('ls *.csv')
plot for [i=1:words(list)] word(list,i) every ::1 with lines ls i title word(list,i)
