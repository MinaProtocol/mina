open Async
open Models
open Lib
module Lift = Peek.Lift

let post = Peek.post

let net_id = Peek.net_id

open Deferred.Result.Let_syntax

module Derive = struct
  let req ~rosetta_uri ~logger ~public_key_hex_bytes ~network_response =
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_derive_request.(
            { network_identifier= net_id network_response
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
            { network_identifier= net_id network_response
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
            { network_identifier= net_id network_response
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
            {network_identifier= net_id network_response; transaction; signed}
            |> to_yojson)
        ~path:"construction/parse"
    in
    Lift.res r ~logger ~of_yojson:Construction_parse_response.of_yojson
    |> Lift.successfully
end

module Combine = struct
  let req ~rosetta_uri ~logger ~unsigned_transaction ~signature ~address
      ~public_key_hex_bytes ~network_response =
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_combine_request.(
            { network_identifier= net_id network_response
            ; unsigned_transaction
            ; signatures=
                [ (* TODO: How important is it to fill in all these details properly? *)
                  { Signature.signing_payload=
                      { Signing_payload.address
                      ; hex_bytes= "TODO"
                      ; signature_type= None }
                  ; public_key=
                      { Public_key.hex_bytes= public_key_hex_bytes
                      ; curve_type= "tweedle" }
                  ; signature_type= "schnorr"
                  ; hex_bytes= signature } ] }
            |> to_yojson)
        ~path:"construction/combine"
    in
    Lift.res r ~logger ~of_yojson:Construction_combine_response.of_yojson
    |> Lift.successfully
end

module Hash = struct
  let req ~rosetta_uri ~logger ~signed_transaction ~network_response =
    let%bind r =
      post ~rosetta_uri ~logger
        ~body:
          Construction_hash_request.(
            {network_identifier= net_id network_response; signed_transaction}
            |> to_yojson)
        ~path:"construction/hash"
    in
    Lift.res r ~logger ~of_yojson:Construction_hash_response.of_yojson
    |> Lift.successfully
end
