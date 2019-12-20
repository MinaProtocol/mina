open Core_kernel
module T = Transaction_union_tag_functor.Make (Snark_params.Tick)
include T

let%test_module "predicates" =
  ( module struct
    open Snark_params.Tick
    open T.Checked

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

    let%test_unit "is_user_command" =
      test_predicate is_user_command (one_of [Payment; Stake_delegation])
  end )
