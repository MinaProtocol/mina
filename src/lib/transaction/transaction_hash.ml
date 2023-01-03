open Core_kernel
open Mina_base

[%%import "/src/config.mlh"]

module T = struct
  include Blake2.Make ()
end

include T

module Base58_check = Codable.Make_base58_check (struct
  (* for legacy compatibility *)
  include Stable.Latest.With_top_version_tag

  let version_byte = Base58_check.Version_bytes.transaction_hash

  let description = "Transaction Hash"
end)

[%%define_locally
Base58_check.(of_base58_check, of_base58_check_exn, to_base58_check)]

let to_yojson t = `String (to_base58_check t)

let of_yojson = function
  | `String str ->
      Result.map_error (of_base58_check str) ~f:(fun _ ->
          "Transaction_hash.of_yojson: Error decoding string from base58_check \
           format" )
  | _ ->
      Error "Transaction_hash.of_yojson: Expected a string"

let hash_signed_command, hash_zkapp_command =
  let mk_hasher (type a) (module M : Bin_prot.Binable.S with type t = a)
      (cmd : a) =
    cmd |> Binable.to_string (module M) |> digest_string
  in
  let signed_cmd_hasher = mk_hasher (module Signed_command.Stable.Latest) in
  let zkapp_cmd_hasher = mk_hasher (module Zkapp_command.Stable.Latest) in
  (* replace actual signatures, proofs with dummies for hashing, so we can
     reproduce the transaction hashes if signatures, proofs omitted in
     archive db
  *)
  let hash_signed_command (cmd : Signed_command.t) =
    let cmd_dummy_signature = { cmd with signature = Signature.dummy } in
    signed_cmd_hasher cmd_dummy_signature
  in
  let hash_zkapp_command (cmd : Zkapp_command.t) =
    let cmd_dummy_signatures_and_proofs =
      { cmd with
        fee_payer = { cmd.fee_payer with authorization = Signature.dummy }
      ; account_updates =
          Zkapp_command.Call_forest.map cmd.account_updates
            ~f:(fun (acct_update : Account_update.t) ->
              let dummy_auth =
                match acct_update.authorization with
                | Control.Proof _ ->
                    Control.Proof Proof.transaction_dummy
                | Control.Signature _ ->
                    Control.Signature Signature.dummy
                | Control.None_given ->
                    Control.None_given
              in
              { acct_update with authorization = dummy_auth } )
      }
    in
    zkapp_cmd_hasher cmd_dummy_signatures_and_proofs
  in
  (hash_signed_command, hash_zkapp_command)

[%%ifdef consensus_mechanism]

let hash_command cmd =
  match cmd with
  | User_command.Signed_command s ->
      hash_signed_command s
  | User_command.Zkapp_command p ->
      hash_zkapp_command p

let hash_signed_command_v2 = hash_signed_command

let hash_signed_command_v1 (cmd : Signed_command.t_v1) =
  let b58 = Signed_command.Base58_check_v1.to_base58_check cmd in
  digest_string b58

let hash_zkapp_command_v1 = hash_zkapp_command

let hash_fee_transfer fee_transfer =
  fee_transfer |> Fee_transfer.Single.to_base58_check |> digest_string

let hash_coinbase coinbase =
  coinbase |> Coinbase.to_base58_check |> digest_string

let hash_of_transaction_id (transaction_id : string) : t Or_error.t =
  (* A transaction id might be:
     - original Base58Check transaction ids of signed commands (Signed_command.V1.t), or
     - a Base64 encoding of signed commands and zkApps (Signed_command.Vn.t, for n >= 2,
       or Zkapp_command.Vm.t, for m >= 1)

     For the Base64 case, the Bin_prot serialization leads with a version tag
  *)
  match Signed_command.of_base58_check_exn_v1 transaction_id with
  | Ok cmd_legacy ->
      Ok (hash_signed_command_v1 cmd_legacy)
  | Error _ -> (
      match Base64.decode transaction_id with
      | Ok s -> (
          let len = String.length s in
          let buf = Bin_prot.Common.create_buf len in
          Bin_prot.Common.blit_string_buf s buf ~len ;
          let pos_ref = ref 0 in
          let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
          match version with
          | 1 -> (
              (* must be a zkApp command *)
              try
                let cmd = Zkapp_command.Stable.V1.bin_read_t ~pos_ref buf in
                Ok (hash_zkapp_command_v1 cmd)
              with _ ->
                Or_error.error_string
                  "Could not decode serialized zkApp command (version 1)" )
          | 2 -> (
              (* must be a signed command, until there's a V2 for zkApp commands *)
              try
                let cmd = Signed_command.Stable.V2.bin_read_t ~pos_ref buf in
                Ok (hash_signed_command_v2 cmd)
              with _ ->
                Or_error.error_string
                  "Could not decode serialized signed command (version 2)" )
          | _ ->
              Or_error.error_string
                (sprintf
                   "Transaction hashing not implemented for command with \
                    version %d"
                   version ) )
      | Error _ ->
          Or_error.error_string
            "Could not decode transaction id as either Base58Check or Base64" )

module User_command_with_valid_signature = struct
  type hash = T.t [@@deriving sexp, compare, hash]

  let hash_to_yojson = to_yojson

  let hash_of_yojson = of_yojson

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( (User_command.Valid.Stable.V2.t[@hash.ignore])
        , (T.Stable.V1.t[@to_yojson hash_to_yojson]) )
        With_hash.Stable.V1.t
      [@@deriving sexp, hash, to_yojson]

      let to_latest = Fn.id

      (* Compare only on hashes, comparing on the data too would be slower and
         add no value.
      *)
      let compare (x : t) (y : t) = T.compare x.hash y.hash
    end
  end]

  let create (c : User_command.Valid.t) : t =
    { data = c; hash = hash_command (User_command.forget_check c) }

  let data ({ data; _ } : t) = data

  let command ({ data; _ } : t) = User_command.forget_check data

  let hash ({ hash; _ } : t) = hash

  let forget_check ({ data; hash } : t) =
    { With_hash.data = User_command.forget_check data; hash }

  include Comparable.Make (Stable.Latest)

  let make data hash : t = { data; hash }
end

module User_command = struct
  type hash = T.t [@@deriving sexp, compare, hash]

  let hash_to_yojson = to_yojson

  let hash_of_yojson = of_yojson

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( (User_command.Stable.V2.t[@hash.ignore])
        , (T.Stable.V1.t[@to_yojson hash_to_yojson]) )
        With_hash.Stable.V1.t
      [@@deriving sexp, hash, to_yojson]

      let to_latest = Fn.id

      (* Compare only on hashes, comparing on the data too would be slower and
         add no value.
      *)
      let compare (x : t) (y : t) = T.compare x.hash y.hash
    end
  end]

  let create (c : User_command.t) : t = { data = c; hash = hash_command c }

  let data ({ data; _ } : t) = data

  let command ({ data; _ } : t) = data

  let hash ({ hash; _ } : t) = hash

  let of_checked ({ data; hash } : User_command_with_valid_signature.t) : t =
    { With_hash.data = User_command.forget_check data; hash }

  include Comparable.Make (Stable.Latest)
end

let%test "signed command v1 hash from transaction id" =
  let transaction_id =
    "BD421DxjdoLimeUh4RA4FEvHdDn6bfxyMVWiWUwbYzQkqhNUv8B5M4gCSREpu9mVueBYoHYWkwB8BMf6iS2jjV8FffvPGkuNeczBfY7YRwLuUGBRCQJ3ktFBrNuu4abqgkYhXmcS2xyzoSGxHbXkJRAokTwjQ9HP6TLSeXz9qa92nJaTeccMnkoZBmEitsZWWnTCMqDc6rhN4Z9UMpg4wzdPMwNJvLRuJBD14Dd5pR84KBoY9rrnv66rHPc4m2hH9QSEt4aEJC76BQ446pHN9ZLmyhrk28f5xZdBmYxp3hV13fJEJ3Gv1XqJMBqFxRhzCVGoKDbLAaNRb5F1u1WxTzJu5n4cMMDEYydGEpNirY2PKQqHkR8gEqjXRTkpZzP8G19qT"
  in
  (* N.B.: this is the old-style hash, computed by digesting the Base58Check serialization *)
  let expected_hash = "CkpZUiKxdNnT53v5LAxnsohbLc9xabe6HcsQUtFsVVAQZB2pdNUjc" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

let%test "signed command v2 hash from transaction id" =
  let transaction_id =
    "Av0BlDV3VklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAP//IgAgpNU5narWobUpPXWnrzjilYnd9C6DVcafO/ZLc3vdrMgAVklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBFeE3d36c7ThjtioG6XUJjkISr2jfgpa99wHwhZ6neSQB/rQkVklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
  in
  let expected_hash = "CkpZcAHDStkSGLD8Whb4vjk4qMrf79TL8gKUT3sC8PUHpKmV8mpMx" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

let%test "zkApp v1 hash from transaction id" =
  let transaction_id =
    "ASPLCDaggJwUNe9wX1TSjbTnVCTH51R2Mlr9YAhdwSIuAf0Aypo7AAHkIhYnKT0YniDDO/ImayrrohL4T90PHVw56tWbaU8QAFMwop7L/b3su+cTu+dOcjc5Q7q/lQdcn4a7ncCRloIEAd8wb7wJNR26XRLGu9resn9Q7FnSekWJJbzHVIJyksogAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEBAQEAAQEBAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEAAQEBAQEBAQEBAQEBAQECAQABAPyewqNrz+vbFPxC5oGc+yM0VAD8B0QJiHVWaKv87+PDiSchFHMA/CswGXZeihRB/BH1BoJLXeVoAPw3CbHSu2uzr/yD2DPAcumsGwAAAL/+xAxoOB3hy9da6bKa8o+E6z8SNhb3l2yldL6wvdcEAL5OS7i+HkiEqHTPIAgYVPh9xjcfEJws4EqTgkQW2Noj/IjYfCMp3Enc/KtrDd4gS4FdAPy+0BiWi5xYu/zKAHuD9Zp7ZgD8WXbwdM6Es4f8ntntoUnMjd0A/NcDERE+alSF/HcUlDKhLUZLAPySwCrl9eCmVfwENTrXJ9IjRQD8LMaos8azxBb8AvrKZKdPp1wA/JjIdybzjFCB/Fz2Gu5Jhw4DAPxseU6k9itfWPyHtWEUBAP3PAD8sqkfcRdUdzz8cMz8jgiDkU8A/AOVgDJch2f3/Dise74Q8hVJAPzC36/rxQpiGfyhYUiDCsF4jQD8xV79qPsvbfL8EyPvfSuzIjAA/EUbhwcoLchv/J8Vkdw93L2FAPzZwmDv7JFgWvxxgZbfsWU4gAD8LHYOwtuuA3/8eHOSy2b1l9IA/DtEtp1n/+cW/P27ZRFufu9sAPxDIpI4N6lOqPxyuJ1FF2giVwAAAAn86crg7+gFyYT8kRUCbKSUhJT8TJ09TVqzbkf8lhw65BIh5SIANMhypcSi5tGiWVsEgHkvMl4NqVJa75SgKhkungrqcQsuUatOXcRYxI6ppXEUVSZWIrevkwVG8DBL+NImnGCnC/xvv+asybOCM/xjGHb5WEOXeQD8l4eI6QYrOt38x6FEKUDmet0A/MufnPQw5ejG/N2coM1lu90HAPwTGmmHolksU/x7b2UqsLwhqQD8iwcQj7F3nOL87gxr3wBfXPgA/IecsActp70d/KAmX+nilxtNAPwRX4BWfHR1nPzo8c76aWP+oQD8TWDp29+KK1z8m/cQ8oxxjFoA/Ehr4FFcs8Ai/O1tqUBzi4imAPxuZHZetdcHkPwSjk7bOYvGwQD8ySs/N17jRUT85c2M/BXHQJ0A/E6qvEuEgphC/Ly3r9DXJ6mXAPx3bv3/Wz3KmfyUQlwVVWrm7wD8VJmXIXGyfUv8QMiTYeCiH5UA/LNHB7K+zNEs/B0CZPI83tFbAAD8b7/mrMmzgjP8Yxh2+VhDl3kA/JeHiOkGKzrd/MehRClA5nrdAPzLn5z0MOXoxvzdnKDNZbvdBwD8Expph6JZLFP8e29lKrC8IakA/IsHEI+xd5zi/O4Ma98AX1z4APyHnLAHLae9HfygJl/p4pcbTQD8EV+AVnx0dZz86PHO+mlj/qEA/E1g6dvfiitc/Jv3EPKMcYxaAPxIa+BRXLPAIvztbalAc4uIpgD8bmR2XrXXB5D8Eo5O2zmLxsEA/MkrPzde40VE/OXNjPwVx0CdAPxOqrxLhIKYQvy8t6/Q1yeplwD8d279/1s9ypn8lEJcFVVq5u8A/FSZlyFxsn1L/EDIk2Hgoh+VAPyzRweyvszRLPwdAmTyPN7RWwAAAAAAAD+6WkCBNXR8/sfxoC3R0JzBV54YnnS1outT1Y8KUugumzFhEczh8MfL7RTIoT48vOxaO/s+N3/Ji5VPR8Rk6Q8BNjburQixZKkkg+K4lrywzNBZLBFCpO5htA9ygj+Q7yYBUPvUycU0O2KOXRu4rqt5rSenqd0Si60JgK4UnzPncRwBPmiPW2IEAL1DOJerQlEWDaeBkJBHsLWGuecc90KHHR0BUM/UCpWwGNdIFjEKs+91FSE/OkLojCQvMzPn03DWLQkB4QUQ9KKTS3wzHaIRWupiPy8tQZs/18MbFXb7DbVR2TYBkoAMUTWMeIUoKHsHFtvdcr0wLZUD0b3L3va9/EeW3AoBLPX+YjbTX2Pa0q66Tr1/4O0Kf6D3dsgb85WGdGw3SRQBSb9G1z6qYxMqoWAUnqm0yh1YpkO62mPlgIFX+UZHwx4BqmTEEjGlctgK+zAar9AS881ulYAzzq0rPwZFa1g7BywBKRCVN5qEASFVry9wKy/9rqfaz0FqCBdC/EiHCIumaSMByrbHIxbnpB7+M5GX9ZYg+93QwJ0fDnAiBSNkGG9iaAoBZkPIyAlxr6BZPgFxgWnAVwKYyGFMpiunRWp/anjGSy8BuvDBzfJMd3a9Rcy2jbjGgkWwx2V11F2xlR3iDHZLBDQBqM+rJy/sqaWpx9MEN/nXcvOgZXkQkvtCa8+TeGK0/DEBVMaqkDmtY76/0nlozUTVooi6MLhvH3xUn8Cz3nS6jBEB+OkreM8uBPXiSaAmO6gAIxHfN1wXNjuNBzESQ/DnIg0BDFTQT9twrjGehjcXJAw/nh6G+iIW65nExaoD+PAbShYBp/Vi+GAcj12cxA4j3Dn4kecteoUz+ZCd9RvjNZcG/hEBBZOKnHOjRpVoOGPNilwo0FkSYMOXVyY6WhZfjvHlJjcB6zfRT8rvtP0rRmhyxEj0AUtpFDgJIRk5LN+UAtRR6QkBdRlWBkIyNNvMPGxnNdWysrDfc30Y+RpZCsUgqQ2nWCwBylY8Ek/ZfXvk6hUmo43ohXKEkUKF05RGTfceV+BvhQIBN1++Lfl+By21mrkUiIF2XJf1J/cXkhDsJxSd3QqgRgIBAAlMSoRurr7fxeWuXyc+q3NXseNKX1sCabg90TqleTMB8wUdlXfXmRXccOYk2pv6okYCc/sz4g5qF2M3mvUV0AABs/0lJsM7CYKOBWTpPjzhgJ7s+W09ZDNyHlxMUnx7CQYBQHhH56g3gg5JIm8ViTbRWobXnIZag2pdeYTajW6xsTsBM+Ho98jkZVFy93LynOGSBZDg8X2k/UwSzcNylYWZYxIBB9KED1oVbBKJGUIF3HvL5bKhai7eLlf43SDqvEZQih8B+W7BppmwSdTlxxDYqPgK1uat1fPpx5ENGb1+k4JneB8AASbPfhIjhZWFX1jo0mpr7WwEwjeOGb5QTNMqHNdb3JE2AYJmLGk2bL0UlefXcr0tHb256FnPwAAE6kYh1O5s48cAASIDW8WyLaCAAev2PE5rZXZs9U7jM7RF5osb92tj8igRAf6KptuvSsKm1FMNfsMZhPnCjZ5atZKBn/QXbuzViugPAQ3cqAmQfYoAPTa0FY7o23VVQwGyXfkCubXgYHE3KO4GAb6cKQ7HgOgcDNt6RavQkK307zxZwV1pzxEySHW9POUMAWN/c1BOfyqv1GmturmW8GAWhntmDNQuICiDaZv/t8gcAfqiLDrLXmIGgn6F5LzKYTbWJuG0bfwIdS0YIQTkMzc6AejQ09X8HF0OYntTQIx/6QInjVNuoc45eTRWaoOpieAFAe+lTcbJAbzd/uXD4g8oQWbmaohI0Bo880yM2XxK9SguAbL7JGptKw4k66DCECUuBcWn9qQFXFdp4jx+QBkNGrs/Ab8QCTHnH2tz2cxQQBrEQReo6vC19ZO2m1XT521ao+cWAXTZ0zl1sErGDW9FydRZCofdAwSHolsopG5iQVGzcwwxAZCq5vg980TMwdAYVMM1tp2ik93aCc5oh7lYAvrysDUoAY9uzJQ1IF0yg9iyeX8vMUwyvuBxSjkIW5Gx7MgEzpgwAVijVvoeUs/ABB5jGiGVVIwthN1z6i8psSTgjZO4VqY8AZuUwL1rWMdXltrjgdXD335u2snpFFWj/X92LjTq4AU/AYk4yCLEwSnWLy9dsqBOFeahoZ9xlU7I210ctcjtxcstAeOlX5iH5bVDLUpMgitvD5HS7+gPm63ByKUnUlFO55w5AfJo6yk2wJ0xM1TLOuHR4QIos41XyagX09O64vbufswdAef8Nk1wsAbLuJBVPHset+Kmcp5ErCjgK1urr+OtZS0oAfarkvoMmtIcvv1cPdm5bAB7X9H9j9MxOKCJgdX1JFAgAVnAXyGUswTZQwNOtsHoUfHoL5ViATZptkTy6I1tMVwpAYm9pkIV9dIeWU/o7Lz2lH3X/O8jPBdrfef/sPe5TdwzASvoHYwseoDn3Pt+kUbkBNpygsw1oGZZfuxaT45rISIBAU+tbu6HNUgNbXTMTr3YhkzE4riC/Torsp+AzXd0tk4YAQtaE+UmL8eJ6FAd7IDXwYufr6kfWHtGb+GmpalcfnEhAVcd4b+xWky2X5aBttId9kQMGe6OEdN1XEZSzFjImQopAdsukbuUQdISAkRR9dndRhVmmdDQsiUk2SZju2ef2xoHAWUU5FkvrOifZZGh09YJdwOYAdu+f+4H/n29/w78x4EMAAHboQcslp7NVf6Itn16cO8km3yHrEvNZI1TkT2vQhAaKQF9cvv2LxKPN+9Fgx709czkNdNLnbYUvDPkqCKAiC3OPgHLqK4pb2uCiR44+jE2NVRlOmuOqsCNwAcnJHmkSWuiMQGW8Dl+fcQzmQH3q0UIORxJdOgSZjlpj8/BcVbK9iibFQHjtm3ipFW392grHA5ACunBn43OALk0i3ZZMETFDoxoAgGB2xwFCe63n7dgNXueeq57yGdY5+20JGEok78FjRQLEgHeK/Ee72LSKpPpaHgCEQZWjXpx8k4qhFZxsqX2Fv1ELgGMl36E/VRUjebqTNj6Y06Zp7nxxPw1BEIqiNEbM80LPgFFgoIIGAA0aI5zzqvPaLpi1CnHSQN+HnlsQV6qyYp2JwF41uZ6+MCTZM8g2JpMZSdbZKFBXwGw3MKaYLuohud9NwH/L9ZNoeB5I74O8uHsyocfBUiTFIT5SjIrzcEM58ugHwHLImJxGJjUerQA898EUHBC7jUIpcwbOffJoOY5ljQ2GgEI3ABqGfXsEcZaDIWnyvRqx01z4BOa7F9zr06KY5OGPAGZcdu46odBmja+CkVJ7ViMBX9ZuvRw/EgWq4Ni/hlwNgABmQ+siLCDW6YZjfWP3T6HA095/URM/+o7zsOoRtGGwAYBoqFCp8REnIqntr/FlvRDUPcB5YWo4nS0ziu1zlNc2wYB24H6hEdsTyyOOywYIbglO3aXf3uuQaRBd6PFu3gL6hMB7v6dRUS9fBXnpo0D+Wf4wPZy12Bpo5C2yQT0mXe+5hkAke/nGaqWdGgj8+OjuVJRL5UghhiEviLVhmi7TVR80x0BQyGOvLyp2AJtyBbBEswBFvYfTO0mty2YcWZcQ9+ytgueZKMJfWcw0fGvQUpfOps2LAqNPRAG6cECMg1RGVhoFgFxA3zvIt9fK8K1HE7yZ3KCZ69VNFPBZIPnzfskHxZBJPf7ETnIzNF+4g2zYnuXBojm89qUqsu2NwiWyTXmvsgPAUMId0idtSOUYOxg/F7o/FErH3ttAkqYqX/ClAR+aXkqjn6W2uxCD4fNxbP9MgOeQltO5Fxj/3WUOMhk1aY75SAB8Zcx9qlTgm7sBAhKif45QWvpt316vCGLTRkA/PKZ0i1CDO6Cd5ZBbXINgQ8vF1bKAw+PtSo7WE21yE+GE2mrAQHXhLvP5Z3vv8GvuSa8X8jdQDpYDvBKEsumzoTltnvyPhd3DAhjTkkn5Lxbnf9bpmbxFnFbyl4Bns/nfXhS54AaAbqDMOOY7xdQNvU4U9sHppLXGtGSa2culLwA/icSSgAyHI/yet3GBibxdU3KjpZycW8I3RTBmvDeU1okcPaajhkBI8+fQcurVvdqWVLXJ4anSmbYK/cnMaiEDfUFsX3frCv46c8j/aKdrdcTsLsaCmBXDarKVjWufaveqYBTR0CQEwHyWzszbLnfY+KMpc2OArk0VtqtIsyW0+zjIGY11lO/LWkI1Z5hgVCH5uXTX4ShRkw+lVWDmcHAl11Ttxk+1vA5ATEN5tAHUdeGf7jEQUh2IRp9OaRTFIaS4Iulmjf77XIiBbbq+AmlV83z/ulhcX7fUL3f/yOuHo6AM1bYxjJVuA8BbD9ZsoXjKMeuCht9C82trUYlJRRS/Aa9jT+QWplzQi4PwXA3+o07He2XTPlVqQg/ZxSw5o8vbw8yk/doWlEsPwEraLXWdbLMvhehFjfqeju3dQy2HYl/lBhiTpZQksAtOkdZV9b0NhKMsWUpGNIXiQwJZVROeCB0YV2tEALiTvwYAX+rMiXoEOu1NgCeS3nXnj7crSL14iSc69LPri8DEAg6LAnmVu/ysxazmW8cUkhv6vyroRaOz6hmtVUbm5MTFTMB9icqCo7nq/02MeYne8cY0ho/icHkMLtL7swg7nDkhi1hgOxSu7UvOBVfD8ABP3ieTRilmFr2jpG2Kn517wFCOwG+3aNemMy7V12qGMWqoKLVFHZSUxXP/s4S1CciQN4lK9AB6wgZhkc51VqjXAmnjLHv3GPIHzNT5gEp9OWDdUU+AVoTCGZBlEC/l4BMypHJuHPQoIH7AgcKPUlasB9xt1w+HTz7EZPXRqhMpnDJQK4BjFgmapHxJn60r3EAumWBLBoAAXoyyeJ+X0CdhOoZnjwibO9Fy6Tv2FSNAKRtSxYqPE4yuKb1p0sGRNzGM/NINnwLOWUFEigsSHn9kpUwAc9OrA4H46uTNYXiLXruoOYxPyeUWUKecPqQ45wYLVU8Im6ikzod8Qd0Hl8JRKHSdSu4zdv0GYrxCsd+9JHx/mGNdNtkOPtEKBUcH72MFuNDGVsyksY364x3cjJoFsCeG0d7/rk/XdYNlFT2KrBAFk8jsNnnzZjQEnf80/U3CsmnHj/PwxngnxpywmTyZ5s/CpRHVVY4x2zV1Wq4sSy9poZym8EfNWxS6aQHAvg3Ju2+gx6ZzyoQKsHZ/mL+2HCXxhT6F8w/TScqYG4qe5d+qntni75GL8fEEjxfnu8vLz04TwmqKwX3wWlbgDG+2EktFFq6dQQoPDrtA2aoPXFvvKbFTJTbOqcTQ3Wd0NLL991I270ihOKKesc/4IDQrN1jiI2dbeMyUIqw3jdGOetMD7JhZxXhyH9YBUov76nptXh6FA+ttjb8t9tZ/L4+HHjrwXoRBeUiOuxqUoLWZeSYzOloImM7POAN/+v41bhEJGWWT+pwSqjslnF9rhJpFRD48fB0FeIIQJ2S6gUw2U6CWgCqfST9B+0vkxBAXnTf/T8tm609oT5ombk9JGXJFpczfuDIkRvRUtOJBDcopUNTiNiOcDeGMgAPrkrvE5iXOk2JHgNLdDfWZWDWYCNkO6hzb5Wh7j16XT3K3hAiPqV60GHsfGNAkCv6ClBAj2shISWmBycNbtgDERVojhmGPHdFxJjXyfdztL7mgRm36psaRVVJWs3REoU0o13uccNi36P+PydUwVTQdQXOzMyl2htd/jkByIfylw4x+qAmN09MOrNRRSXcdo3eAeOp46ZcLpM962J9iJ9aJmZxWMz1uutNWktScRBbmod+2GBUKfox/aNpN7jCAl44ET3hppswk5XjWP/cjyt7pwo4IwH6ywpswi8kREzAhipwA3tQI7qkoCa4ERt9qTo19+vdP2AoRVGsJUmHcMrYB0mka71SBmWwyk43RHF58NoTt82AAX6SUlaQBWy5m/wgbYFzfNRAqEkAPiMIoySqIz4+2VHQcmDW6wOK2XjrlSxh9Vwqxug5bem4L4ZfaaILAIoLYrgPayG3LB0mAJ2uE+F2z1IYyW+vY+jrfMXLLl5lUzDhqq1piIRSUe/+GQ4wOMpsn+Jbrg1E2KLVDOHN+n/vnYCaAebwmeSgMePaFhFBOnmkKCGqjvxXYg0U9ePbv/ybeku+qRGYkszhjoeJHxc6pQyx7tu4/XrTXWuTH/rZv7NsWFP88hvwlPBQhwUywJpLWFP3+/AKJaEkpEhdH6E+mXPeZWMhybZPOExdhCgLUpj+m7oT2gegRHEGRiMYiZ5VroX8wkeMGkYq9jJcMHennQoWUk7BOpJmTJDLGa4RsWlymykBX0i7J2VoqdY0ISivn5IGpg+08qLA99fxyxWJ//hYWYVzOM+ssMjQ3icmftLp7aw3n2foq2uWxw7ExHRBP1iOSccJBnoatwkOJKX42W7YdvsEt7+VO3wzE1a+2DL3gt/a55E1Z/w6JVUzIdtPWkrXgpFNAKHVqXNP+PA9gtzxvVdVEWrqNKAQ7yHrs8PuAmoy1guZK1Dyx4mBQwHxLnpBGmwHrgdWrdoSJGpZz2LzBs5GcJSYilv1z75MzVw5LP1yb4NxQ2bGNFs0cD3XGeqtSY6EWD8uznnyJ7NJs3+0Mu/7b40fueOrzznVoXgZRd1sfCBXLKkuO+R61QWZZoBsYttXTX/MOcORNDQy1Ll751edAMskBJ+IcDe1QoZdmRswx1ZkfDtEoZkdtvSMgicxc2S4FL+qVu6O2W3N1hMhMR6wNxITWENgaQJIPxK15u9eSsyiA+G8+NQ25V2sy4vTlwQanxU2HJbjGLf2TezwDhb7208vvFLzX3iNSTYjHoUy/aYzS5BlXD0NBqhasnnXm6g9cz8/SaZGiWBRJ4/3UtVezj5KzBq01hQJ5jZHxsXjPO/9hogtOzmFbEz6SAgsogKqiK5Ik9FoHIQ5dMdaLp/OupS1F3PNkLaVhXMoYLQiei/f+wMl5bMoNP1eK2wtOx8V9iwDQXJ/+elubrNTmM7BmN9kPQz0yACn8xaalMl1+C3OMu7RdJDhZNH28qaRIvBpxeCM1/SLBX7/yMoVi9op8yBTBvSIIa7wfGC4yWtzCNJa2u+zrNYgcXCww6q6x9xsNpE8nyWfIAwAxAB0k2td7q+P+w0eaSXmKqaTMP3YJ5OZSE+N9KGvR/CqqbUuI3pBgn88jEI3O9gINh6bvEinTUxKgIwz9vRfg5O1xcynXD9KUyqEElA9HPErDDg9wRDwws5y2pFNITEePKjZ7+1t5jD8WoTEuSFA+rWbS57p7JBHB4ysnDnxaHg1/1YZAXM2BG2y1LVJLXlHlgIABxFOQyHcey8W8DdT+2Lb0iscekJZh12uzkg9kpPssGpwKKAcjK+KByCbNBEVfL0/EJJQ9XV34/cYUyFqJMHJ/B1xCn8BN1HK2VIJ8AgYtKUH/CxnaL/OFf5uKfrp9U8q0rLCGE0BWeViaGwvakbaeMIKL6Lnvp4sSmYx3oKIfM9O/1GZipMYTKvMw5bG57BFRqhs9YCT9VAFazWJp2tOjDTLPEquAx+/yF7YsjZt/+oRkBVmFHzzgillHCWL039NSaq3SSRwK+fOOHdH0VLHH+hlDxUjvJ2ReBo14nq/XvSuiMUY+xrSqcf/zDZ7AZ+p1PA3h007RJI1+Dyl4WAiYzTDmFOzlVa+vYUfwq2Z3xGObzFRr5LIHfRZDxqYrw+lgp+SW4tsdVS/cU8iAXhSSLoVNLdzOWbpeKQe2U5snfBJDMA0q5OfX6RqMJi9e1KpHmlkUiheNB5KhA08TjukISh3MzbIDjGaaPxpZL7cQ5OhMv90/WO9hyY4EpJn2npXFUY9hg+V4YHuIdoFBuKiE9TZFjfQ3qd3Rlg4nYPg8kJdzL0nY6L7yiDBbHiF/PHfWp4gFI7F0AWnVRDBdG/7cgwTzbBvqQ6x28pUb8mA7iv70CdTRYR7P5nMNFbzNxp8ru1rHAx8ip+lEfeb0xGMRDLpfzJ+4ubwRFEiWQ7WflR2K/kaaUNbzd/Yf/704xl22UdtY+X+j7EVqjQg0oGt8LGi5aoOqyIkTet1n/Lv7eS8XqIdB/VGN5kWKzhvzhsawuKvGXJ8WcZih4BZps9WVjEbWUAiZXjwSLAGW7U72IHWb3+u4qkf6dEjDUTUlwjbqoFTLJayAP0waRLqWfzLbTDapNu/3ygPL98nrRzS98xTAPQTNkbPasbbBzaxO2mCBe/Wp4Sc7+8kcREOi6RatkDycDYhG4LickM0cvGNkeozxYh+p6fHILLNaNkh3M/6L/Xu5jWLqGgIYD0FXMz3HLJYPTr2nOayscT46qh338wACXiLPdhxq9b6HS9vMM+3siPf3w0Apo4tsuGlrBtExqTLqMiqqzfKNMgxAUVK96qWYO/pMqqUxim5TsxkzYv4xCLPrJv+LWkuw7c6ARjr9TzupIwQwL8c2AseE6hVgv9ZcUzxrfiqOiy2z7AHAco2LgpL5A+QKhIdyvRoCvdxFHPjfSgk8u1ZMWfMlMIkAWkgz5HUeMoxosoIuIDDRJr/vpU++RTsvyyImQNI+uUMAarkcr3TXSTAWXVh7LdL7KRHCN96YcNyM1DEiNJJuVEcAeJqj5t01ndZftH6bmO7Xox1R5sGHMmui+QDr0wjJZQOAVJrzPI4+iEPp8l1uuL510Y2XAMIUT/8e8ZnOBH5SG8kAZcfJICCyxmD34zTIZX2Juq6wTqjyXfN5N7qJvAyz2sdAe1Byo1L2431zP1UKO0YoONBllWVQjGc/CICeskiVVM/AU7UewiBCcMtlUvpZvtfi/RgmF6UztoC7MSMYK+TEa8hAenn2ut1QKMWS+FixT351fU6lCJHlkwbz9wNqJmd3kkrAWdsr6trG+iRMqeJUCxZOpkcFGoXKXv/Uzm97zabqaAFAezQcZC/PmQ0EILcJKMLE3W8eR138TEqjPCO6egomE4FAV8hyXoyIbrXEs5IdSuFSX+NPGbuoy3WoaYeej/2ERkpAaWFc+HXSJPnqw72ijSd6lpMgwhYrKbXOMNoQThvftMDAdEyS4CLNYpCCHkSuxU1lCXaVMVHOwO936/7M3raU3c+AfF448uAr6X2fe9kckxY6C8ZB8iaODxToLQC6QG+U4IbARB6WSMbBgTcOQ0DckbZv5qOwSmpp4cCNZXETBYBORQqAYUAh5Med6QCquMit2AFOYr+z1BbS9Mldk9poJs7mLYCAVring/ixQpAMtBS8OMb5cz9adhkPGRieC3GiP060cQkAbkRzOPvPYwm2fgQr+l2W5fxJ52kM0h3cIoyS9L5kpcNAZDGe54zRwkabMaM19djc2hiY6PaAFHnx2Qr3DL4DaY2AcpuHfh2v1m7KKOhAZOfq2Aa6WPyhsrI8b+IM9pLABsRAXEif+W0fkWqKxD7GK5o2eOM/ntvSB8MwyqBhJV7IAEAAT7G96AR3mUIZZp2nCd0pDLHWH6ocvLiryXiQq/hMo4uAVcWnwBE4R0pdNTP/U6gNk/aDuqH/1gvErXfrXRk/1wxAVt6SdHzhZgfRVMkXIgJUo7CHEQqTaTx5Jupnr4Utp0bAShPqnOTYLXVe1uJlK36+kVlWSzt0E1bZFDgEKSchpk+AaSNGp27YLJJTV8zpZWQG1aKi0j8XA1QzFcu7utXEEQFAd0KwLTxzmP4O/hHVRWqKJU6rCSuTNP4JpXM3u1ylko+AAEZPLHOwW1PQQiinPRyczg0iq3TTw3YSMCwcFyLPHGgBgH344XYAQCQFOnAbXOpS6dkqxAlqH9jAF50SN8UrCW0EgERreSi78QjxlllEBfd+inv/kPPx6s1eTqeAqyi0yBWCwGeUpngF3VVGcSaw8Bviv/RV7auQ1nR2TP8TFoAAqxrAQGzSwJZH/A21+rLtAg3l9XkGde5Nnr18ZxHwNRomLF+HQGBQEwlSDnWun6cw77Xl1Gw9MEnkBIge71AYQFV6acYGwEIAM8U8uE3nE9RlQyilLoWHLjreg3aSgMwzvc6NkfaGAHR6qgUkU9Z8l+rnPr3+vCjZq9NtO8OI9i3o849yBEZKgFzb0XDOK+UpGKtAfv20gK3EmINj51yiR1rdLuNTKMCEAGetNC72BEnQMs8YWlSHIhkYfSbunvks13uGlKs4bYIKgG8gq8g6tN6O4am3CAKQlBJd2aMVm874/DYn2+ESITPEAHUUcEuN+XyO8uEfix2ZtRRjslkMyOqJo/ifnFF0UM2LwEOlh3PXT+d2vZIs2D6UEAlFk4jmPED0X0hcGUD88FGEgFO9WDOkmEsxSP1Q7FucJjgryhZ6SgLtBsxysUmt3ivFgFB9HYFynEdlqorEezfWXuezOZxgOuNx1FMbU6pv3R2KwGBUxEyJs82foBVdfng7uAd08Y1qZ2LAqImm7FULyWDLQFhzD9Fco+ZGzEkiN3NYkcRn5H+dIa8OUfgZqlWfcANEQH/uSaHFSOmYg/yAqHXNHvhGqo8kDhHNM+RwOycZvIpJwHJS6XE8qNdc+wizcE0tEmB3wbk9o29P6+jGnwkGnsSGwHD+YZF45BPqMP1fBb6rQLvBT41OglN3v5f+45LwIuxBgGvHjNtLMF4YZQnaF63MG+3Sgvut9iPVuVZ+gQx9EkdCgFCl+QatI5bKKCcpPRLkCWt+3+w76FQjWYVYPCFgNoqHgEgN95hxig1UyFtk98VhwF+afxPB6o1+pMcjAwBKUacMQGubgGbyqebL6w+D7xDcvyp8G1QKqq59ENQkxNLSbpQHAEaTYjKQ5fg5hEtSXeNQzR+y6AithsbNd28Lt6d6eagNgEFGTZlESRGnG++1/PkqKwnLvYGsED1WpZjYAjAK1JlGgF9di+sO7C6UPG5qnvlB6PflkaSiRQxyUwxiIWDc4YPCwFmVhomdrBlYqJ8bPSXKhUWDaAU/2btxpNQO8VvJofGFQGQ8acbkJlnfgzuBDPncLSrPs5/OPAGzdpvRu7Z1sh6CwFiwzUMngby8/3jV/8EHiY8kN4JMYVla/HWcGFdoDHXAQABu8KWm22K9MClILoxa1OQ9maGeTIYQHgLn2Wqe/7ApT8BYt5E6yraU8tRx5Zg5+luQAgbDA6UbTPCf46JaUR8+gwB9GRi2KXN2/8A63aamuBhajpfH1pyxIKqPui9xbG5BwYB45TtEGX8FhtiT6vqII9AksJ2QWlvHhthRIL5FD585gUBppVc+e8MWEobmPAsi6zzj2A/IcLzz9uZNWJPhpy3pxoBcg9vhnmrqJ2uRSROSvFj6KV1TpX56F8hbqDBbXuvLj0B6QHLHxEMq2csvQGYEaipzHiao+ET24fnhhcu38kKMjUBZGL0HfTeSoKMbJ59bOgjFLtjLzZGHb5qB/MQIruVfDcBk9xqV854wAZ90uTGCwDhQ1JQ2x4pEqVsd3mO41ZjAycBOaapEHhg9OPmTPAFn88l85D01w3v7LOlsFuBsk6NaRABTWwDMwWEeMmk0K/PcWzTM8hY4/EZYerH9O9Hu6sQagkB1ReyKxq0i0DXmRklryOghonk2y9ZkaRGkyg2ix+PUSMB+s/r8lu59B/cV7y1/LxP9nQPuOZxG6s8a1t7uqBoLh8BW5JnBHUfvezQ6w97ZRq5OJjD/t0vygYEt8gwQDvC4jEAATwoo66+Oqjqcqnwrd+OqJnoNQ7j9hmbE7ENTV6bzVcyAe/ruLu5EqmKf682/8iSasg57UDmQX2PUjPYlgvenPwEAQRNmfPUlsBPA5dvxiEq0yh1a/5H8eYSdIh4HV6lxikGAcXwdZL6KPSGg4DrkOa3UFrZyPwu7Wbz9QEYcy2F3iInAJwIregl8UNruGr/j0BT9qrd5uYzmGPe9/UwvFqK5CAyAAAAIgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  in
  let expected_hash = "CkpYpASVnRVXMW6U4zuGdaNuedNAiRQq51ESWohRpkQfF8WboHysS" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

[%%endif]
