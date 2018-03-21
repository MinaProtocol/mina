import ecfactory.mnt_cycles as mnt_cycles

import sys

sys.stderr.write("start\n")

for line in sys.stdin:
  sys.stderr.write("line!\n")
  try:
    D = int(line)
    sys.stderr.write("line " + str(D) + "\n")
    cycles = mnt_cycles.make_cycle(-D)
    print('Found a cycle: ' + str(cycles[0][0]) + ', ' + str(cycles[0][1]))
  except Exception as e:
    print(e.message)
