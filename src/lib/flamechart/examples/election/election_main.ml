open Election
open Core
open Impl

(* Election day! The time has come for citizens to cast their ballots for
   pizza toppings: will it be pepperoni? Or will mushroom win the day?

   But there is a slight problem:
   Reports suggest that there have been attempts to hack the software that
   tabulates votes and determines the winner. As such, the government has decided
   that the election results should be accompanied by a proof of their correctness.
   The scheme is as follows:

   Let $H$ be a hash function and say there are $n$ voters who must all vote.
   - Each voter $i$ will provide the government with their vote $v_i$ along with
     a random nonce $x_i$ for a commitment $h_i = H(x_i, v_i)$.
   - Each voter will also publish that commitment $h_i$.
   - The government will compute the result of the election, either pepperoni or mushroom.
   - The government will prove in zero knowledge the following statement:
      Exposing the commitments $h_1, \dots, h_n$ and the winner $w$,
      there exist $(x_1, v_1), \dots, (x_n, v_n)$ such that
      - For each $i$, $H(x_i, v_i) = h_i$.
      - if the number of votes for Pepperoni is greater than n / 2, $w$ is Pepperoni,
        otherwise, $w$ is Mushroom.
   - Finally each voter verifies the government's proof against the claimed winner $w$
     and the commitments $h_1, \dots, h_n$.

   In plain English, the government will prove "I know votes corresponding to the commitments $h_i$
   such that taking the majority of those votes results in winner $w$".
*)
(* This is an example usage of the above "election proof system".
   To see how this is actually implemented using Snarky, check out election.ml.
*)

module Constraints = Flamechart.Snarky_log.Constraints (Impl)

let () =
  (* Mock data *)
  let received_ballots =
    Array.init number_of_voters ~f:(fun _ ->
        Ballot.Opened.create (if Random.bool () then Pepperoni else Mushroom)
    )
  in
  let commitments, winner, proof = tally_and_prove received_ballots in
  let log_events =
    Constraints.log_func ~input:(exposed ()) (handled_check received_ballots)
      ~apply_args:(fun c -> c commitments winner )
  in
  Flamechart.to_file "output.json" log_events ;
  assert (verify proof (Keypair.vk keypair) (exposed ()) commitments winner)
