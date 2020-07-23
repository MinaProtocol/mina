open Core_kernel

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    (* there's no Time.Stable.Vn, assert version and test for changes in serialization *)
    type t = Unbanned | Banned_until of Time.t

    let to_latest = Fn.id

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
  end

  module Tests = struct
    let%test "banned status serialization v1" =
      let tm = Time.of_string "2019-10-08 17:51:23.050849Z" in
      let status = V1.Banned_until tm in
      let known_good_digest = "99a12fdb97c62ceba0c4d4f5879b0cdc" in
      Ppx_version_runtime.Serialization.check_serialization
        (module V1)
        status known_good_digest
  end
end]

type t = Stable.Latest.t = Unbanned | Banned_until of Time.t

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]
