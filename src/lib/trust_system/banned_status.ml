open Core_kernel
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      (* TODO: there's no Time.Stable.Vn, how to version this? *)
      type t = Unbanned | Banned_until of Time.t
      [@@deriving bin_io, version {asserted}]
    end

    include T

    let to_yojson = function
      | Unbanned ->
          `String "Unbanned"
      | Banned_until tm ->
          `Assoc
            [ ( "Banned_until"
              , `String (Time.to_string_abs tm ~zone:Time.Zone.utc) ) ]

    let of_yojson = function
      | `String "Unbanned" ->
          Ok Unbanned
      | `Assoc [("Banned_until", `String s)] ->
          Ok (Banned_until (Time.of_string s))
      | _ ->
          Error "Banned_status.of_yojson: unexpected JSON"

    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "coda_base_proof"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)

  module For_tests = struct
    (* TODO *)
  end
end

type t = Stable.Latest.t = Unbanned | Banned_until of Time.t
