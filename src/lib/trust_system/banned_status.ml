open Core

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Unbanned | Banned_until of (Time_float.t[@version_asserted])

    let to_latest = Fn.id

    let to_yojson = function
      | Unbanned ->
          `String "Unbanned"
      | Banned_until tm ->
          `Assoc
            [ ( "Banned_until"
              , `String (Time_float.to_string_abs tm ~zone:Time_float.Zone.utc)
              )
            ]

    let of_yojson = function
      | `String "Unbanned" ->
          Ok Unbanned
      | `Assoc [ ("Banned_until", `String s) ] ->
          Ok (Banned_until (Time_float_unix.of_string_abs s))
      | _ ->
          Error "Banned_status.of_yojson: unexpected JSON"
  end
end]

[%%define_locally Stable.Latest.(to_yojson, of_yojson)]
