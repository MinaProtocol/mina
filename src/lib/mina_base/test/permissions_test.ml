(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^permissions$'
    Subject:    Test permissions.
 *)

open Core_kernel
open Mina_base
open Permissions

let decode_encode_roundtrip () =
  let open Auth_required in
  let open For_test in
  List.iter [ Impossible; Proof; Signature; Either ] ~f:(fun t ->
      [%test_eq: t] t (decode (encode t)) )

let json_roundtrip () =
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = deriver full in
  [%test_eq: t] user_default (user_default |> to_json full |> of_json full)

let json_value () =
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = deriver full in
  [%test_eq: string]
    (user_default |> to_json full |> Yojson.Safe.to_string)
    ( {json|{
        editState: "Signature",
        access: "None",
        send: "Signature",
        receive: "None",
        setDelegate: "Signature",
        setPermissions: "Signature",
        setVerificationKey: "Signature",
        setZkappUri: "Signature",
        editActionState: "Signature",
        setTokenSymbol: "Signature",
        incrementNonce: "Signature",
        setVotingFor: "Signature",
        setTiming: "Signature"
      }|json}
    |> Yojson.Safe.from_string |> Yojson.Safe.to_string )
