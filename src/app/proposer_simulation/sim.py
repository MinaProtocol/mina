import random
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation

f = 0.99

threshold = lambda x: 1 - (1 - f) ** x

def normalize(xs):
  s = sum(xs)
  return [ x / s for x in xs ]

coinbase_amount = 0.1

def simulate(stakes, total_money, slots):
  total_money = float(total_money)
  winners = []
  for i in range(slots):
    per_slot_winners = []
    for id, s in enumerate(stakes):
      if random.random() < threshold(s / total_money):
        per_slot_winners.append(id)
    # Simulate the deterministic tie-breaking
    if per_slot_winners:
      winners.append(random.choice(per_slot_winners))

  new_stakes = stakes[:]
  for w in winners:
    total_money += coinbase_amount
    new_stakes[w] += coinbase_amount
  return (new_stakes, total_money)

figure = plt.figure()
stakes = 100 * [0.5] +  [ 50 ]
total_money = float(sum(stakes))
bars = plt.bar(np.arange(len(stakes)), [s / total_money for s in stakes])
plt.ylim(top=1)

sim = lambda (s, g): simulate(s, g, 2160)
def iterate(f, n, x):
  for i in range(n):
    x = f(x)
  return x

def update(frame):
  global stakes
  global total_money
  res = iterate(sim, 1, (stakes, total_money))
  stakes = res[0]
  total_money = res[1]
  print max(stakes) / total_money
  for i, b in enumerate(bars):
    b.set_height(stakes[i] / total_money)

animation = FuncAnimation(figure, update, interval=10)

plt.show()
