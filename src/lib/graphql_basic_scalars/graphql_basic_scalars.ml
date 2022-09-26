(**
   This file defines basic graphql scalars in a shape usable by graphql_ppx for serialising.

   It is meant to be used by backend graphql code.

   The [grapqh_lib] library re-exports these basic scalars as well as other ones,
   and is meant to be used by client code (via grapqh_ppx).
 *)

open Graphql_async.Schema

module type Json_intf = sig
  type t

  val parse : Yojson.Basic.t -> t

  val serialize : t -> Yojson.Basic.t

  val typ : unit -> ('a, t option) Graphql_async.Schema.typ
end

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
  let neg = String.starts_with ~prefix:"-" s in
  if neg then
    failwith "Cannot parse string starting with a minus as an unsigned integer"
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

module Make_scalar_using_base64 (T : sig
  type t

  val to_base64 : t -> string

  val of_base64 : string -> t Core_kernel.Or_error.t
end) (Scalar : sig
  val name : string

  val doc : string
end) : Json_intf with type t = T.t = struct
  type t = T.t

  let parse json =
    Yojson.Basic.Util.to_string json
    |> T.of_base64 |> Core_kernel.Or_error.ok_exn

  let serialize x = `String (T.to_base64 x)

  let typ () =
    Graphql_async.Schema.scalar Scalar.name ~doc:Scalar.doc ~coerce:serialize
end

module InetAddr =
  Make_scalar_using_to_string
    (Core.Unix.Inet_addr)
    (struct
      let name = "InetAddr"

      let doc = "network address"
    end)
