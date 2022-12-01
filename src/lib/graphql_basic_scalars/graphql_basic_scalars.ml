(**
   This file defines basic graphql scalars in a shape usable by graphql_ppx for serialising.

   It is meant to be used by backend graphql code.

   It also includes basic round-trip testing facilities for GraphQL scalar types.

   The [graphql_lib] library re-exports these basic scalars as well as other ones,
   and is meant to be used by client code (via grapqh_ppx).
 *)

open Core_kernel
open Utils

module Make (Schema : Schema) = struct
  open Schema

  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  let unsigned_scalar_scalar ~to_string typ_name =
    scalar typ_name
      ~doc:
        (Core.sprintf
           !"String representing a %s number in base 10"
           (Stdlib.String.lowercase_ascii typ_name) )
      ~coerce:(fun num -> `String (to_string num))

  (* guard against negative wrap around behaviour from
     the `integers` library *)
  let parse_uinteger json ~f =
    let s = Yojson.Basic.Util.to_string json in
    let neg = String.is_prefix ~prefix:"-" s in
    if neg then
      failwith
        "Cannot parse string starting with a minus as an unsigned integer"
    else f s

  module UInt32 : Json_intf with type t = Unsigned.UInt32.t = struct
    type t = Unsigned.UInt32.t

    let parse = parse_uinteger ~f:Unsigned.UInt32.of_string

    let serialize value = `String (Unsigned.UInt32.to_string value)

    let typ () =
      unsigned_scalar_scalar ~to_string:Unsigned.UInt32.to_string "UInt32"
  end

  module UInt64 : Json_intf with type t = Unsigned.UInt64.t = struct
    type t = Unsigned.UInt64.t

    let parse = parse_uinteger ~f:Unsigned.UInt64.of_string

    let serialize value = `String (Unsigned.UInt64.to_string value)

    let typ () =
      unsigned_scalar_scalar ~to_string:Unsigned.UInt64.to_string "UInt64"
  end

  module Index : Json_intf with type t = int = struct
    type t = int

    let parse json = Yojson.Basic.Util.to_string json |> int_of_string

    let serialize value = `String (Int.to_string value)

    let typ () =
      scalar "Index" ~doc:"ocaml integer as a string" ~coerce:serialize
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

  module InetAddr =
    Make_scalar_using_to_string
      (Core.Unix.Inet_addr)
      (struct
        let name = "InetAddr"

        let doc = "network address"
      end)
      (Schema)
end

include Make (Schema)
module Utils = Utils
module Testing = Testing

let%test_module "Roundtrip tests" =
  ( module struct
    open Testing
    include Make (Test_schema)

    module UInt32_gen = struct
      include Unsigned.UInt32

      let gen =
        Int32.quickcheck_generator
        |> Quickcheck.Generator.map ~f:Unsigned.UInt32.of_int32

      let sexp_of_t = Fn.compose Int32.sexp_of_t Unsigned.UInt32.to_int32
    end

    let%test_module "UInt32" = (module Testing.Make_test (UInt32) (UInt32_gen))

    module UInt64_gen = struct
      include Unsigned.UInt64

      let gen =
        Int64.quickcheck_generator
        |> Quickcheck.Generator.map ~f:Unsigned.UInt64.of_int64

      let sexp_of_t = Fn.compose Int64.sexp_of_t Unsigned.UInt64.to_int64
    end

    let%test_module "UInt64" = (module Make_test (UInt64) (UInt64_gen))

    module Index_gen = struct
      include Int

      let gen = quickcheck_generator
    end

    let%test_module "Index" = (module Make_test (Index) (Index_gen))

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

    module InetAddr_gen = struct
      include Core.Unix.Inet_addr

      let gen =
        Int32.gen_incl 0l Int32.max_value
        |> Quickcheck.Generator.map ~f:inet4_addr_of_int32
    end

    let%test_module "InetAddr" = (module Make_test (InetAddr) (InetAddr_gen))
  end )
