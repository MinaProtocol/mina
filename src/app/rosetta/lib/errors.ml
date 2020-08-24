open Core_kernel
open Async

module Partial_reason = struct
  type t =
    | Length_mismatch
    | Fee_payer_and_source_mismatch
    | Amount_not_some
    | Account_not_some
    | Incorrect_token_id
    | Amount_inc_dec_mismatch
    | Status_not_pending
    | Can't_find_kind of string
  [@@deriving yojson, sexp, show, eq]
end

module Variant = struct
  (* DO NOT change the order of this variant, the generated error code relies
   * on it and we want that to remain stable *)
  type t =
    [ `Sql of string
    | `Json_parse of string option
    | `Graphql_coda_query of string
    | `Network_doesn't_exist of string * string
    | `Chain_info_missing
    | `Account_not_found of string
    | `Invariant_violation
    | `Transaction_not_found of string
    | `Block_missing
    | `Malformed_public_key
    | `Operations_not_valid of Partial_reason.t list
    | `Unsupported_operation_for_construction
    | `Signature_missing
    | `Public_key_format_not_valid ]
  [@@deriving yojson, show, eq, to_enum, to_representatives]
end

module T : sig
  type t [@@deriving yojson, show, eq]

  val create : ?context:string -> Variant.t -> t

  val erase : t -> Models.Error.t

  val all_errors : Models.Error.t list lazy_t

  module Lift : sig
    val parse :
      ?context:string -> ('a, string) Result.t -> ('a, t) Deferred.Result.t

    val sql :
         ?context:string
      -> ('a, [< Caqti_error.t]) Deferred.Result.t
      -> ('a, t) Deferred.Result.t

    val wrap :
      ('a, t) Deferred.Result.t -> ('a, [> `App of t]) Deferred.Result.t
  end
end = struct
  type t = {extra_context: string option; kind: Variant.t}
  [@@deriving yojson, show, eq]

  let code = Fn.compose (fun x -> x + 1) Variant.to_enum

  let message = function
    | `Sql _ ->
        "SQL failure"
    | `Json_parse _ ->
        "JSON parse error"
    | `Graphql_coda_query _ ->
        "GraphQL query failed"
    | `Network_doesn't_exist _ ->
        "Network doesn't exist"
    | `Chain_info_missing ->
        "Chain info missing"
    | `Account_not_found _ ->
        "Account not found"
    | `Invariant_violation ->
        "Internal invariant violation (you found a bug)"
    | `Transaction_not_found _ ->
        "Transaction not found"
    | `Block_missing ->
        "Block not found"
    | `Malformed_public_key ->
        "Malformed public key"
    | `Operations_not_valid _ ->
        "Cannot convert operations to valid transaction"
    | `Public_key_format_not_valid ->
        "Invalid public key format"
    | `Unsupported_operation_for_construction ->
        "Unsupported operation for construction"
    | `Signature_missing ->
        "Signature missing"

  let context = function
    | `Sql msg ->
        Some msg
    | `Json_parse optional_msg ->
        optional_msg
    | `Graphql_coda_query msg ->
        Some msg
    | `Network_doesn't_exist (req, conn) ->
        Some
          (sprintf
             !"You are requesting the status for the network %s but you are \
               connected to the network %s\n"
             req conn)
    | `Chain_info_missing ->
        Some
          "Could not get chain information. This probably means you are \
           bootstrapping -- bootstrapping is the process of synchronizing \
           with peers that are way ahead of you on the chain. Try again in a \
           few seconds."
    | `Account_not_found addr ->
        Some
          (sprintf
             !"You attempt to lookup %s but we couldn't find it in the ledger."
             addr)
    | `Invariant_violation ->
        None
    | `Transaction_not_found hash ->
        Some
          (sprintf
             !"You attempt to lookup %s but it is missing from the mempool. \
               This may be due to it's inclusion in a block -- try looking \
               for this transaction in a recent block. It also could be due \
               to the transaction being evicted from the mempool."
             hash)
    | `Block_missing ->
        (* TODO: Add context around the query made *)
        None
    | `Malformed_public_key ->
        None
    | `Operations_not_valid reasons ->
        Some
          (sprintf
             !"Cannot recover transaction for the following reasons: %{sexp: \
               Partial_reason.t list}"
             reasons)
    | `Public_key_format_not_valid ->
        None
    | `Unsupported_operation_for_construction ->
        None
    | `Signature_missing ->
        None

  let retriable = function
    | `Sql _ ->
        false
    | `Json_parse _ ->
        false
    | `Graphql_coda_query _ ->
        false
    | `Network_doesn't_exist _ ->
        false
    | `Chain_info_missing ->
        true
    | `Account_not_found _ ->
        true
    | `Invariant_violation ->
        false
    | `Transaction_not_found _ ->
        true
    | `Block_missing ->
        true
    | `Malformed_public_key ->
        false
    | `Operations_not_valid _ ->
        false
    | `Public_key_format_not_valid ->
        false
    | `Unsupported_operation_for_construction ->
        false
    | `Signature_missing ->
        false

  let create ?context kind = {extra_context= context; kind}

  let erase (t : t) =
    { Models.Error.code= Int32.of_int_exn (code t.kind)
    ; message= message t.kind
    ; retriable= retriable t.kind
    ; details=
        ( match (context t.kind, t.extra_context) with
        | None, None ->
            Some (Variant.to_yojson t.kind)
        | None, Some context | Some context, None ->
            Some
              (`Assoc
                [("body", Variant.to_yojson t.kind); ("error", `String context)])
        | Some context1, Some context2 ->
            Some
              (`Assoc
                [ ("body", Variant.to_yojson t.kind)
                ; ("error", `String context1)
                ; ("extra", `String context2) ]) ) }

  let all_errors =
    Variant.to_representatives
    |> Lazy.map ~f:(fun vs -> List.map vs ~f:(Fn.compose erase create))

  module Lift = struct
    let parse ?context res =
      Deferred.return
        (Result.map_error
           ~f:(fun s -> create ?context (`Json_parse (Some s)))
           res)

    let sql ?context res =
      Deferred.Result.map_error
        ~f:(fun e -> create ?context (`Sql (Caqti_error.show e)))
        res

    let wrap t = Deferred.Result.map_error ~f:(fun e -> `App e) t
  end
end

include T
