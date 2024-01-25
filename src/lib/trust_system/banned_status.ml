open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Unbanned | Banned_until of (Time.t[@version_asserted])

    let to_latest = Fn.id

    let to_yojson = function
      | Unbanned ->
          `String "Unbanned"
      | Banned_until tm ->
          `Assoc
            [ ( "Banned_until"
              , `String (Time.to_string_abs tm ~zone:Time.Zone.utc) )
            ]

    let of_yojson = function
      | `String "Unbanned" ->
          Ok Unbanned
      | `Assoc [ ("Banned_until", `String s) ] ->
          Ok (Banned_until (Time.of_string s))
      | _ ->
          Error "Banned_status.of_yojson: unexpected JSON"
  end
end]

[%%define_locally Stable.Latest.(to_yojson, of_yojson)]
