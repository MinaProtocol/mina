---
title: A SNARKy Exponential Function
subtitle: Simulating real numbers using finite field arithmetic
date: 2019-03-09
author: Izaak Meckler
author_website: https://twitter.com/imeckler
---

In Coda, we use the proof-of-stake protocol Ouroboros for consensus.
Naturally since this is Coda, that means we have to check proofs-of-stake inside
a SNARK.

A proof-of-stake for a person with some amount of stake $a$
in Ouroboros is a random number $s$ between 0 and 1
(which one provably has generated fairly) such that $s$ is
less than some threshold depending on $a$. Concretely, that
threshold is $1 - (1/2)^{\frac{a}{T}}$ where $T$ is the total amount of
stake in the system.

It's important to use a threshold of this form because it means that the density
of blocks over time does not depend on the distribution of stake.

If you know anything about SNARKs, you know that inside of a SNARK all we
can do is arithmetic (that is, addition and multiplication) in a finite field $F_p$. It's not at
all clear how we can compute a fractional number raised to a fractional power!

We'll go through a very cool technique for computing such a thing.
All the code for doing what we'll talk about is implemented using
[snarky](https://github.com/o1-labs/snarky) and can be found [here](https://github.com/CodaProtocol/coda/pull/1822).

The technique will go as follows:

1. We'll use Taylor series to approximately reduce the problem to doing arithmetic with
  real numbers.
2. We'll approximate the arithmetic of real numbers using the arithmetic
  of rational numbers.
3. We'll then approximate the arithmetic of rational numbers using integer
  arithmetic.
4. Finally, we'll simulate integer arithmetic using finite field
  arithmetic.

## Taylor series

First we need a way to reduce the problem of computing an exponentiation to
multiplications and additions in a finite field. As a first step, calculus
lets us reduce exponentiation to multiplication and addition over the
real numbers (a field, but not a finite one) using a [Taylor series](https://en.wikipedia.org/wiki/Taylor_series).

Specifically, we know that

<div class="katex-block">
```
\begin{aligned}
  1 - (1/2)^x
  &= -\log(1/2) x - \frac{(\log(1/2) x)^2}{2!} - \frac{(\log(1/2) x)^3}{3!} - \dots \\
  &= \log(2) x - \frac{(\log(2) x)^2}{2!} + \frac{(\log(2) x)^3}{3!} - \dots
\end{aligned}
```
</div>

We can truncate this Taylor series to get polynomials $T_n$
<div class="katex-block">
```
\begin{aligned}
  T_n
  &= \log(2) x - \frac{(\log(2) x)^2}{2!} + \dots + \frac{(\log(2) x)^n}{n!} \\
  &= \log(2) x - \frac{\log(2)^2}{2!} x^2 + \dots + \frac{\log(2)^n}{n!} x^n
\end{aligned}
```
</div>
by taking the first $n$ terms. The Taylor polynomials *nearly* compute
$1 - (1/2)^x$, but with some error that gets smaller as you take more and more
terms. You can see this in the image of the actual function (in blue) along with the
first few Taylor polynomials (in black).

![](/static/blog/taylor/taylor-polys.png)

It turns out there's a handy formula which lets us figure out how
many terms we need to take to make sure we get the first
$k$ bits of the output correct, so we can just use that and truncate at
the appropriate point for the amount of precision that we want.


## From reals to rationals

Multiplication and addition are continuous, which means if you change the
inputs by only a little bit, the outputs change by only a little bit.

Explicitly, if instead of computing $x_1 + x_2$, we compute
$a_1 + a_2$ where $a_i$ is $x_i$ plus some small error $e_i$, we have
$a_1 + a_2 = (x_1 + e_1) + (x_2 + e_2) = (x_1 + x_2) + (e_1 + e_2)$ so
the result is close to $x_1 + x_2$ (since $e_1 + e_2$ is small).

Similarly for multiplication we have
$a1 a2 = (x1 + e1)(x2 + e2) = x1 x2 + e1 x1 + e2 x2 + e1 e2$.
If $e1, e2$ are small enough compared to $x_1$ and $x_2$,
then $e1 x1 + e2 x2 + e1 e2$ will be small as well, and so
$a1 a2$ will be close to $x1 x2$.

![If we change the input by a little, the output changes only by a little.](https://upload.wikimedia.org/wikipedia/commons/d/d5/Epsilon-delta_limit.svg)

What this means is that instead of computing the Taylor polynomial
$$
  \log(2) x - \frac{\log(2)^2}{2!} x^2 + \dots + \frac{\log(2)^n}{n!} x^n
$$

using real numbers like $\log(2)$ (which is irrational), we can approximate
each coefficient $\log(2)^k / k!$ with a nearby rational number and compute
using those instead! By continuity, we're guaranteed that the result will
be close to the actual value (and we can quantify exactly how close if we
want to).

## From rationals to integers

There are a few ways to approximate rational arithmetic using integer arithmetic,
some of which are more efficient than others.

The first is to use arbitrary rational numbers and simulate rational arithmetic exactly.
We know that
$$
\frac{a}{b} + \frac{c}{d} = \frac{a d + b c}{b d}
$$
so if we represent rationals using pairs of integers, we can simulate rational
arithmetic perfectly. However, there is a bit of an issue with this approach, which
is that the integers involved get really huge really quickly when you add numbers together.
For example,  $1/2 + 1/3 + \dots + 1/n$ has $n!$ as its denominator, which is a large number.

That's a problem for us inside the SNARK, because we're working with a finite field and
want to make sure there is no overflow.

A better approach is to use rational numbers whose denominator is a power of two.
These numbers are called [dyadic rationals](https://en.wikipedia.org/wiki/Dyadic_rational) and are basically the same thing as
[floating point numbers](https://en.wikipedia.org/wiki/Floating-point_arithmetic).

![What dyadic rationals look like](https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Dyadic_rational.svg/1200px-Dyadic_rational.svg.png)

Here,
addition can be simulated using integers as follows. A rational number $\frac{a}{2^k}$
is represented as the pair $(a, k)$. Say $k \leq m$. For addition, we have
$$
\frac{a}{2^k} + \frac{b}{2^m} = \frac{2^{m - k} a + b}{2^m}
$$
so the denominator of a sum is the max of the denominators of the inputs.
That means that the denominators don't get huge when you add a bunch of numbers (they
will stay as big as the largest input to the sum).

Moreover, any rational number can be approximated by a number of this form (it's just
the binary expansion of that number).

## From integers to a finite field

To recap, we've done the following.

1. We approximated our exponential $1 - (1/2)^x$ by arithmetic over the reals
  using Taylor polynomials.
2. We approximated real arithmetic by rational arithmetic using continuity.
3. We approximated rational arithmetic by the arithmetic of dyadic-rationals/floats,
  again using continuity. Moreover, we saw that floating point arithmetic can easily
  be simulated exactly using integer arithmetic.

Now our final step is to simulate integer arithmetic using the arithmetic of
our prime order field $\mathbb{F}_p$. But this step is actually the easiest!
As long as we are careful about numbers not overflowing, it's the same thing.
That is, if we know ahead of time that $a + b < p$, then we can safely
compute $a + b \mod p$, knowing that the result will be the same as over the integers.
The same is true for multiplication. So as long as we don't do too many multiplications,
the integers representing the dyadic rationals we're computing with won't get too big,
and so we will be okay. And if we don't take too many terms of the Taylor series, this
will be the case.

## Conclusion

Let's survey the net result of all this approximation: We have a very efficient way
of approximately computing an exponential function on fractional inputs inside of a SNARK,
in such a way that we can have concrete bounds on the error of the approximation. Pretty cool!
This enables us to use a threshold function for Ouroboros that guarantees a constant density
of blocks regardless of the distribution of stake.
