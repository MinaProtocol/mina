(**
   Utility functors to build custom graphql scalars.  These functors
   parametric in the GraphQL Schema module, so that we can use them
   either with the async version (for the main application) or the
   pure version (for tests).  *)

module type Schema = sig
  type ('a, 'b) typ

  val scalar :
       ?doc:string
    -> string
    -> coerce:('a -> Yojson.Basic.t)
    -> ('ctx, 'a option) typ

  val string : ('ctx, string option) typ
end

module type Json_intf_any_typ = sig
  type t

  type ('a, 'b) typ

  val parse : Yojson.Basic.t -> t

  val serialize : t -> Yojson.Basic.t

  val typ : unit -> ('a, t option) typ
end

module Make_scalar_using_to_string (T : sig
  type t

  val to_string : t -> string

  val of_string : string -> t
end) (Scalar : sig
  val name : string

  val doc : string
end)
(Schema : Schema) :
  Json_intf_any_typ
    with type ('a, 'b) typ := ('a, 'b) Schema.typ
    with type t = T.t = struct
  type t = T.t

  let parse json = Yojson.Basic.Util.to_string json |> T.of_string

  let serialize x = `String (T.to_string x)

  let typ () = Schema.scalar Scalar.name ~doc:Scalar.doc ~coerce:serialize
end

module Make_scalar_using_base58_check (T : sig
  type t

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t
end) (Scalar : sig
  val name : string

  val doc : string
end)
(Schema : Schema) :
  Json_intf_any_typ
    with type ('a, 'b) typ := ('a, 'b) Schema.typ
    with type t = T.t = struct
  type t = T.t

  let parse json = Yojson.Basic.Util.to_string json |> T.of_base58_check_exn

  let serialize x = `String (T.to_base58_check x)

  let typ () = Schema.scalar Scalar.name ~doc:Scalar.doc ~coerce:serialize
end

module Make_scalar_using_base64 (T : sig
  type t

  val to_base64 : t -> string

  val of_base64 : string -> t Core_kernel.Or_error.t
end) (Scalar : sig
  val name : string

  val doc : string
end)
(Schema : Schema) :
  Json_intf_any_typ
    with type ('a, 'b) typ := ('a, 'b) Schema.typ
    with type t = T.t = struct
  type t = T.t

  let parse json =
    Yojson.Basic.Util.to_string json
    |> T.of_base64 |> Core_kernel.Or_error.ok_exn

  let serialize x = `String (T.to_base64 x)

  let typ () = Schema.scalar Scalar.name ~doc:Scalar.doc ~coerce:serialize
end

(** The async schema *)
module Schema = Graphql_wrapper.Make (Graphql_async.Schema)

(** The schema for non async tests *)
module Test_schema = Graphql.Schema
