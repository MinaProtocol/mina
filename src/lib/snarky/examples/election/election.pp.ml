open Core
open Snarky
open Impl
open Import
open Let_syntax

module Vote = struct
  module T = struct
    type t = Pepperoni | Mushroom [@@deriving enum]

    let min = 0

    and max = 1

    and to_enum = function Mushroom -> 1 | Pepperoni -> 0

    and of_enum = function
      | 1 -> Some Mushroom
      | 0 -> Some Pepperoni
      | _ -> None

    let _ = fun (_ : t) -> ()
  end

  include T
  include Enumerable (T)
end

module Ballot = struct
  module Opened = struct
    module Nonce = Field

    include struct
      type nonrec ('hash, 'nat, 'time) polymorphic =
        {length: 'nat; timestamp: 'time; previous_hash: 'hash; next_hash: 'hash}

      let length {length; _} = length

      and timestamp {timestamp; _} = timestamp

      and previous_hash {previous_hash; _} = previous_hash

      and next_hash {next_hash; _} = next_hash

      module T = struct
        type nonrec t = (Hash.T.t, Nat.T.t, Time.T.t) polymorphic
      end

      include T

      module Snarkable = struct
        type nonrec t =
          (Hash.Snarkable.t, Nat.Snarkable.t, Time.Snarkable.t) polymorphic

        let typ =
          let store {length; timestamp; previous_hash; next_hash} =
            Typ.Store.bind (Typ.store Hash.Snarkable.typ next_hash)
              (fun next_hash ->
                Typ.Store.bind (Typ.store Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Store.bind (Typ.store Time.Snarkable.typ timestamp)
                      (fun timestamp ->
                        Typ.Store.bind (Typ.store Nat.Snarkable.typ length)
                          (fun length ->
                            Typ.Store.return
                              {length; timestamp; previous_hash; next_hash} )
                    ) ) )
          in
          let read {length; timestamp; previous_hash; next_hash} =
            Typ.Read.bind (Typ.read Hash.Snarkable.typ next_hash)
              (fun next_hash ->
                Typ.Read.bind (Typ.read Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Read.bind (Typ.read Time.Snarkable.typ timestamp)
                      (fun timestamp ->
                        Typ.Read.bind (Typ.read Nat.Snarkable.typ length)
                          (fun length ->
                            Typ.Read.return
                              {length; timestamp; previous_hash; next_hash} )
                    ) ) )
          in
          let alloc {length; timestamp; previous_hash; next_hash} =
            Typ.Alloc.bind (Typ.alloc Hash.Snarkable.typ next_hash)
              (fun next_hash ->
                Typ.Alloc.bind (Typ.alloc Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Alloc.bind (Typ.alloc Time.Snarkable.typ timestamp)
                      (fun timestamp ->
                        Typ.Alloc.bind (Typ.alloc Nat.Snarkable.typ length)
                          (fun length ->
                            Typ.Alloc.return
                              {length; timestamp; previous_hash; next_hash} )
                    ) ) )
          in
          let check {length; timestamp; previous_hash; next_hash} =
            Typ.Check.bind (Typ.check Hash.Snarkable.typ next_hash)
              (fun next_hash ->
                Typ.Check.bind (Typ.check Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Check.bind (Typ.check Time.Snarkable.typ timestamp)
                      (fun timestamp ->
                        Typ.Check.bind (Typ.check Nat.Snarkable.typ length)
                          (fun length ->
                            Typ.Check.return
                              {length; timestamp; previous_hash; next_hash} )
                    ) ) )
          in
          {store; read; alloc; check}

        let length_in_bits t =
          Pervasives.( + )
            (Nat.Snarkable.length_in_bits t.length)
            (Pervasives.( + )
               (Time.Snarkable.length_in_bits t.timestamp)
               (Pervasives.( + )
                  (Hash.Snarkable.length_in_bits t.previous_hash)
                  (Hash.Snarkable.length_in_bits t.next_hash)))

        let fold t =
          Fold_lib.( +> )
            (Nat.Snarkable.fold t.length)
            (Fold_lib.( +> )
               (Time.Snarkable.fold t.timestamp)
               (Fold_lib.( +> )
                  (Hash.Snarkable.fold t.previous_hash)
                  (Hash.Snarkable.fold t.next_hash)))

        let var_to_triples t =
          Pervasives.( @ )
            (Nat.Snarkable.var_to_triples t.length)
            (Pervasives.( @ )
               (Time.Snarkable.var_to_triples t.timestamp)
               (Pervasives.( @ )
                  (Hash.Snarkable.var_to_triples t.previous_hash)
                  (Hash.Snarkable.var_to_triples t.next_hash)))

        let length_in_triples t =
          Pervasives.( + )
            (Nat.Snarkable.length_in_triples t.length)
            (Pervasives.( + )
               (Time.Snarkable.length_in_triples t.timestamp)
               (Pervasives.( + )
                  (Hash.Snarkable.length_in_triples t.previous_hash)
                  (Hash.Snarkable.length_in_triples t.next_hash)))
      end
    end

    type t = Nonce.t * Vote.t

    type var = Nonce.var * Vote.var

    let typ =
      let open Typ in
      Nonce.typ * Vote.typ

    let to_bits (nonce, vote) = Nonce.to_bits nonce @ Vote.to_bits vote

    let var_to_bits (nonce, vote) =
      let __let_syntax__001_ = Nonce.var_to_bits nonce
      and __let_syntax__002_ = Vote.var_to_bits vote in
      Let_syntax.map (Let_syntax.both __let_syntax__001_ __let_syntax__002_)
        ~f:(fun (nonce_bits, vote_bits) -> nonce_bits @ vote_bits )

    let create vote : t = (Field.random (), vote)
  end

  module Closed = Hash
end

let close_ballot_var (ballot : Ballot.Opened.var) =
  Let_syntax.bind (Ballot.Opened.var_to_bits ballot) ~f:(fun bs ->
      Hash.hash_var bs )

let close_ballot (ballot : Ballot.Opened.t) =
  Hash.hash (Ballot.Opened.to_bits ballot)

type _ Request.t += Open_ballot : int -> Ballot.Opened.t Request.t

let open_ballot i (commitment : Ballot.Closed.var) =
  Let_syntax.map
    (request Ballot.Opened.typ (Open_ballot i) ~such_that:(fun opened ->
         Let_syntax.bind (close_ballot_var opened) ~f:(fun implied ->
             Ballot.Closed.assert_equal commitment implied ) ))
    ~f:(fun (_, vote) -> vote)

let count_pepperoni_votes vs =
  let open Number in
  Checked.List.fold vs ~init:(constant Field.zero) ~f:(fun acc v ->
      Let_syntax.bind
        (let open Vote in
        v = var Pepperoni)
        ~f:(fun pepperoni_vote ->
          Number.if_ pepperoni_vote
            ~then_:(acc + constant Field.one)
            ~else_:(acc + constant Field.zero) ) )

let winner ballots =
  let open Number in
  let half = constant (Field.of_int (List.length ballots / 2)) in
  Let_syntax.bind (Checked.List.mapi ~f:open_ballot ballots) ~f:(fun votes ->
      Let_syntax.bind (count_pepperoni_votes votes)
        ~f:(fun pepperoni_vote_count ->
          Let_syntax.bind (pepperoni_vote_count > half)
            ~f:(fun pepperoni_wins ->
              let open Vote in
              if_ pepperoni_wins ~then_:(var Pepperoni) ~else_:(var Mushroom)
          ) ) )

let number_of_voters = 11

let check_winner commitments claimed_winner =
  Let_syntax.bind (winner commitments) ~f:(fun w ->
      Vote.assert_equal w claimed_winner )

let exposed () =
  let open Data_spec in
  [Typ.list ~length:number_of_voters Ballot.Closed.typ; Vote.typ]

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
