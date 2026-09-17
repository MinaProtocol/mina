(* Rosetta Construction API wrappers.  See [construction.mli].

   As in [Data], each request is the generated Rosetta request model for
   the endpoint, serialised with its own [to_yojson]. *)

module RM = Rosetta_models

let derive t ~public_key ?metadata () =
  let request =
    { RM.Construction_derive_request.network_identifier =
        Http.network_identifier t
    ; public_key
    ; metadata
    }
  in
  Http.post_json t ~path:"/construction/derive"
    ~body:(RM.Construction_derive_request.to_yojson request)

let preprocess t ~operations ?metadata () =
  let request =
    { RM.Construction_preprocess_request.network_identifier =
        Http.network_identifier t
    ; operations
    ; metadata
    }
  in
  Http.post_json t ~path:"/construction/preprocess"
    ~body:(RM.Construction_preprocess_request.to_yojson request)

let metadata t ?options ?(public_keys = []) () =
  let request =
    { RM.Construction_metadata_request.network_identifier =
        Http.network_identifier t
    ; options
    ; public_keys
    }
  in
  Http.post_json t ~path:"/construction/metadata"
    ~body:(RM.Construction_metadata_request.to_yojson request)

let payloads t ~operations ?metadata ?(public_keys = []) () =
  let request =
    { RM.Construction_payloads_request.network_identifier =
        Http.network_identifier t
    ; operations
    ; metadata
    ; public_keys
    }
  in
  Http.post_json t ~path:"/construction/payloads"
    ~body:(RM.Construction_payloads_request.to_yojson request)

let parse t ~signed ~transaction =
  let request =
    RM.Construction_parse_request.create
      (Http.network_identifier t)
      signed transaction
  in
  Http.post_json t ~path:"/construction/parse"
    ~body:(RM.Construction_parse_request.to_yojson request)

let combine t ~unsigned_transaction ~signatures =
  let request =
    RM.Construction_combine_request.create
      (Http.network_identifier t)
      unsigned_transaction signatures
  in
  Http.post_json t ~path:"/construction/combine"
    ~body:(RM.Construction_combine_request.to_yojson request)

let hash t ~signed_transaction =
  let request =
    RM.Construction_hash_request.create
      (Http.network_identifier t)
      signed_transaction
  in
  Http.post_json t ~path:"/construction/hash"
    ~body:(RM.Construction_hash_request.to_yojson request)

let submit t ~signed_transaction =
  let request =
    RM.Construction_submit_request.create
      (Http.network_identifier t)
      signed_transaction
  in
  Http.post_json t ~path:"/construction/submit"
    ~body:(RM.Construction_submit_request.to_yojson request)
