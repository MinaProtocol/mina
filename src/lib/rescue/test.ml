open Core_kernel
open Snark_params
open Tick

let () =
  constraint_count
    (let ( >>= ) = Tick.Let_syntax.( >>= ) in
     let unp = Field.Checked.choose_preimage_var ~length:Field.size_in_bits in
     exists Field.typ >>= unp
     >>= fun x ->
     exists Field.typ >>= unp
     >>= fun y ->
     Pedersen.Checked.hash_triples
       ~init:(Pedersen.State.salt "foo")
       (Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_
          (x @ y)))
  |> printf "%d\n%!"

include Rescue.Make (Snark_params.Tick.Run)
