open Core
open Import
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type t =
        { fee: Currency.Fee.Stable.V1.t
        ; prover: Public_key.Compressed.Stable.V1.t }
      [@@deriving bin_io, sexp, yojson]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "sok_message"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted intentionally *)
type t = Stable.Latest.t =
  {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
[@@deriving sexp, yojson]

let create ~fee ~prover = Stable.Latest.{fee; prover}

module Digest = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        include Random_oracle.Digest.Stable.V1

        let fold, typ, length_in_triples =
          Random_oracle.Digest.(fold, typ, length_in_triples)
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

  module Checked = Random_oracle.Digest.Checked

  let fold, typ, length_in_triples =
    Stable.Latest.(fold, typ, length_in_triples)

  let default =
    let open Random_oracle.Digest in
    of_string (String.init length_in_bytes ~f:(fun _ -> '\000'))
end

let digest t =
  Random_oracle.digest_string (Binable.to_string (module Stable.Latest.T) t)
