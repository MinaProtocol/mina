open Core_kernel
open Module_version

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
      let known_good_hash =
        "\x52\x14\x64\x6A\xB0\x37\x7A\x62\x8D\x28\x6A\x3F\x02\xB8\xE8\xDE\x24\x5B\xED\xBA\x74\x72\xF0\xD3\xFE\x59\x09\x18\xCC\x8C\x0E\x31"
      in
      Serialization.check_serialization (module V1) status known_good_hash
  end
end]

type t = Stable.Latest.t = Unbanned | Banned_until of Time.t

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]
