open Core
open Camlsnark
open Impl
open Import
open Let_syntax

module Vote = struct
  module T = struct
    type t =
      | Pepperoni
      | Mushroom
    [@@deriving enum]
  end
  include T
  include Enumerable(T)
end

module Ballot = struct
  module Opened = struct
    module Nonce = Field

    type t = Nonce.t * Vote.t
    type var = Nonce.var * Vote.var
    let typ = Typ.(Nonce.typ * Vote.typ)

    let to_bits (nonce, candidate) =
      Nonce.to_bits nonce @ Vote.to_bits candidate

    let var_to_bits (nonce, candidate) =
      let%map nonce_bits = Nonce.var_to_bits nonce
      and candidate_bits = Vote.var_to_bits candidate
      in
      nonce_bits @ candidate_bits

    let create vote : t = (Field.random (), vote)
  end

  module Closed = Hash
end

let close_ballot_var (ballot : Ballot.Opened.var) =
  let%bind bs = Ballot.Opened.var_to_bits ballot in
  Hash.hash_var bs

let close_ballot (ballot : Ballot.Opened.t) =
  Hash.hash (Ballot.Opened.to_bits ballot)

type _ Request.t +=
  | Open_ballot : int -> Ballot.Opened.t Request.t

let open_ballot i (closed : Ballot.Closed.var) =
  let%bind ((_, vote) as opened) =
    request Ballot.Opened.typ (Open_ballot i)
  in
  let%bind () =
    let%bind implied_closed = close_ballot_var opened in
    Ballot.Closed.assert_equal implied_closed closed
  in
  return vote

(* This could be much more efficient since a Candidate is just a bool which can
   be coerced to a cvar (thus requiring literally no constraints to just sum up).
   It's written this way for pedagogical purposes. *)
let count_pepperoni_votes vs =
  let open Number in
  let rec go pepperoni_total vs =
    match vs with
    | [] -> return pepperoni_total
    | v :: vs' ->
      let%bind new_total =
        let%bind pepperoni_vote = Vote.(v = var Pepperoni) in
        if_ pepperoni_vote
          ~then_:(pepperoni_total + constant Field.one)
          ~else_:pepperoni_total
      in
      go new_total vs'
  in
  go (constant Field.zero) vs
;;

let pepperoni_wins ballots =
  let open Number in
  let total_votes = List.length ballots in
  let half = constant (Field.of_int (total_votes / 2)) in
  (* First we open all the ballots *)
  let%bind votes = Checked.all (List.mapi ~f:open_ballot ballots) in
  (* Then we sum up all the votes (we only have to sum up the pepperoni votes
     since the mushroom votes are N - pepperoni votes)
  *)
  let%bind pepperoni_vote_count = count_pepperoni_votes votes in
  pepperoni_vote_count > half
;;

let number_of_voters = 11

let check_winner commitments claimed_winner =
  let%bind p = pepperoni_wins commitments in
  Boolean.Assert.(p = claimed_winner)

let exposed () =
  let open Data_spec in
  [ Typ.list ~length:number_of_voters Ballot.Closed.typ
  ; Boolean.typ
  ]

let keypair = generate_keypair check_winner ~exposing:(exposed ())

let tally_and_prove (ballots : Ballot.Opened.t array) =
  let commitments =
    List.init number_of_voters ~f:(fun i ->
      Hash.hash (Ballot.Opened.to_bits ballots.(i)))
  in
  let pepperoni_wins =
    let pepperoni_votes =
      Array.count ballots ~f:(function
        | (_, Pepperoni) -> true | (_, Mushroom) -> false)
    in
    pepperoni_votes > Array.length ballots / 2
  in
  let handled_check commitments claimed_winner =
    handle
      (check_winner commitments claimed_winner)
      (fun (With {request; respond}) ->
        match request with
        | Open_ballot i -> respond ballots.(i)
        | _ -> unhandled)
  in
  ( commitments
  , pepperoni_wins
  , prove (Keypair.pk keypair) (exposed ()) () handled_check
      commitments pepperoni_wins
  )

let () =
  (* Mock data *)
  let received_ballots =
    Array.init number_of_voters ~f:(fun _ ->
      (Ballot.Opened.create
        (if Random.bool () then Pepperoni else Mushroom)))
  in
  let (commitments, pepperoni_wins, proof) = tally_and_prove received_ballots in
  assert
    (verify proof (Keypair.vk keypair) (exposed ())
       commitments pepperoni_wins)

