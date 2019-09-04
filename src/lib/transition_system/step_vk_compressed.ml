open Core_kernel
open Snark_params
open Tock
open Tuple_lib
open Bitstring_lib
open Verifier
open Verification_key.Compressed

type nonrec 'f t_ = ('f, 'f Double.t) t_

type t = Tick.Boolean.var list t_

let typ =
  let input_size = Step_input.size in
  let fq' size =
    let unpack, length =
      match size with
      | `Full ->
          (Field.unpack, Field.size_in_bits)
      | `Small n ->
          ((fun x -> List.take (Field.unpack x) n), n)
    in
    Tick.Typ.transport
      (Tick.Typ.list Tick.Boolean.typ ~length)
      ~there:unpack ~back:Field.project
  in
  let fq = fq' `Full in
  let fqe = Tick.Typ.tuple2 fq fq in
  typ' ~input_size ~fq ~fqe ~y_bits:(fq' (`Small (Y_bits.length ~input_size)))

let to_scalars vk = List.map ~f:Bitstring.Lsb_first.of_list (to_list vk)

(* TODO: Make the y_coordinate a "Bits.t" or something that caches the unpacking since
  decompress does the unpacking internally. *)
let to_bits ~unpack_field vk =
  let fq t = unpack_field t ~length:Field.size_in_bits in
  to_list' vk ~fq
    ~fqe:(fun x -> List.map (Pairing.Fqe.to_list x) ~f:fq)
    ~y_bits:(fun x ->
      unpack_field x ~length:(Y_bits.length ~input_size:Step_input.size) )
  |> List.concat

module Unchecked = struct
  type t = Field.t t_

  let of_backend_vk vk : t = Unchecked.compress (vk_of_backend_vk vk)
end
