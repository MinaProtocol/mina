open Core_kernel
open Async

module Variant = struct
  type t =
    [ `Sql of string
    | `Json_parse of string
    | `Graphql_coda_query of string
    | `Network_doesn't_exist of string * string
    | `Chain_info_missing ]
  [@@deriving yojson, show]
end

module T : sig
  type t [@@deriving yojson, show]

  val create : retriable:bool -> ?context:string -> Variant.t -> [> `App of t]

  val erase : t -> Models.Error.t

  module Lift : sig
    val parse :
         ?context:string
      -> ('a, string) Result.t
      -> ('a, [> `App of t]) Deferred.Result.t

    val sql :
         ?context:string
      -> ?retriable:bool
      -> ('a, [< Caqti_error.t]) Deferred.Result.t
      -> ('a, [> `App of t]) Deferred.Result.t
  end
end = struct
  type t = {extra_context: string option; kind: Variant.t; retriable: bool}
  [@@deriving yojson, show]

  (* TODO: One of the ppx masters should make an "special_enum" ppx that will
     * do this for us. Jane Street's enum only works on argumentless variants *)
  let code = function
    | `Sql _ ->
        1
    | `Json_parse _ ->
        2
    | `Graphql_coda_query _ ->
        3
    | `Network_doesn't_exist _ ->
        4
    | `Chain_info_missing ->
        5

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

  let context = function
    | `Sql msg ->
        Some msg
    | `Json_parse msg ->
        Some msg
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

  let create ~retriable ?context kind =
    `App {extra_context= context; kind; retriable}

  let erase (t : t) =
    { Models.Error.code= Int32.of_int_exn (code t.kind)
    ; message= message t.kind
    ; retriable= t.retriable
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

  module Lift = struct
    let parse ?context res =
      Deferred.return
        (Result.map_error
           ~f:(fun s -> create ~retriable:false ?context (`Json_parse s))
           res)

    let sql ?context ?(retriable = false) res =
      Deferred.Result.map_error
        ~f:(fun e -> create ~retriable ?context (`Sql (Caqti_error.show e)))
        res
  end
end

include T
