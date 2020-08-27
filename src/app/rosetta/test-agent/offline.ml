open Async
open Core_kernel
open Models
open Lib
module Lift = Peek.Lift

let post = Peek.post

open Deferred.Result.Let_syntax

module Derive = struct
  let req ~rosetta_uri ~logger ~public_key_hex_bytes ~network_response =
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_derive_request.(
            { network_identifier=
                List.hd_exn
                  network_response.Network_list_response.network_identifiers
            ; public_key=
                { Public_key.hex_bytes= public_key_hex_bytes
                ; curve_type= "tweedle" }
            ; metadata= Some Amount_of.Token_id.(encode default) }
            |> to_yojson)
        ~path:"construction/derive"
    in
    Lift.res r ~logger ~of_yojson:Construction_derive_response.of_yojson
    |> Lift.successfully
end

module Preprocess = struct
  let req ~rosetta_uri ~logger ~max_fee ~operations ~network_response =
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_preprocess_request.(
            { network_identifier=
                List.hd_exn
                  network_response.Network_list_response.network_identifiers
            ; max_fee= [Amount_of.coda max_fee]
            ; operations
            ; suggested_fee_multiplier= None
            ; metadata= None }
            |> to_yojson)
        ~path:"construction/preprocess"
    in
    Lift.res r ~logger ~of_yojson:Construction_preprocess_response.of_yojson
    |> Lift.successfully
end

module Payloads = struct
  let req ~rosetta_uri ~logger ~operations ~metadata ~network_response =
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_payloads_request.(
            { network_identifier=
                List.hd_exn
                  network_response.Network_list_response.network_identifiers
            ; operations
            ; metadata= Some metadata }
            |> to_yojson)
        ~path:"construction/payloads"
    in
    Lift.res r ~logger ~of_yojson:Construction_payloads_response.of_yojson
    |> Lift.successfully
end

module Parse = struct
  let req ~rosetta_uri ~logger ~transaction ~network_response =
    let signed, transaction =
      match transaction with
      | `Unsigned txn ->
          (false, txn)
      | `Signed txn ->
          (true, txn)
    in
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_parse_request.(
            { network_identifier=
                List.hd_exn
                  network_response.Network_list_response.network_identifiers
            ; transaction
            ; signed }
            |> to_yojson)
        ~path:"construction/parse"
    in
    Lift.res r ~logger ~of_yojson:Construction_parse_response.of_yojson
    |> Lift.successfully
end
