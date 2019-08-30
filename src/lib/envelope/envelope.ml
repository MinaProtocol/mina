open Core
open Module_version

module Sender = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Local | Remote of Core.Unix.Inet_addr.Stable.V1.t
        [@@deriving sexp, bin_io, compare, version]
      end

      include T

      let equal sender1 sender2 = Int.equal (compare sender1 sender2) 0

      let to_yojson t : Yojson.Safe.json =
        match t with
        | Local ->
            `String "Local"
        | Remote inet_addr ->
            `Assoc [("Remote", `String (Unix.Inet_addr.to_string inet_addr))]

      let of_yojson (json : Yojson.Safe.json) : (t, string) Result.t =
        match json with
        | `String "Local" ->
            Ok Local
        | `Assoc [("Remote", `String addr)] ->
            Ok (Remote (Unix.Inet_addr.of_string addr))
        | _ ->
            Error "Expected JSON representing envelope sender"

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

  (* bin_io intentionally omitted in deriving list *)
  type t = Stable.Latest.t = Local | Remote of Unix.Inet_addr.Stable.V1.t
  [@@deriving sexp, compare]

  [%%define_locally
  Stable.Latest.(to_yojson, of_yojson, equal)]
end

module Incoming = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type 'a t = {data: 'a; sender: Sender.Stable.V1.t [@compare.ignore]}
        [@@deriving eq, sexp, bin_io, yojson, version, compare]
      end

      include T
    end

    module Latest = V1
  end

  (* bin_io intentionally omitted *)
  type 'a t = 'a Stable.Latest.t [@@deriving eq, sexp, yojson, compare]

  let sender t = t.Stable.Latest.sender

  let data t = t.Stable.Latest.data

  let wrap ~data ~sender = Stable.Latest.{data; sender}

  let map ~f t = Stable.Latest.{t with data= f t.data}

  let local data =
    let sender = Sender.Local in
    Stable.Latest.{data; sender}

  let max ~f e1 e2 = if compare f e1 e2 > 0 then e1 else e2
end
