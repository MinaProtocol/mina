(*
open Core
open Checked.Let_syntax

let request spec x = request_witness spec (As_prover.return x)

module Hash : sig
  type var
  type t
  val typ : (var, t) Var_spec.t
  val var_to_bits : var -> (Boolean.var list, _) Checked.t
  val to_bits : t -> bool list
  val hash_var : Boolean.var list -> (var, _) Checked.t
  val hash : bool list -> t
  val assert_equal : var -> var -> (unit, _) Checked.t
end = struct
  type var
  type t
  let typ = failwith "TODO"
  let hash = failwith "TODO"
  let var_to_bits = failwith "TODO"
  let to_bits = failwith "TODO"
  let assert_equal = failwith "TODO"
  let hash_var = failwith "TODO"
end

let int_of_bits bs =
  List.foldi bs ~init:0 ~f:(fun i acc b ->
    if b then acc + (1 lsl i) else acc)

let field_to_int _ = failwith "TODO"

(* Call Var_spec spec. Have field to int exn *)

module Card = struct
  module Suit = struct
    module T = struct
      type t =
        | Clubs
        | Diamonds
        | Hearts
        | Spades
      [@@deriving enum]
    end
    include T
    include Enumerable(T)
  end

  module Number = struct
    module T = struct
      type t =
        | Two | Three | Four | Five
        | Six | Seven | Eight | Nine | Ten
        | Jack
        | Queen
        | King
        | Ace
      [@@deriving enum]
    end
    include T
    include Enumerable(T)
  end

  type t = Suit.t * Number.t
  type var = Suit.var * Number.var
  let typ = Var_spec.(Suit.typ * Number.typ)

  let to_bits ((suit, number) : var) =
    let%map suit_bits = Suit.to_bits suit
    and number_bits = Number.to_bits number in
    suit_bits @ number_bits

  let assert_equal (s1, n1) (s2, n2) =
    Checked.all_ignore
      [ Suit.assert_equal s1 s2
      ; Number.assert_equal n1 n2
      ]
end

type _ Request.t +=
  | Deal : (Card.t * Hash.t) Request.t

module Card_stack = struct
  include Hash

  let push stack card =
    let%bind
      card_bits = Card.var_to_bits card
    and
      stack_bits = Hash.var_to_bits stack
    in
    Hash.hash_var (card_bits @ stack_bits)

  let deal_one stack =
    let%bind ((card, stack') as result) =
      request Var_spec.(Card.typ * typ) Deal
    in
    let%bind () =
      let%bind implied_stack = push stack' card in
      assert_equal stack implied_stack
    in
    return result
end

module Hand = struct
  let length = 5

  let typ = Var_spec.list ~length Card.typ

  let deal stack =
    let rec go hand stack i =
      if i = 0
      then return (List.rev hand)
      else
        let%bind (card, stack') = Card_stack.deal_one stack in
        go (card :: hand) stack' (i - 1)
    in
    go [] stack length

  let assert_equal h1 h2 =
    Checked.all_ignore (List.map2_exn ~f:Card.assert_equal h1 h2)
end

let check_deal hand initial_stack =
  let%bind dealt_hand = Hand.deal initial_stack in
  Hand.assert_equal hand dealt_hand

module Card_chain = struct
  type t = (Card.t * Hash.t) Linked_stack.t

  let pop = Linked_stack.pop_exn

  let of_list (deck : Card.t list) =
    let t = Linked_stack.create () in
    List.fold (List.rev deck) ~f:(fun hash ->
      Hash.t
end

module Prover = struct
  module State = Card_chain

  let handler state : Handler.t = fun (With {request; respond}) ->
    match request with
    | Deal ->
      let (card, hash) = Card_chain.pop state in
      respond (card, hash)
    | _ -> unhandled
end

let certify_deal (deck : Card.t list) =
  let card_chain = Card_chain.of_list deck in
  () *)
