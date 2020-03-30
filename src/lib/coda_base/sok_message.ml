open Core
open Import
open Module_version

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  {fee: Currency.Fee.t; prover: Public_key.Compressed.t}
[@@deriving sexp, yojson]

let create ~fee ~prover = Stable.Latest.{fee; prover}

module Digest = struct
  let length_in_bytes = Blake2.digest_size_in_bytes

  module Stable = struct
    module V1 = struct
      module T = struct
        type t = string [@@deriving sexp, hash, compare, eq, yojson, version]

        include Binable.Of_binable
                  (String)
                  (struct
                    type nonrec t = t

                    let to_binable = Fn.id

                    let of_binable s =
                      assert (String.length s = length_in_bytes) ;
                      s
                  end)

        let to_input t =
          Random_oracle.Input.bitstring Fold_lib.Fold.(to_list (string_bits t))

        let typ =
          let open Snark_params.Tick in
          Typ.array ~length:Blake2.digest_size_in_bits Boolean.typ
          |> Typ.transport ~there:Blake2.string_to_bits
               ~back:Blake2.bits_to_string
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "sok_message_digest"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted intentionally *)
  type t = Stable.Latest.t [@@deriving sexp, eq, yojson]

  module Checked = struct
    open Snark_params.Tick

    type t = Boolean.var array

    let to_input t = Random_oracle.Input.bitstring (Array.to_list t)
  end

  [%%define_locally
  Stable.Latest.(to_input, typ)]

  let default = String.init length_in_bytes ~f:(fun _ -> '\000')
end

let digest t =
  Blake2.to_raw_string
    (Blake2.digest_string (Binable.to_string (module Stable.Latest) t))
