open Core_kernel
open Snark_params
open Signed
open Unsigned

module T = Coda_numbers.Nat.Make32 ()

include (T : module type of T with module Checked := T.Checked)

let in_seed_update_range (slot : t) =
  let constants = (Coda_constants.t ()).consensus in
  let ck = constants.c * constants.k |> UInt32.of_int in
  let open UInt32.Infix in
  ck <= slot && slot < ck * UInt32.of_int 2

module Checked = struct
  include T.Checked

  let in_seed_update_range (slot : var) =
    let uint32_msb (x : UInt32.t) =
      List.init 32 ~f:(fun i ->
          let open UInt32 in
          let open Infix in
          let ( = ) x y = Core.Int.equal (compare x y) 0 in
          (x lsr Int.sub 31 i) land UInt32.one = UInt32.one )
      |> Bitstring_lib.Bitstring.Msb_first.of_list
    in
    let open Tick in
    let open Tick.Let_syntax in
    let ( < ) = Bitstring_checked.lt_value in
    let constants = (Coda_constants.t ()).consensus in
    let ck = constants.c * constants.k |> UInt32.of_int in
    let ck_bitstring = uint32_msb ck
    and ck_times_2 = uint32_msb UInt32.(Infix.(of_int 2 * ck)) in
    let%bind slot_msb =
      to_bits slot >>| Bitstring_lib.Bitstring.Msb_first.of_lsb_first
    in
    let%bind slot_gte_ck = slot_msb < ck_bitstring >>| Boolean.not
    and slot_lt_ck_times_2 = slot_msb < ck_times_2 in
    Boolean.(slot_gte_ck && slot_lt_ck_times_2)
end

let gen =
  let open Quickcheck.Let_syntax in
  let constants = (Coda_constants.t ()).consensus in
  Core.Int.gen_incl 0 (constants.c * constants.k * 3) >>| UInt32.of_int

let%test_unit "in_seed_update_range unchecked vs. checked equality" =
  let test =
    Test_util.test_equal typ Tick.Boolean.typ Checked.in_seed_update_range
      in_seed_update_range
  in
  let constants = (Coda_constants.t ()).consensus in
  let x = constants.c * constants.k in
  let examples =
    List.map ~f:UInt32.of_int [x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1]
  in
  Quickcheck.test ~trials:100 ~examples gen ~f:test
