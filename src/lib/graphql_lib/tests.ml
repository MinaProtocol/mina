open Core_kernel
open Async_kernel
open Async_unix
module Schema = Graphql_wrapper.Make (Graphql_async.Schema)

module type Test_Intf = sig
  type t

  val gen : t Base_quickcheck.Generator.t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int
end

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

let test_query schema ctx query (f_test : Yojson.Basic.t -> unit) : unit =
  Thread_safe.block_on_async_exn (fun () ->
      match Graphql_parser.parse query with
      | Error err ->
          failwith err
      | Ok doc ->
          Graphql_async.Schema.execute schema ctx doc
          >>= json_from_response >>| f_test )

let get_test_field = function
  | `Assoc [ ("data", `Assoc [ ("test", value) ]) ] ->
      value
  | json ->
      failwithf "(%s) Unexpected format of JSON response:%s" __LOC__
        (Yojson.Basic.to_string json)
        ()

module Make_test (S : Scalars.Json_intf) (G : Test_Intf with type t = S.t) =
struct
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

module UInt32_gen = struct
  include Unsigned.UInt32

  let gen =
    Int32.quickcheck_generator
    |> Quickcheck.Generator.map ~f:Unsigned.UInt32.of_int32

  let sexp_of_t = Fn.compose Int32.sexp_of_t Unsigned.UInt32.to_int32
end

module UInt64_gen = struct
  include Unsigned.UInt64

  let gen =
    Int64.quickcheck_generator
    |> Quickcheck.Generator.map ~f:Unsigned.UInt64.of_int64

  let sexp_of_t = Fn.compose Int64.sexp_of_t Unsigned.UInt64.to_int64
end

module String_gen = struct
  include String

  let gen = gen_nonempty
end

module Span_gen = struct
  include Time.Span

  let gen =
    let open Core_kernel_private.Span_float in
    let millenium = of_day (Float.round_up (365.2425 *. 1000.)) in
    Quickcheck.Generator.filter quickcheck_generator ~f:(fun t ->
        neg millenium <= t && t <= millenium )

  let compare x y =
    (* https://github.com/janestreet/core_kernel/blob/v0.14.1/src/float.ml#L61 *)
    (* Note: We have to use a different tolerance than
       `Core_kernel.Time.Span.robustly_compare` does
       because spans are rounded to the millisecond when
       serialized through GraphQL. See the implementation
       of Span in the `Graphql_basic_scalars` module. *)
    let tolerance = 1E-3 in
    let diff = x - y in
    if diff < of_sec ~-.tolerance then -1
    else if diff > of_sec tolerance then 1
    else 0
end

module Time_gen = struct
  type t = Core_kernel.Time.t

  (* The following generator function is copied from version 0.15.0 of the core library, and only generates values that can be serialized.
     https://github.com/janestreet/core/blob/35941320a3eab628786ae3853e5f753a3ab357c2/core/src/span_float.ml#L742-L754.
     See issue https://github.com/MinaProtocol/mina/issues/11310.
     Once the core library is updated to >= 0.15.0, [Core.Time.quickcheck_generator] should be used instead work.*)

  let gen =
    Quickcheck.Generator.map Span_gen.gen
      ~f:Core_kernel.Time.of_span_since_epoch

  let sexp_of_t = Core.Time.sexp_of_t

  let compare x y = Core_kernel.Time.robustly_compare x y
end

module Slot_gen = struct
  include Consensus__Slot

  let gen =
    Quickcheck.Generator.map ~f:Consensus__Slot.of_uint32
      (Consensus__Constants.for_unit_tests |> Lazy.force |> gen)
end

module FeeTransferType_gen = struct
  include Filtered_external_transition.Fee_transfer_type

  let gen = quickcheck_generator
end

module TransactionHash_gen = struct
  include Mina_transaction.Transaction_hash

  let gen =
    Mina_base.Coinbase.Gen.gen
      ~constraint_constants:
        Genesis_constants.Constraint_constants.for_unit_tests
    |> Quickcheck.Generator.map ~f:(fun (coinbase, _) -> hash_coinbase coinbase)
end

(* BASIC SCALARS *)
let%test_module "UInt32" = (module Make_test (Scalars.UInt32) (UInt32_gen))

let%test_module "UInt64" = (module Make_test (Scalars.UInt64) (UInt64_gen))

let%test_module "String_json" =
  (module Make_test (Scalars.String_json) (String_gen))

let%test_module "Time" = (module Make_test (Scalars.Time) (Time_gen))

let%test_module "Span" = (module Make_test (Scalars.Span) (Span_gen))

(* MINA BASE *)
let%test_module "TokenId" =
  (module Make_test (Scalars.TokenId) (Mina_base.Token_id))

let%test_module "StateHash" =
  (module Make_test (Scalars.StateHash) (Mina_base.State_hash))

let%test_module "ChainHash" =
  (module Make_test (Scalars.ChainHash) (Mina_base.Receipt.Chain_hash))

let%test_module "EpochSeed" =
  (module Make_test (Scalars.EpochSeed) (Mina_base.Epoch_seed))

let%test_module "LedgerHash" =
  (module Make_test (Scalars.LedgerHash) (Mina_base.Ledger_hash))

(* MINA NUMBERS *)
let%test_module "GlobalSlot" =
  (module Make_test (Scalars.GlobalSlot) (Mina_numbers.Global_slot))

let%test_module "AccountNonce" =
  (module Make_test (Scalars.AccountNonce) (Mina_numbers.Account_nonce))

let%test_module "AccountNonce" =
  (module Make_test (Scalars.Length) (Mina_numbers.Length))

(* CURRENCY *)
let%test_module "Fee" = (module Make_test (Scalars.Fee) (Currency.Fee))

let%test_module "Amount" = (module Make_test (Scalars.Amount) (Currency.Amount))

let%test_module "Balance" =
  (module Make_test (Scalars.Balance) (Currency.Balance))

(* SIGNATURE LIB *)
let%test_module "PublicKey" =
  (module Make_test (Scalars.PublicKey) (Signature_lib.Public_key.Compressed))

(* BLOCK TIME *)
let%test_module "BlockTime" = (module Make_test (Scalars.BlockTime) (Block_time))

(* CONSENSUS *)
let%test_module "Epoch" = (module Make_test (Scalars.Epoch) (Consensus__Epoch))

let%test_module "Slot" = (module Make_test (Scalars.Slot) (Slot_gen))

(* FILTERED EXTERNAL TRANSITION *)
let%test_module "FeeTransferType" =
  (module Make_test (Scalars.FeeTransferType) (FeeTransferType_gen))

(* TRANSACTION HASH *)
let%test_module "TransactionHash" =
  (module Make_test (Scalars.TransactionHash) (TransactionHash_gen))

(* Manual tests for Mina_block.Precomputed.Proof.t *)
let%test_module "PrecomputedBlockProof" =
  ( module struct
    (* The type `t` from this module is equal to this *)
    (* type t = (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t *)

    module Nat = Pickles_types.Nat
    module S = Scalars.PrecomputedBlockProof
    module G = Mina_block.Precomputed.Proof

    (* Sample gotten from: lib/prover/prover.ml *)
    let examples : G.t list =
      [ Pickles.Proof.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:16 ]

    (* From the `Make_test` functor *)
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
          assert (Poly.equal value (S.parse @@ get_test_field response) ) )

    let%test_unit "test" = List.iter examples ~f:query_server_and_compare
  end )

(* TODO: add quickcheck tests tests for the following graphql scalars *)
(* let%test_module "PrecomputedBlockProof" =
   (module Make_test (Scalars.PrecomputedBlockProof) (Mina_block.Precomputed.Proof) ) *)
