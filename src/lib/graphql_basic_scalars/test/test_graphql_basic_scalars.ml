(* Testing
   -------

   Component: GraphQL Basic Scalars
   Subject: Test GraphQL scalar roundtrips
   Invocation: dune exec src/lib/graphql_basic_scalars/test/test_graphql_basic_scalars.exe
*)

open Core_kernel
open Graphql_basic_scalars.Utils
include Graphql_basic_scalars.Make (Test_schema)
module Make_test_alcotest = Graphql_basic_scalars.Testing.Produce_test

(* Generator modules for different scalar types *)

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

module Index_gen = struct
  include Int

  let gen = quickcheck_generator
end

module String_gen = struct
  include String

  let gen = gen_nonempty
end

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

module Time_gen = struct
  type t = Core_kernel.Time.t

  (* The following generator function is copied from version 0.15.0 of the core
     library, and only generates values that can be serialized.
     https://github.com/janestreet/core/blob/35941320a3eab628786ae3853e5f753a3ab357c2/core/src/span_float.ml#L742-L754.
     See issue https://github.com/MinaProtocol/mina/issues/11310.
     Once the core library is updated to >= 0.15.0,
     [Core.Time.quickcheck_generator] should be used instead work.*)

  let gen =
    Quickcheck.Generator.map Span_gen.gen
      ~f:Core_kernel.Time.of_span_since_epoch

  let sexp_of_t = Core.Time.sexp_of_t

  let compare x y = Core_kernel.Time.robustly_compare x y
end

module InetAddr_gen = struct
  include Core.Unix.Inet_addr

  let gen =
    Int32.gen_incl 0l Int32.max_value
    |> Quickcheck.Generator.map ~f:inet4_addr_of_int32
end

(* Create test modules *)
module UInt32_test = Make_test_alcotest (UInt32) (UInt32_gen)
module UInt64_test = Make_test_alcotest (UInt64) (UInt64_gen)
module Index_test = Make_test_alcotest (Index) (Index_gen)
module String_json_test = Make_test_alcotest (String_json) (String_gen)
module Span_test = Make_test_alcotest (Span) (Span_gen)
module Time_test = Make_test_alcotest (Time) (Time_gen)
module InetAddr_test = Make_test_alcotest (InetAddr) (InetAddr_gen)

let () =
  let open Alcotest in
  run "GraphQL Basic Scalars"
    [ ( "Scalar roundtrip tests"
      , [ test_case "UInt32 roundtrip" `Quick UInt32_test.test_query
        ; test_case "UInt64 roundtrip" `Quick UInt64_test.test_query
        ; test_case "Index roundtrip" `Quick Index_test.test_query
        ; test_case "String_json roundtrip" `Quick String_json_test.test_query
        ; test_case "Span roundtrip" `Quick Span_test.test_query
        ; test_case "Time roundtrip" `Quick Time_test.test_query
        ; test_case "InetAddr roundtrip" `Quick InetAddr_test.test_query
        ] )
    ]
