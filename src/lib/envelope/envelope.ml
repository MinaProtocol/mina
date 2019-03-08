open Core
open Network_peer
open Module_version

module Sender = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = Local | Remote of Peer.t [@@deriving sexp, bin_io]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "envelope_sender"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest
end

module Incoming = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type 'a t = {data: 'a; sender: Sender.Stable.V1.t}
        [@@deriving sexp, bin_io]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "envelope_incoming"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.V1

  let sender {sender; _} = sender

  let data {data; _} = data

  let wrap ~data ~sender = {data; sender}

  let map ~f t = {t with data= f t.data}

  let local data =
    let sender = Sender.Local in
    {data; sender}
end
