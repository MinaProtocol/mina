---
title: Snarky: A high-level language for verifiable computation
date: 2018-03-11
author: Izaak Meckler
---

Living in the world today requires giving up a lot of control.
We give up control of our financial lives to banks and unaccountable credit bureaus.
We give up control of our most intimate data to use online services like Facebook, Amazon, and Google.
We give up control of our elections to voting-system companies who run opaque and unauditable elections.
We even give up some control over our understanding of the world through exposure to false or misleading news stories.

But it doesn't have to be this way.
Cryptography as a discipline provides us with some of the tools necessary to regain some of this control over our resources and data
while reducing the need to trust unaccountable actors.

One such tool is **verifiable computation**.
A **verifiable computation** is a computation that
produces an output along with a proof certifying *something* about that output.
Until very recently, verifiable computation has been mostly theoretical, but recent
developments in zk-SNARK constructions have helped maked it practical. 

Verifiable computation makes it possible for you to be confident about exactly
what other people are doing with your data. For example, it enables

- Online services that are forced to be transparent about what data of yours they
  have and how they are using it.
- Auditable elections that protect the privacy of your vote.
- Publishing stories that provably come from a reliable source, without leaking what that source is.
- Sending money to others without yielding control of your account or your privacy.

Verifiable computation is powered by zk-SNARKs.
Right now, however, progamming directly with SNARKs is comparable to writing machine
code by hand, and trusting "SNARK machine code" is a lot like trusting a compiled binary without
the source code.

To fulfill the promise of verifiable computing as a tool for returning control and agency
to individuals, their operation has to be made as transparent as possible.
We can help accomplish that goal by making the properties that verifiable computations
prove specifiable in languages that are as close as possible
to the informal, inuitive properties we have in our minds. That way, individuals can
trust the easy-to-understand high-level specifications, rather than opaque "SNARK
machine code".

In this post, I'll describe how we at O(1) Labs are helping to bridge this gap and
solve the transparency problem with our language [Snarky](https://github.com/o1-labs/snarky)
for specifying verifiable computation.


# Verifiable computation

As mentioned above, a **verifiable computation** is a computation that
**computes** an output along with a **proof** certifying *something* about that output.

For example, 

- A government could **compute** the winner of an election and **prove** that they counted
  all the votes correctly. 
- An advertising service could **compute** an ad to serve to you and **prove** that the ad
  was generated without using personal data (i.e., your race, income, political views, etc.)
- A website could **compute** a news-feed to send to you and **prove** that it
  was generated without access to your personal data (and thus free of targeted ads, content, etc.)
- A journalist could **compute** a story containing a quote from a source and **prove** that
  the quote came from a reliable source (without revealing which one).

# Verifiable elections

For this post, let's focus on the example of a verifiable election. One place where people
are clamoring for accountability is of course in how pizza toppings are chosen in group
settings. (Heads up: I kept this example simple for exposition, which means there are a few flaws.
I take no accountability for your pizza election.)

So let's imagine you and your friends are trying to decide on what pizza topping to get
(either pepperoni or mushroom) and you'd like to vote on a topping while keeping your
votes as secret as possible.

<div class='blog-image-wrapper'>
  <img class='small-blog-image' src='/static/img/pizza.jpg' alt='Source:http://food.xegyn.com/images/posts/2015-07-05-thin-crust-pizza/arinell.jpg'></img>
  <div class='caption'>Here is a picture of pizza to keep you interested.</div>
</div>

Let's say everyone trusts Alice to keep votes secret.
She'll act as the "government" by collecting everyone's votes.
But everyone also knows Alice loves mushroom pizza, which means we don't necessarily
trust her to run a fair election.
So we'll develop a scheme that gives everyone
assurance that the election was run correctly (i.e., that each person's vote was
included and that the majority vote was computed correctly).

Using zk-SNARKs, we can write a verifiable computation which
Alice can run to compute the majority vote and prove that it was computed correctly.
Moreover, using the "zk" or zero-knowledge part of zk-SNARKs, she can do so
in such a way that everyone can trust the result without learning any information about individuals' votes.

# zk-SNARKs, technically

Simplifying a bit, zk-SNARK constructions give us the following ability.
Say we have a set of polynomials $p_1, \dots, p_k$ in variables $x_1, \dots, x_n, y_1, \dots, y_m$.
For given $\alpha_1, \dots, \alpha_n$, if we know $\beta_1, \dots, \beta_m$ such that
$$ p_i(\alpha_1, \dots, \alpha_n, \beta_1, \dots, \beta_m) = 0
$$
we can produce a piece of data $\pi$ which somehow certifies our knowledge of such
$\beta_i$s which has the following two properties:
1. Zero-knowledge: $\pi$ does not expose any information about $\beta_1, \dots, \beta_m$
2. Succinctness: $\pi$ is very small (concretely, a few hundred bytes) and can be checked quickly (concretely, in milliseconds).
Such a set of $\beta$s is called a satisfying assignment.

It turns out that such constraint systems are universal in the following sense.
Given any (non-deterministic) verifiable computation, we can construct a constraint system so that the
existence of a satisfying assignment is equivalent to the correctness of the computation.

So, it seems that zk-SNARKs gives us exactly what we want. Namely, a means to prove correctness of
computations while hiding private information and saving parties from having to redo the computation themselves.

# Back to elections

With these SNARKs in hand, let's return to our election example. The voting scheme will be
as follows:

1. Each voter $i$ chooses a vote $v_i$ and a nonce $b_i$. They publish a
  [commitment](https://en.wikipedia.org/wiki/Commitment_scheme)
  $h_i = H(b_i, v_i)$, where $H$ is some collision resistant hash function. They send
  $(b_i, v_i)$ to the government.
2. The government computes the majority vote $w$ and publishes it along with a SNARK
  proving "For each $i$, I know $(b_i, v_i)$ such that $H(b_i, v_i) = h_i$ and $w$ is
  the majority vote of the $v_i$".
3. Voters verify the SNARK on their own against the public set of commitments $(h_1, \dots, h_n)$.

The zero knowledge property of the SNARK ensures that no votes are revealed to anyone except
the government. So, to realize this scheme in practice, all we need to do is to encode the
above statement as a constraint system. Here it is:

<div class='blog-image-wrapper'>
  <a href='/static/constraints.txt'><img class='medium-blog-image' src='/static/img/constraints-preview.png'></a>
  <div class='caption'>Click for full set</div>
</div>

Great, we're done! Er -- well, maybe not. The trouble is that it's basically impossible for
anyone to verify that this constraint system does actually enforce the above property. I could
have just chosen it at random, or maliciously. In fact it doesn't actually force the property:
I deleted a bunch of constraints to make this page load faster.

The situation is similar to programming in general: one doesn't want to have to trust a compiled
binary because it is difficult to verify that it is doing what one expects one to do. Instead,
we write programs in high-level languages that are easier for people to verify, and then compile
them to assembly.

Here, in order for it to be convincing that a constraint system actually does what one expects it
to do, one would like it to be the result of running a trusted compiler on a high-level program
that is more easily seen to be equivalent to the claim one wants to prove.

# Toward a programming language for verifiable computation

We'll now describe Snarky, our OCaml DSL for verifiable computation. It's a high-level language
for describing verifiable computations so that their correctness is more transparent.
First we describe the programming model of Snarky and then explain in more depth how this model is
realized.

## Requests

The basic programming model is as follows. A "verifiable computation" will be an otherwise
pure computation augmented with the ability to do the following two things:

1. Pause execution to ask its environment to provide it with a value and then resume execution
  using that value.
2. Assert that a constraint holds among some values, terminating with an exception if the
  constraint does not hold.

<div class='blog-image-wrapper'>
  <img class='small-blog-image' src='/static/img/helping-hand.jpg'>
  <div class='caption'>A verifiable computation requesting a value from its environment</div>
</div>

To get a feel for the model, let's see our election computation rendered in a pseudocode version
of Snarky.
```
winner (commitments):
  votes =
    List.map commitments (fun commitment ->
      (nonce, vote) = request (Open_ballot commitment)
      assert (H(nonce, vote) = commitment)
      return vote)

  pepperoni_count =
    count votes (fun v -> v = Pepperoni)

  pepperoni_wins = pepperoni_count > commitments.length / 2
  return (if pepperoni_wins then Pepperoni else Mushroom)
```

This is intended to define a function `winner` that takes as input a list of commitments
and returns the majority vote of a set of votes corresponding to those commitments (assuming
it doesn't terminate with an exception). It obtains the corresponding votes
by mapping over the commitments and for each one

- requesting that the environment provide it with such a vote (and nonce)
- asserting that the provided vote and nonce do in fact correspond to the commitment.

If `winner(commitments)` is run in an environment in which it
terminates without an assertion failure and outputs `w`,
we know that there were votes corresponding to `commitments` such that the majority vote
was `w`. Snarky gives us a way to prove statements like this about computations.

$\newcommand{\tild}{\widetilde}$
Namely,
given a verifiable computation $P$ (i.e., a computation that makes some requests for values and
assertions of constraints) Snarky lets us compile $P$ into a constraint system $\tild{P}$ such that the
following two are equivalent:

1. Some environment can provide $P$ with values to answer each request such that $P$ executes
  without an assertion failure.
2. Some environment can produce a satisfying assignment to $\tild{P}$.

In our case, the requests are for openings to each of the vote commitments, and the assertions
check the correctness of the openings. So, reiterating, if Alice can prove `winner(cs) = w` for
some commitments `cs` and winner `w`, she will have proved
"I know a set of votes `votes` corresponding to the commitments `cs` such that the majority vote of
`votes` is `w`".

## Snarky concretely

Let's take a look at what the above example actually looks like in Snarky
```ocaml
let winner commitments =
  let%bind votes =
    Checked.List.mapi commitments ~f:(fun i commitment ->
      let%bind nonce, vote =
        request Ballot.Opened.typ (Open_ballot i)
      in
      let%map () =
        hash_ballot (nonce, votes)
        >>= Ballot.Closed.assert_equal commitment
      in
      vote)
  in
  let%bind pepperoni_count =
    count votes ~f:(fun v -> Vote.(v = var Pepperoni))
  in
  let half = constant (Field.of_int (List.length commitments / 2)) in
  let%bind pepperoni_wins = pepperoni_count > half in
  Vote.(if_ pepperoni_wins ~then_:(var Pepperoni) ~else_:(var Mushroom))
```

There's a bit of noise caused by the harsh realities of OCaml's monad syntax,
but overall it is quite close to our pseudocode. We

1. Map over the commitments, requesting for our environment to open them.
2. Compute the number of votes for pepperoni.
3. If the number of pepperoni votes is greater than half the votes, return pepperoni
  as the winner, and otherwise return mushroom.

## Handling requests

We must provide a mechanism for handling requests made by verifiable computations to
pass in requested values (similar to the way we write exception handlers). In Snarky,
this looks like

```ocaml
handle
  (winner commitments)
  (fun (With {request; respond}) ->
    match request with
    | Open_ballot i -> respond ballots.(i)
    | _ -> unhandled)
```
where `ballots : Ballot.Opened.t array` is the array of opened ballots that the government
has access to.

The request/handler model has a few nice features. In particular,

1. It allows one to program in a direct style by pretending one has
  magical access to requested values.
2. It makes a clear distinction between values that are directly computed and
  non-deterministically chosen values that need to be constrained (with assertions)
  to ensure correctness.
3. It makes testing verifiable computations simple, as one can set up "malicious"
  handlers that provide values other than the intended ones. The purpose here is
  to check that the assertions made by the computation do in fact rule out all
  values besides the intended ones.

# Wrapping up

Snarky helps us bridge the gap between high-level properties we want to prove using
verifiable computations, and the low-level constraint systems we need to provide to SNARK constructions.
It brings the promise of accountability and control over personal data through
verifiable computing one step closer to practicality.
The code is available on [github](https://github.com/o1-labs/snarky), and we at O(1) 
Labs are using it in the development of our new cryptocurrency protocol that aims
to power the examples described above and more.

If you find what we're doing interesting, we're hiring. You can find more
info [here](https://o1labs.org/jobs.html). You can also sign up for
our mailing list [here](/#contact).
