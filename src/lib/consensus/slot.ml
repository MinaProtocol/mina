open Core_kernel
open Snark_params
open Signed
open Unsigned

module T = Coda_numbers.Nat.Make32 ()

include (T : module type of T with module Checked := T.Checked)

let in_seed_update_range ~(constants : Constants.t) (slot : t) =
  let open UInt32.Infix in
  (* TODO: This must be 1/3 of the epoch length *)
  let ck = constants.c * constants.k in
  slot < ck * UInt32.of_int 2

module Checked = struct
  include T.Checked

  let in_seed_update_range ~(constants : Constants.var) (slot : var) =
    let open Tick in
    let open Tick.Let_syntax in
    let open Snarky_integer in
    let module Length = Coda_numbers.Length in
    let integer_mul i i' = make_checked (fun () -> Integer.mul ~m i i') in
    let to_integer = Length.Checked.to_integer in
    let%bind ck =
      integer_mul (to_integer constants.c) (to_integer constants.k)
    in
    let two = Integer.constant ~m (Bignum_bigint.of_int 2) in
    let%bind ck_times_2 = integer_mul ck two in
    make_checked (fun () ->
        Integer.lt ~m (T.Checked.to_integer slot) ck_times_2 )
end

let gen (constants : Constants.t) =
  let open Quickcheck.Let_syntax in
  let ck3 =
    UInt32.Infix.(constants.c * constants.k * UInt32.of_int 3) |> UInt32.to_int
  in
  Core.Int.gen_incl 0 ck3 >>| UInt32.of_int

let%test_unit "in_seed_update_range unchecked vs. checked equality" =
  let constants = Lazy.force Constants.for_unit_tests in
  let module Length = Coda_numbers.Length in
  let test x =
    Test_util.test_equal
      (Snarky_backendless.Typ.tuple2 Constants.typ typ)
      Tick.Boolean.typ
      (fun (c, x) -> Checked.in_seed_update_range ~constants:c x)
      (fun (c, x) -> in_seed_update_range ~constants:c x)
      (constants, x)
  in
  let x = UInt32.mul constants.c constants.k |> UInt32.to_int in
  let examples =
    List.map ~f:UInt32.of_int [x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1]
  in
  Quickcheck.test ~trials:100 ~examples (gen constants) ~f:test
