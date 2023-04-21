(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^transaction union tag$'
    Subject:    Test transaction union tags.
 *)

open Core_kernel
open Snark_params.Tick
open Mina_base
open Transaction_union_tag

let test_predicate checked unchecked =
  let checked x = Checked.return (checked x) in
  for i = min to max do
    Test_util.test_equal unpacked_typ Boolean.typ checked unchecked
      (Option.value_exn (of_enum i))
  done

let one_of xs t = List.mem xs ~equal t

(* These tests assert checked-unchecked equivalence of some functions
   operating on type t.*)
let is_payment () = test_predicate Unpacked.is_payment (equal Payment)

let is_stake_delegation () =
  test_predicate Unpacked.is_stake_delegation (equal Stake_delegation)

let is_fee_transfer () =
  test_predicate Unpacked.is_fee_transfer (equal Fee_transfer)

let is_coinbase () = test_predicate Unpacked.is_coinbase (equal Coinbase)

let is_user_command () =
  test_predicate Unpacked.is_user_command (one_of [ Payment; Stake_delegation ])

let not_user_command () =
  test_predicate
    (fun x -> Boolean.not (Unpacked.is_user_command x))
    (one_of [ Fee_transfer; Coinbase ])

let bit_representation () =
  for i = min to max do
    Test_util.test_equal unpacked_typ Bits.typ
      (Fn.compose Checked.return Unpacked.to_bits_var)
      bits_t_of_t
      (Option.value_exn (of_enum i))
  done
