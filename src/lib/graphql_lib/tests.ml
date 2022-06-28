(** Tests that the custom scalars defined in the Scalars module,
    the coerce function used by the GraphQL server is the inverse of the parse function
    (which is used by graphql_ppx to decode the responses).
 *)

open Core_kernel
open Async_kernel
open Async_unix
module Schema = Graphql_wrapper.Make (Graphql_async.Schema)

let test_query schema ctx query f : unit =
  Thread_safe.block_on_async_exn (fun () ->
      match Graphql_parser.parse query with
      | Error err ->
          failwith err
      | Ok doc ->
          Graphql_async.Schema.execute schema ctx doc
          >>= (function
                | Ok (`Response data) ->
                    Async_kernel.return data
                | Ok (`Stream stream) ->
                    Async_kernel.Pipe.to_list stream
                    >>| fun lst ->
                    `List
                      Core_kernel.(
                        List.map lst ~f:(fun x ->
                            Option.value_exn (Result.ok x) ))
                | Error err ->
                    Async_kernel.return err )
          >>| f )

module type GENERATOR = sig
  type t

  val gen : t Base_quickcheck.Generator.t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int
end

let get_test_field = function
  | `Assoc [ ("data", `Assoc [ ("test", value) ]) ] ->
      value
  | _ ->
      failwith "asdakljdl"

module Make_test (S : Scalars.S_JSON) (G : GENERATOR with type t = S.t) = struct
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
(* let%test_module "Uint64" = (module Make_test(Scalars.UInt64)(Unsigned.UInt64)) *)
(* let%test_module "Uint32" = (module Make_test(Scalars.UInt32)(Unsigned.UInt32)) *)
(* let%test_module "Time" = (module Make_test(Scalars.Time)(Core_kernel.Time)) *)
