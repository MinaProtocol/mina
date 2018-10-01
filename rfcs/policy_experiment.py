import random
import matplotlib.pyplot as plt
import matplotlib.animation as animation

# There are n pieces of work.
# A policy is a randomized funciton
# (capacity : N) -> [n]^capacity

num_work = 100

def shuffled(x):
    y = x[:]
    random.shuffle(y)
    return y

def uniform(capacity):
    return lambda: shuffled(list(range(num_work)))[:capacity]

def first_available(capacity):
    return range(capacity)

def convex_combination(policies):
    def f(capacity):
        p = random.random()
        acc = 0.0
        for prob, policy in policies:
            acc += prob
            if p < acc:
                return policy(capacity)
    return f

capacities = [ 1 ] * 20
network = [ uniform(c) for c in capacities]

def concat(xss):
    return [ x for xs in xss for x in xs ]

def sample_network(samplers):
    return concat([ s() for s in samplers ])

def main():
    works = []

    def first_missing_work():
        ws = list(set(works))
        ws.sort()
        looking_for = 0
        for w in ws:
            if w > looking_for:
                return looking_for
            looking_for += 1
        return looking_for

    def update_histogram(frame):
        works.extend(sample_network(network))
        plt.cla()
        _, _, patches = plt.hist(works, bins=num_work)
        missing = first_missing_work()
        for i, patch in enumerate(patches):
            if i < missing:
                patch.set_facecolor('green')

    fig = plt.figure()
    anim = animation.FuncAnimation(fig, update_histogram, interval=500)

    #print (works)
    #hist = plt.hist(works, bins=num_work)
    #print (hist)
    plt.show()

if __name__ == '__main__':
    main()
