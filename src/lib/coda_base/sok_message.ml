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
      [@@deriving bin_io, sexp]
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

include Stable.Latest

let create ~fee ~prover = {fee; prover}

module Digest = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        include Random_oracle.Digest
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

  include Stable.Latest

  let default = of_string (String.init length_in_bytes ~f:(fun _ -> '\000'))
end

let digest t = Random_oracle.digest_string (Binable.to_string (module T) t)
