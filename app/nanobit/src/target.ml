open Core_kernel
open Nanobit_base
open Snark_params

type t = Tick.Field.t
[@@deriving bin_io]

let of_field = Fn.id

let meets_target t ~hash =
  let module B = Tick_curve.Bigint.R in
  B.compare (B.of_field t) (B.of_field hash) < 0
;;

include Bits.Snarkable.Field(Tick)

let assert_mem x xs =
  let open Tick in
  let open Let_syntax in
  let rec go acc = function
    | [] -> Boolean.Assert.any acc
    | y :: ys ->
      let%bind e = Checked.equal x y in
      go (e :: acc) ys
  in
  go [] xs
;;

let strength_unchecked (target : t) =
  failwith "TODO"
;;

(* floor(size of field / target) *)
let strength (target : Packed.var) =
  let open Tick in
  let open Let_syntax in
  let%bind z = exists Var_spec.field As_prover.(map (read_var target) ~f:strength_unchecked) in
  (* numbits(z) + numbits(target) = Field.size_in_bits or Field.size_in_bits - 1 or ?
     and 
     (z + 1) * target < target
  *)
  (* num_bits unpacks. This is wasteful since target gets unpacked elsewhere *)
  let%bind target_bit_size = Util.num_bits target in
  let%bind z_bit_size = Util.num_bits z in
  let b = Cvar.Infix.(target_bit_size + z_bit_size) in
  let%bind () =
    assert_mem b
      [ Cvar.constant Field.(of_int size_in_bits)
      ; Cvar.constant Field.(of_int (size_in_bits - 1))
      ]
  in
  let%map () =
    let%bind prod = Checked.mul Cvar.(Infix.(z + constant Field.one)) target in
    let%bind { less } = Util.compare ~bit_length:Field.size_in_bits prod target in
    Boolean.Assert.is_true less
  in
  z
;;
