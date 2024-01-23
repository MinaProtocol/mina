open Core_kernel
open Snark_params
open Unsigned

module T = Mina_numbers.Nat.Make32 ()

include (T : module type of T with module Checked := T.Checked)

let in_seed_update_range ~(constants : Constants.t) (slot : t) =
  let open UInt32.Infix in
  let third_epoch = constants.slots_per_epoch / UInt32.of_int 3 in
  assert (UInt32.(equal constants.slots_per_epoch (of_int 3 * third_epoch))) ;
  slot < third_epoch * UInt32.of_int 2

module Checked = struct
  include T.Checked

  let in_seed_update_range ~(constants : Constants.var) (slot : var) =
    let open Tick in
    let open Snarky_integer in
    let module Length = Mina_numbers.Length in
    let integer_mul i i' = make_checked (fun () -> Integer.mul ~m i i') in
    let to_integer = Length.Checked.to_integer in
    let%bind third_epoch =
      make_checked (fun () ->
          let q, r =
            Integer.div_mod ~m
              (to_integer constants.slots_per_epoch)
              (Integer.constant ~m (Bignum_bigint.of_int 3))
          in
          Tick.Run.Boolean.Assert.is_true
            (Integer.equal ~m r (Integer.constant ~m Bignum_bigint.zero)) ;
          q )
    in
    let two = Integer.constant ~m (Bignum_bigint.of_int 2) in
    let%bind ck_times_2 = integer_mul third_epoch two in
    make_checked (fun () ->
        Integer.lt ~m (T.Checked.to_integer slot) ck_times_2 )
end

let gen (constants : Constants.t) =
  let open Quickcheck.Let_syntax in
  let epoch_length = constants.slots_per_epoch |> UInt32.to_int in
  Core.Int.gen_incl 0 epoch_length >>| UInt32.of_int

let%test_unit "in_seed_update_range unchecked vs. checked equality" =
  let constants = Lazy.force Constants.for_unit_tests in
  let module Length = Mina_numbers.Length in
  let test x =
    Test_util.test_equal
      (Snarky_backendless.Typ.tuple2 Constants.typ typ)
      Tick.Boolean.typ
      (fun (c, x) -> Checked.in_seed_update_range ~constants:c x)
      (fun (c, x) -> in_seed_update_range ~constants:c x)
      (constants, x)
  in
  let x =
    UInt32.div constants.slots_per_epoch (UInt32.of_int 3) |> UInt32.to_int
  in
  let examples =
    List.map ~f:UInt32.of_int
      [ x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1 ]
  in
  Quickcheck.test ~trials:100 ~examples (gen constants) ~f:test
