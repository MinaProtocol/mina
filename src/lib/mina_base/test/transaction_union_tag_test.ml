open Core_kernel
open Mina_base

let test_predicate checked unchecked () =
  let open Transaction_union_tag in
  let checked x = Snark_params.Tick.Checked.return (checked x) in
  for i = min to max do
    Test_util.test_equal unpacked_typ Snark_params.Tick.Boolean.typ checked
      unchecked
      (Option.value_exn (of_enum i))
  done

let one_of xs t = List.mem xs ~equal:Transaction_union_tag.equal t

let is_payment =
  test_predicate Transaction_union_tag.Unpacked.is_payment
    (Transaction_union_tag.equal Transaction_union_tag.Payment)

let is_stake_delegation =
  test_predicate Transaction_union_tag.Unpacked.is_stake_delegation
    (Transaction_union_tag.equal Transaction_union_tag.Stake_delegation)

let is_fee_transfer =
  test_predicate Transaction_union_tag.Unpacked.is_fee_transfer
    (Transaction_union_tag.equal Transaction_union_tag.Fee_transfer)

let is_coinbase =
  test_predicate Transaction_union_tag.Unpacked.is_coinbase
    (Transaction_union_tag.equal Transaction_union_tag.Coinbase)

let is_user_command =
  test_predicate Transaction_union_tag.Unpacked.is_user_command
    (one_of Transaction_union_tag.[ Payment; Stake_delegation ])

let not_user_command =
  test_predicate
    (fun x ->
      Snark_params.Tick.Boolean.not
        (Transaction_union_tag.Unpacked.is_user_command x) )
    (one_of Transaction_union_tag.[ Fee_transfer; Coinbase ])

let bit_representation () =
  let open Transaction_union_tag in
  for i = min to max do
    Test_util.test_equal unpacked_typ Bits.typ
      (Fn.compose Snark_params.Tick.Checked.return Unpacked.to_bits_var)
      bits_t_of_t
      (Option.value_exn (of_enum i))
  done
