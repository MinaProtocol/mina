open Snark_params

type t = Tick.Field.t * Tick.Field.t
[@@deriving bin_io]

type var = Tick.Field.var * Tick.Field.var
let typ : (var, t) Tick.Typ.t = Tick.Typ.(field * field)

(* TODO: We can move it onto the subgroup during account creation. No need to check with
  every transaction *)

module Compressed = struct
  open Tick
  type t = Field.t [@@deriving bin_io]
  type var = Field.var
  let typ : (var, t) Typ.t = Typ.field
  let assert_equal (x : var) (y : var) = assert_equal x y

(* TODO: Right now everyone could switch to using the other unpacking...
   Either decide this is ok or assert bitstring lt field size *)
  let var_to_bits (pk : var) =
    Checked.choose_preimage pk ~length:Field.size_in_bits
end

let compress_var : var -> Compressed.var = fun _ -> failwith "TODO"
let decompress_var : Compressed.var -> var = fun _ -> failwith "TODO"
let assert_equal : var -> var -> (unit, _) Tick.Checked.t = fun _ _ -> failwith "TODO"
