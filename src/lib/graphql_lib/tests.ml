(** Round-trip tests for the custom scalars defined in the Scalars module.
    We check that the coerce function used by the GraphQL server is the inverse of the parse function
    used by graphql_ppx to decode the responses).
 *)

open Core_kernel
open Async_kernel
open Async_unix
module Schema = Graphql_wrapper.Make (Graphql_async.Schema)

let json_from_response = function
  | Ok (`Response data) ->
      Async_kernel.return data
  | Ok (`Stream stream) ->
      Async_kernel.Pipe.to_list stream
      >>| fun lst ->
      `List
        Core_kernel.(List.map lst ~f:(fun x -> Option.value_exn (Result.ok x)))
  | Error err ->
      Async_kernel.return err

(** Run the [query] and execute test function [f_test] on the response *)
let test_query schema ctx query (f_test : Yojson.Basic.t -> unit) : unit =
  Thread_safe.block_on_async_exn (fun () ->
      match Graphql_parser.parse query with
      | Error err ->
          failwith err
      | Ok doc ->
          Graphql_async.Schema.execute schema ctx doc
          >>= json_from_response >>| f_test )

(** Additional functions necessary to run the round-trip tests for type t *)
module type TEST_UTILS = sig
  type t

  val gen : t Base_quickcheck.Generator.t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int
end

let get_test_field = function
  | `Assoc [ ("data", `Assoc [ ("test", value) ]) ] ->
      value
  | json ->
      failwithf "(%s) Unexpected format of JSON response:%s" __LOC__
        (Yojson.Basic.to_string json)
        ()

module Make_test (S : Scalars.S_JSON) (G : TEST_UTILS with type t = S.t) =
struct
  (** Builds a test which creates a schema returning a value of type [S.t],
      query it, parse the response back from JSON and compare the values. *)
  let query_server_and_compare value =
    let schema =
      Graphql_async.Schema.(
        schema
          [ field "test"
              ~typ:(non_null @@ S.typ ())
              ~args:Arg.[]
              ~resolve:(fun _ () -> value)
          ])
    in
    test_query schema () "{ test }" (fun response ->
        [%test_eq: G.t] value (S.parse @@ get_test_field response) )

  let%test_unit "test" =
    Quickcheck.test G.gen ~sexp_of:G.sexp_of_t ~f:query_server_and_compare
end

let%test_module "BlockTime" = (module Make_test (Scalars.BlockTime) (Block_time))

let%test_module "EpochSeed" =
  (module Make_test (Scalars.EpochSeed) (Mina_base.Epoch_seed))

let%test_module "Fee" = (module Make_test (Scalars.Fee) (Currency.Fee))

let%test_module "Amount" = (module Make_test (Scalars.Amount) (Currency.Amount))

let%test_module "TokenId" =
  (module Make_test (Scalars.TokenId) (Mina_base.Token_id))

let%test_module "Balance" =
  (module Make_test (Scalars.Balance) (Currency.Balance))

let%test_module "PublicKey" =
  (module Make_test (Scalars.PublicKey) (Signature_lib.Public_key.Compressed))

module Time_gen = struct
  type t = Core_kernel.Time.t

  (* The following generator function is copied from version 0.15.0 of the core library, and only generates values that can be serialized.
     https://github.com/janestreet/core/blob/35941320a3eab628786ae3853e5f753a3ab357c2/core/src/span_float.ml#L742-L754.

     See issue https://github.com/MinaProtocol/mina/issues/11310.

     Once the core library is updated to >= 0.15.0, [Core.Time.quickcheck_generator] should be used instead work.*)

  let gen =
    let span_gen =
      let open Core_kernel_private.Span_float in
      let millenium = of_day (Float.round_up (365.2425 *. 1000.)) in
      Quickcheck.Generator.filter quickcheck_generator ~f:(fun t ->
          neg millenium <= t && t <= millenium )
    in
    Quickcheck.Generator.map span_gen ~f:Core_kernel.Time.of_span_since_epoch

  let sexp_of_t = Core.Time.sexp_of_t

  let compare x y = Core_kernel.Time.robustly_compare x y
end

let%test_module "Time" = (module Make_test (Scalars.Time) (Time_gen))
