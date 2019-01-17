## Initialization ##
cd input_directory
set datafile separator ","

## Graph Formatting ##
set ylabel 'Count'
set size 1, 1
set xtics("Addition" 1.3, "Subtraction" 2.3, "Multiplication" 3.3, "Inverse" 4.3)
set xtics font "Helvetica, 10"
set format y "%.0f"
set key outside

## Box Formatting ##
set boxwidth 0.1
set style fill solid 0.25 border
set style line 1 lc rgb '#0072bd'
set style line 2 lc rgb '#d95319'
set style line 3 lc rgb '#edb120'
set style line 4 lc rgb '#7e2f8e'
set style line 5 lc rgb '#77ac30'
set style line 6 lc rgb '#a2142f'

## Output ##
set term postscript enhanced color solid
set output "operators.ps"

# set term png enhanced
# set output "operators.png"

## Plot 1 ##
list = system('ls *.csv')
size = system('tail -n 1 '.word(list,1).'| cut -f1 -d","')
set title 'Operators (Domain Size: '.size.')'
plot for [i=1:words(list)] for [j=2:5] '< tail -n 1 '.word(list,i) using (j-1+(i*0.1)):(column(j)) with boxes ls i title (j==2)?word(list,i):""

## Graph Formatting ##
set title 'Operators'
set xtics font "Helvetica, 6"
set xlabel 'Domain Size'
set logscale xy 2
set format xy "2^{%L}"
set size ratio -1
set grid x y

## Plot 2 ##
list = system('ls *.csv')
plot for [i=1:words(list)] word(list,i) using 1: (sum [col=2:5] column(col)) :xtic(1) with lines ls i title word(list,i)