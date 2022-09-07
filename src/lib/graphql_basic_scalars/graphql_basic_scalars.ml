(**
   This file defines basic graphql scalars in a shape usable by graphql_ppx for serialising.

   It is meant to be used by backend graphql code.

   It also includes basic round-trip testing facilities for GraphQL scalar types.

   The [graphql_lib] library re-exports these basic scalars as well as other ones,
   and is meant to be used by client code (via grapqh_ppx).
 *)

open Graphql_async.Schema
open Async_kernel
open Async_unix
open Core_kernel
module Schema = Graphql_wrapper.Make (Graphql_async.Schema)

module type Json_intf = sig
  type t

  val parse : Yojson.Basic.t -> t

  val serialize : t -> Yojson.Basic.t

  val typ : unit -> ('a, t option) Graphql_async.Schema.typ
end

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

module Make_test (S : Json_intf) (G : Test_Intf with type t = S.t) = struct
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

let unsigned_scalar_scalar ~to_string typ_name =
  scalar typ_name
    ~doc:
      (Core.sprintf
         !"String representing a %s number in base 10"
         (Stdlib.String.lowercase_ascii typ_name) )
    ~coerce:(fun num -> `String (to_string num))

module UInt32 : Json_intf with type t = Unsigned.UInt32.t = struct
  type t = Unsigned.UInt32.t

  let parse json = Yojson.Basic.Util.to_string json |> Unsigned.UInt32.of_string

  let serialize value = `String (Unsigned.UInt32.to_string value)

  let typ () =
    unsigned_scalar_scalar ~to_string:Unsigned.UInt32.to_string "UInt32"
end

module UInt64 : Json_intf with type t = Unsigned.UInt64.t = struct
  type t = Unsigned.UInt64.t

  let parse json = Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string

  let serialize value = `String (Unsigned.UInt64.to_string value)

  let typ () =
    unsigned_scalar_scalar ~to_string:Unsigned.UInt64.to_string "UInt64"
end

module Index : Json_intf with type t = int = struct
  type t = int

  let parse json = Yojson.Basic.Util.to_string json |> int_of_string

  let serialize value = `String (Int.to_string value)

  let typ () = scalar "Index" ~doc:"ocaml integer as a string" ~coerce:serialize
end

module JSON = struct
  type t = Yojson.Basic.t

  let parse = Base.Fn.id

  let serialize = Base.Fn.id

  let typ () = scalar "JSON" ~doc:"Arbitrary JSON" ~coerce:serialize
end

module String_json : Json_intf with type t = string = struct
  type t = string

  let parse json = Yojson.Basic.Util.to_string json

  let serialize value = `String value

  let typ () = string
end

module Time = struct
  type t = Core_kernel.Time.t

  let parse json =
    Yojson.Basic.Util.to_string json |> Core_kernel.Time.of_string

  let serialize t = `String (Core_kernel.Time.to_string t)

  let typ () = scalar "Time" ~coerce:serialize
end

module Span = struct
  type t = Core.Time.Span.t

  let parse json =
    Yojson.Basic.Util.to_string json
    |> Int64.of_string |> Int64.to_float |> Core.Time.Span.of_ms

  let serialize x =
    `String (Core.Time.Span.to_ms x |> Int64.of_float |> Int64.to_string)

  let typ () = scalar "Span" ~doc:"span" ~coerce:serialize
end

module Make_scalar_using_to_string (T : sig
  type t

  val to_string : t -> string

  val of_string : string -> t
end) (Scalar : sig
  val name : string

  val doc : string
end) : Json_intf with type t = T.t = struct
  type t = T.t

  let parse json = Yojson.Basic.Util.to_string json |> T.of_string

  let serialize x = `String (T.to_string x)

  let typ () =
    Graphql_async.Schema.scalar Scalar.name ~doc:Scalar.doc ~coerce:serialize
end

module Make_scalar_using_base58_check (T : sig
  type t

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t
end) (Scalar : sig
  val name : string

  val doc : string
end) : Json_intf with type t = T.t = struct
  type t = T.t

  let parse json = Yojson.Basic.Util.to_string json |> T.of_base58_check_exn

  let serialize x = `String (T.to_base58_check x)

  let typ () =
    Graphql_async.Schema.scalar Scalar.name ~doc:Scalar.doc ~coerce:serialize
end

(* TESTS *)
module UInt32_gen = struct
  include Unsigned.UInt32

  let gen =
    Int32.quickcheck_generator
    |> Quickcheck.Generator.map ~f:Unsigned.UInt32.of_int32

  let sexp_of_t = Fn.compose Int32.sexp_of_t Unsigned.UInt32.to_int32
end

let%test_module "UInt32" = (module Make_test (UInt32) (UInt32_gen))

module UInt64_gen = struct
  include Unsigned.UInt64

  let gen =
    Int64.quickcheck_generator
    |> Quickcheck.Generator.map ~f:Unsigned.UInt64.of_int64

  let sexp_of_t = Fn.compose Int64.sexp_of_t Unsigned.UInt64.to_int64
end

let%test_module "UInt64" = (module Make_test (UInt64) (UInt64_gen))

module String_gen = struct
  include String

  let gen = gen_nonempty
end

let%test_module "String_json" = (module Make_test (String_json) (String_gen))

module Span_gen = struct
  include Core_kernel.Time.Span

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

let%test_module "Span" = (module Make_test (Span) (Span_gen))

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

let%test_module "Time" = (module Make_test (Time) (Time_gen))

module InetAddr =
  Make_scalar_using_to_string
    (Core.Unix.Inet_addr)
    (struct
      let name = "InetAddr"

      let doc = "network address"
    end)
