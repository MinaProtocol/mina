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

let nth_bit x n = (x lsr n) land 1 = 1

let list_to_triple_exn = function
  | [x0; x1; x2] ->
      (x0, x1, x2)
  | _ ->
      failwith "expected a list of length 3"

let triple_to_list (x0, x1, x2) = [x0; x1; x2]

let to_bits tag = List.init 3 ~f:(nth_bit (to_enum tag)) |> list_to_triple_exn

let of_bits_exn bits =
  Option.value_exn
    ~error:(Error.of_string "unrecognized bits")
    ( List.fold_right (triple_to_list bits) ~init:0 ~f:(fun b acc ->
          (2 * acc) + Bool.to_int b )
    |> of_enum )

let%test_unit "to_bits of_bits inv" =
  let open Quickcheck in
  test
    (Generator.tuple3 Bool.quickcheck_generator Bool.quickcheck_generator
       (Generator.return false))
    ~f:(fun b -> assert (b = to_bits (of_bits_exn b)))

let typ =
  Typ.transport
    Typ.(tuple3 Boolean.typ Boolean.typ Boolean.typ)
    ~there:to_bits ~back:of_bits_exn

let fold (tag : t) : bool Triple.t Fold.t =
  { fold=
      (fun ~init ~f ->
        let b0, b1, b2 = to_bits tag in
        f init (b0, b1, b2) ) }

let length_in_triples = 1

module Checked = struct
  open Let_syntax

  let constant tag =
    let b0, b1, b2 = to_bits tag in
    Boolean.(var_of_value b0, var_of_value b1, var_of_value b2)

  let to_triples bits = [bits]

  let is tag triple =
    let xs = triple_to_list (to_bits tag) in
    let ys = triple_to_list triple in
    let eq x y = if x then y else Boolean.not y in
    List.map2_exn xs ys ~f:eq |> Boolean.all

  let is_payment triple = is Payment triple

  let is_fee_transfer triple = is Fee_transfer triple

  let is_stake_delegation triple = is Stake_delegation triple

  let is_coinbase triple = is Coinbase triple

  let is_chain_voting triple = is Chain_voting triple

  let is_user_command triple =
    Checked.all
      [is_payment triple; is_stake_delegation triple; is_chain_voting triple]
    >>= Boolean.any

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
