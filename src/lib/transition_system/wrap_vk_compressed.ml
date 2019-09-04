open Core_kernel
open Tuple_lib
open Snark_params.Tick
open Run
open Verifier
open Verification_key.Compressed

type nonrec 'f t_ = ('f, 'f Triple.t) t_

type t = Field.t t_

(* TODO: Make the y_coordinate a "Bits.t" or something that caches the unpacking since
  decompress does the unpacking internally. *)
let to_bits ~unpack_field vk =
  let fq t = unpack_field t ~length:Field.size_in_bits in
  to_list' vk ~fq
    ~fqe:(fun x -> List.map (Pairing.Fqe.to_list x) ~f:fq)
    ~y_bits:(fun x ->
      unpack_field x ~length:(Y_bits.length ~input_size:Wrap.input_size) )
  |> List.concat

module Unchecked = struct
  type t = Field.Constant.t t_

  let of_backend_vk vk : t = Unchecked.compress (vk_of_backend_vk vk)
end

let typ = typ ~input_size:Wrap.input_size
