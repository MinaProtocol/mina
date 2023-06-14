(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^account updates$'
    Subject:    Test account updates.
 *)

open Core_kernel
open Mina_numbers
open Mina_base
open Account_update
open Signature_lib

let update_json_roundtrip () =
  let open Update in
  let open Zkapp_basic in
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind i = Int.(gen_incl min_value max_value) in
    let%bind delegate = Public_key.Compressed.gen in
    let%bind auth_tag = Control.Tag.gen in
    let%bind permissions = Permissions.gen ~auth_tag in
    let%bind token = String.gen_with_length 6 Char.gen_uppercase in
    let%bind timing = Timing_info.gen in
    let%map voting_for = State_hash.gen in
    let app_state =
      Zkapp_state.V.of_list_exn
        Set_or_keep.
          [ Set (F.of_int i); Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
    in
    let verification_key =
      Set_or_keep.Set
        (let data =
           Pickles.Side_loaded.Verification_key.(
             dummy |> to_base58_check |> of_base58_check_exn)
         in
         let hash = Zkapp_account.digest_vk data in
         { With_hash.data; hash } )
    in
    { app_state
    ; delegate = Set_or_keep.Set delegate
    ; verification_key
    ; permissions = Set_or_keep.Set permissions
    ; zkapp_uri = Set_or_keep.Set "https://www.example.com"
    ; token_symbol = Set_or_keep.Set token
    ; timing = Set_or_keep.Set timing
    ; voting_for = Set_or_keep.Set voting_for
    })
    ~f:(fun update ->
      let module Fd = Fields_derivers_zkapps.Derivers in
      let full = deriver (Fd.o ()) in
      [%test_eq: t] update (update |> Fd.to_json full |> Fd.of_json full) )

module Fd = Fields_derivers_zkapps.Derivers

let precondition_json_roundtrip_accept () =
  let open Account_precondition in
  let account_precondition : t = Accept in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] account_precondition
    (account_precondition |> Fd.to_json full |> Fd.of_json full)

let precondition_json_roundtrip_nonce () =
  let open Account_precondition in
  let account_precondition : t = Nonce (Account_nonce.of_int 928472) in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] account_precondition
    (account_precondition |> Fd.to_json full |> Fd.of_json full)

let precondition_json_roundtrip_full_with_nonce () =
  let open Account_precondition in
  let n = Account_nonce.of_int 4321 in
  let account_precondition : t =
    Full
      { Zkapp_precondition.Account.accept with
        nonce = Check { lower = n; upper = n }
      }
  in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] account_precondition
    (account_precondition |> Fd.to_json full |> Fd.of_json full)

let precondition_json_roundtrip_full () =
  let open Account_precondition in
  let n = Account_nonce.of_int 4513 in
  let account_precondition : t =
    Full
      { Zkapp_precondition.Account.accept with
        nonce = Check { lower = n; upper = n }
      ; delegate = Check Public_key.Compressed.empty
      }
  in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] account_precondition
    (account_precondition |> Fd.to_json full |> Fd.of_json full)

let precondition_to_json () =
  let open Account_precondition in
  let account_precondition : t = Nonce (Account_nonce.of_int 34928) in
  let full = deriver (Fd.o ()) in
  [%test_eq: string]
    (account_precondition |> Fd.to_json full |> Yojson.Safe.to_string)
    ( {json|{
       balance: null,
       nonce: {lower: "34928", upper: "34928"},
       receiptChainHash: null, delegate: null,
       state: [null,null,null,null,null,null,null,null],
       actionState: null, provedState: null, isNew: null
       }|json}
    |> Yojson.Safe.from_string |> Yojson.Safe.to_string )

let body_fee_payer_json_roundtrip () =
  let open Body.Fee_payer in
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = deriver full in
  [%test_eq: t] dummy (dummy |> to_json full |> of_json full)

let body_json_roundtrip () =
  let open Body in
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = Graphql_repr.deriver full in
  [%test_eq: Graphql_repr.t] Graphql_repr.dummy
    (Graphql_repr.dummy |> to_json full |> of_json full)

let fee_payer_json_roundtrip () =
  let open Fee_payer in
  let dummy : t =
    { body = Body.Fee_payer.dummy; authorization = Signature.dummy }
  in
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = deriver full in
  [%test_eq: t] dummy (dummy |> to_json full |> of_json full)

let json_roundtrip_dummy () =
  let dummy : Graphql_repr.t =
    to_graphql_repr ~call_depth:0
      { body = Body.dummy; authorization = Control.dummy_of_tag Signature }
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = Graphql_repr.deriver @@ Fd.o () in
  [%test_eq: Graphql_repr.t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)
