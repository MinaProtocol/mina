open Core_kernel
open Fold_lib
open Tuple_lib
open Snark_params.Tick

type t = Payment | Stake_delegation | Fee_transfer | Coinbase | Chain_voting
[@@deriving enum, eq, sexp]

let gen =
  Quickcheck.Generator.map (Int.gen_incl min max) ~f:(fun i ->
      Option.value_exn (of_enum i) )

type var = Boolean.var Triple.t

let nth_bit : int -> int -> bool = fun n i -> (n lsr i) land 1 = 1

let triple_to_list (x0, x1, x2) = [x0; x1; x2]

let list_to_triple = function
  | [x0; x1; x2] ->
      (x0, x1, x2)
  | _ ->
      failwith "expected a list of length 3"

let to_bits tag =
  List.init 3 ~f:(nth_bit (to_enum tag)) |> List.rev |> list_to_triple

let of_bits bits =
  Option.value_exn
    ~error:(Error.of_string "unrecognized bits")
    ( List.fold (triple_to_list bits) ~init:0 ~f:(fun acc b ->
          (2 * acc) + Bool.to_int b )
    |> of_enum )

let%test_unit "to_bits of_bits inv" =
  let open Quickcheck in
  test
    (Generator.tuple3 (Generator.return false) Bool.quickcheck_generator
       Bool.quickcheck_generator)
    ~f:(fun b -> assert (b = to_bits (of_bits b)))

let typ =
  Typ.transport
    Typ.(tuple3 Boolean.typ Boolean.typ Boolean.typ)
    ~there:to_bits ~back:of_bits

let fold (t : t) : bool Triple.t Fold.t =
  { fold=
      (fun ~init ~f ->
        let b0, b1, b2 = to_bits t in
        f init (b0, b1, b2) ) }

let length_in_triples = 1

module Checked = struct
  let constant t =
    let x, y, z = to_bits t in
    Boolean.(var_of_value x, var_of_value y, var_of_value z)

  let to_triples ((x, y, z) : var) = [(x, y, z)]

  (* someday: Make these all cached *)

  let is tag triple =
    let xs = List.map (triple_to_list (to_bits tag)) ~f:Boolean.var_of_value in
    let ys = triple_to_list triple in
    let open Checked in
    Core.List.map2_exn xs ys ~f:Boolean.equal |> Checked.all >>= Boolean.all

  let is_payment x = is Payment x

  let is_fee_transfer x = is Fee_transfer x

  let is_stake_delegation x = is Stake_delegation x

  let is_coinbase x = is Coinbase x

  let is_chain_voting x = is Chain_voting x

  let is_user_command bs =
    let%bind payment = is_payment bs
    and fee_transfer = is_stake_delegation bs
    and chain_voting = is_chain_voting bs in
    Boolean.any [payment; fee_transfer; chain_voting]

  let%test_module "predicates" =
    ( module struct
      let test_predicate checked unchecked =
        for i = min to max do
          Test_util.test_equal typ Boolean.typ checked unchecked
            (Option.value_exn (of_enum i))
        done

      let one_of xs t = List.mem xs ~equal t

      let%test_unit "is_payment" = test_predicate is_payment (( = ) Payment)

      let%test_unit "is_fee_transfer" =
        test_predicate is_fee_transfer (( = ) Fee_transfer)

      let%test_unit "is_coinbase" = test_predicate is_coinbase (( = ) Coinbase)

      let%test_unit "is_chain_voting" =
        test_predicate is_chain_voting (( = ) Chain_voting)

      let%test_unit "is_user_command" =
        test_predicate is_user_command
          (one_of [Payment; Stake_delegation; Chain_voting])
    end )
end
