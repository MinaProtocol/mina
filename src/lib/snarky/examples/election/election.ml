open Core
open Snarky
open Impl
open Import
open Let_syntax

(* First we declare the type of "votes" and call a library functor [Enumerable] to
   make it possible to refer to values of type [Vote.t] in checked computations. *)
module Vote = struct
  module T = struct
    type t = Pepperoni | Mushroom [@@deriving enum]
  end

  include T
  include Enumerable (T)
end

module Ballot = struct
  module Opened = struct
    module Nonce = Field

    (* An opened ballot is a nonce along with a vote. *)
    type t = Nonce.t * Vote.t

    type var = Nonce.var * Vote.var

    (* A [typ] is a kind of specification of a type of data which makes it possible
       to use values of that type inside checked computations. In a future version of
       the library, [typ]s will be derived automatically with a ppx extension. *)
    let typ = Typ.(Nonce.typ * Vote.typ)

    let to_bits (nonce, vote) = Nonce.to_bits nonce @ Vote.to_bits vote

    (* This is our first explicit example of a checked computation. It simply says that to
   convert an opened ballot into bits, one converts the nonce and the vote into bits and
   concatenates them. Behind the scenes, this function would set up all the constraints
   necessary to certify the correctness of this computation with a snark. *)
    let var_to_bits (nonce, vote) =
      let%map nonce_bits = Nonce.var_to_bits nonce
      and vote_bits = Vote.var_to_bits vote in
      nonce_bits @ vote_bits

    let create vote : t = (Field.random (), vote)
  end

  (* A closed ballot is simply a hash *)
  module Closed = Hash
end

(* Here we have a checked computation for "closing" an opened ballot. In other words,
   turning the ballot into a commitment. *)
let close_ballot_var (ballot : Ballot.Opened.var) =
  let%bind bs = Ballot.Opened.var_to_bits ballot in
  Hash.hash_var bs

let close_ballot (ballot : Ballot.Opened.t) =
  Hash.hash (Ballot.Opened.to_bits ballot)

(* Checked computations in Snarky are allowed to ask for help.
   This adds a new kind of "help request" a checked computation can make:
   [Open_ballot i] is a request for the opened ballot corresponding to voter [i].
*)
type _ Request.t += Open_ballot : int -> Ballot.Opened.t Request.t

(* Here we write a checked function [open_ballot], which given a voter index [i]
   and a closed ballot (i.e., a commitment) [closed], produces the corresponding
   opened ballot (i.e., the value committed to).

   This seems odd, since commitments are supposed to be hiding. That is, there should
   be no way to compute the committed value from the commitment which this checked function
   is supposed to do. The trick is that checked computations are allowed to ask for help
   and then verify that the help was useful. In this case, we [request] for someone out there
   to provide us with an opening to our commitment, and then check that it is indeed a
   correct opening of our closed ballot, before returning it as the result of the function. *)
let open_ballot i (commitment : Ballot.Closed.var) =
  let%map _, vote =
    request Ballot.Opened.typ (Open_ballot i) ~such_that:(fun opened ->
        let%bind implied = close_ballot_var opened in
        Ballot.Closed.assert_equal commitment implied )
  in
  vote

(* Now we write a simple checked function counting up all the votes for pepperoni in a
   given list of votes. *)
let count_pepperoni_votes vs =
  let open Number in
  Checked.List.fold vs ~init:(constant Field.zero) ~f:(fun acc v ->
      let%bind pepperoni_vote = Vote.(v = var Pepperoni) in
      Number.if_ pepperoni_vote
        ~then_:(acc + constant Field.one)
        ~else_:(acc + constant Field.zero) )

(* Aside for experts: This function could be much more efficient since a Candidate
   is just a bool which can be coerced to a cvar (thus requiring literally no constraints
   to just sum up). It's written this way for pedagogical purposes. *)
(* Now we can put it all together to write a verifiable computation computing the winner: *)
let winner ballots =
  let open Number in
  let half = constant (Field.of_int (List.length ballots / 2)) in
  (* First we open all the ballots *)
  let%bind votes = Checked.List.mapi ~f:open_ballot ballots in
  (* Then we sum up all the votes (we only have to sum up the pepperoni votes
     since the mushroom votes are N - pepperoni votes)
  *)
  let%bind pepperoni_vote_count = count_pepperoni_votes votes in
  let%bind pepperoni_wins = pepperoni_vote_count > half in
  Vote.(if_ pepperoni_wins ~then_:(var Pepperoni) ~else_:(var Mushroom))

let number_of_voters = 11

let check_winner commitments claimed_winner =
  let%bind w = winner commitments in
  Vote.assert_equal w claimed_winner

(* This specifies the data that will be exposed in the statement we're proving:
   a list of closed ballots (commitments to votes) and the winner. *)
let exposed () =
  Data_spec.[Typ.list ~length:number_of_voters Ballot.Closed.typ; Vote.typ]

let keypair = generate_keypair check_winner ~exposing:(exposed ())

let winner (ballots : Ballot.Opened.t array) =
  let pepperoni_votes =
    Array.count ballots ~f:(function
      | _, Pepperoni -> true
      | _, Mushroom -> false )
  in
  if pepperoni_votes > Array.length ballots / 2 then Vote.Pepperoni
  else Mushroom

let tally_and_prove (ballots : Ballot.Opened.t array) =
  let commitments =
    List.init number_of_voters ~f:(fun i ->
        Hash.hash (Ballot.Opened.to_bits ballots.(i)) )
  in
  let winner = winner ballots in
  let handled_check commitments claimed_winner =
    (* As mentioned before, a checked computation can request help from outside.
       Here is where we answer those requests (or at least some of them). *)
    handle (check_winner commitments claimed_winner)
      (fun (With {request; respond}) ->
        match request with
        | Open_ballot i -> respond (Provide ballots.(i))
        | _ -> unhandled )
  in
  ( commitments
  , winner
  , prove (Keypair.pk keypair) (exposed ()) () handled_check commitments winner
  )
