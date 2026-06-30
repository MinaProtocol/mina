(* Rosetta Construction API wrappers.  See [construction.mli]. *)

let with_ni t pairs =
  `Assoc (("network_identifier", Http.network_identifier t) :: pairs)

let opt_field name = function None -> [] | Some v -> [ (name, v) ]

let derive t ~public_key ?metadata () =
  Http.post_json t ~path:"/construction/derive"
    ~body:
      (with_ni t
         ([ ("public_key", public_key) ] @ opt_field "metadata" metadata) )

let preprocess t ~operations ?metadata () =
  Http.post_json t ~path:"/construction/preprocess"
    ~body:
      (with_ni t
         ([ ("operations", operations) ] @ opt_field "metadata" metadata) )

let metadata t ~options ?public_keys () =
  Http.post_json t ~path:"/construction/metadata"
    ~body:
      (with_ni t
         ([ ("options", options) ] @ opt_field "public_keys" public_keys) )

let payloads t ~operations ?metadata ?public_keys () =
  Http.post_json t ~path:"/construction/payloads"
    ~body:
      (with_ni t
         ( [ ("operations", operations) ]
         @ opt_field "metadata" metadata
         @ opt_field "public_keys" public_keys ) )

let parse t ~signed ~transaction =
  Http.post_json t ~path:"/construction/parse"
    ~body:
      (with_ni t
         [ ("signed", `Bool signed); ("transaction", `String transaction) ] )

let combine t ~unsigned_transaction ~signatures =
  Http.post_json t ~path:"/construction/combine"
    ~body:
      (with_ni t
         [ ("unsigned_transaction", `String unsigned_transaction)
         ; ("signatures", signatures)
         ] )

let hash t ~signed_transaction =
  Http.post_json t ~path:"/construction/hash"
    ~body:(with_ni t [ ("signed_transaction", `String signed_transaction) ])

let submit t ~signed_transaction =
  Http.post_json t ~path:"/construction/submit"
    ~body:(with_ni t [ ("signed_transaction", `String signed_transaction) ])
