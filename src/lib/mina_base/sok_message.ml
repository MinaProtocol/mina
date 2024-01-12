open Core_kernel
open Mina_base_util
open Mina_base_import
module Wire_types = Mina_wire_types.Mina_base.Sok_message

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Sok_message_intf.Full with type Digest.t = A.Digest.V1.t
end

module Make_str (A : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fee : Currency.Fee.Stable.V1.t
        ; prover : Public_key.Compressed.Stable.V1.t
        }
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]

  let create ~fee ~prover = Stable.Latest.{ fee; prover }

  module Digest = struct
    let length_in_bytes = Blake2.digest_size_in_bytes

    [%%versioned_binable
    module Stable = struct
      module V1 = struct
        type t = string [@@deriving sexp, hash, compare, equal, yojson]

        let to_latest = Fn.id

        include
          Binable.Of_binable_without_uuid
            (Core_kernel.String.Stable.V1)
            (struct
              type nonrec t = t

              let to_binable = Fn.id

              let of_binable s =
                assert (String.length s = length_in_bytes) ;
                s
            end)

        open Snark_params.Tick

        let to_input t =
          Random_oracle.Input.Chunked.packeds
            (Array.of_list_map
               Fold_lib.Fold.(to_list (string_bits t))
               ~f:(fun b -> (field_of_bool b, 1)) )

        let typ =
          Typ.array ~length:Blake2.digest_size_in_bits Boolean.typ
          |> Typ.transport ~there:Blake2.string_to_bits
               ~back:Blake2.bits_to_string
      end
    end]

    module Checked = struct
      open Snark_params.Tick

      type t = Boolean.var array

      let to_input (t : t) =
        Random_oracle.Input.Chunked.packeds
          (Array.map t ~f:(fun b -> ((b :> Field.Var.t), 1)))
    end

    [%%define_locally Stable.Latest.(to_input, typ)]

    let default = String.init length_in_bytes ~f:(fun _ -> '\000')
  end

  let digest t =
    Blake2.to_raw_string
      (Blake2.digest_string (Binable.to_string (module Stable.Latest) t))
end

include Wire_types.Make (Make_sig) (Make_str)
