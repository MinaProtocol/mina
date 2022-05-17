(** Modules providing the typ value used to build GraphQL schemas
    as well as utility functions to build queries and parse responses.

{2 Scalars}
    - [SCALAR]: A module of type [SCALAR] contains a scalar [typ] value from ocaml_graphq_server and a [response_of_json] that can be used for parsing an anwser of this type client side.

    - [NON_NULLABLE_SCALAR]:
    A particular SCALAR with a non nullable typ, on which we can call the [NullableScalar] functor.
    The [Make_non_null_scalar] functor will build a module of type NON_NULLABLE_SCALAR.

    - [NullableScalar]: A functor from [NON_NULLABLE_SCALAR] to [SCALAR].
    - [ListScalar]: A functor from [SCALAR] to [NON_NULLABLE_SCALAR] that creates a list typ.

    When using the module, we are interested in the [out] type,

{2 Non scalars}
Modules and functors for non scalar GraphQL types are similar to the scalar ones with more functionalities related to queries.

- a [query] type
- a [mk_query] function to serialise these queries.
- the type of the [response_of_json] function takes a query as an extra parameter so that the return type can depend on it (using gadts).


These module types and functors are:
 - TYP
 - NON_NULLABLE_TYP
 - NullableTyp
 - ListTyp
 *)

module type TYPES = sig
  (** Users of a GraphQL module will only use the [out] type, which
      matches the [typ] value, and is always equal to
      [out_before_modifiers modifier final_option_modifier].  The
      various functors such as [NullableTyp] or [ListTyp] will modify
      the [modifier] and [final_option_modifier] constructors.

      When building a GraphGL query, server side modifiers such as [list] do not appear on the query itself.
      They do however change the type of the responses.
      This is why we build the [out] type this way and the [response_of_json] function has type 
      ['a query -> Yojson.Basic.t -> 'a modifier final_option_modifier]

   *)

  (** This type is used to track the [nullable] state of the [typ] and is either equal to ['a] or ['a option] *)
  type 'a final_option_modifier

  (** This type is used to track the other [list] or [nullable] modifiers *)
  type 'a modifier

  type out_before_modifiers

  type out = out_before_modifiers modifier final_option_modifier

  (**
      When building a GraphGL query, server side modifiers such as [list] do not appear on the query itself.
      They do however change the type of the responses.
      This is why we build the [out] type this way and the [response_of_json] function has type: 

      ['a query -> Yojson.Basic.t -> 'a modifier final_option_modifier] *)
end

module Make (Schema : Graphql_intf.Schema) = struct
  open Schema

  module type SCALAR = sig
    include TYPES

    val typ : unit -> (unit, out) typ

    val response_of_json : Yojson.Basic.t -> out
  end

  module type NON_NULLABLE_SCALAR = sig
    include SCALAR with type 'a final_option_modifier = 'a

    val typ_nullable : unit -> (unit, out_before_modifiers modifier option) typ
  end

  module type TYP = sig
    include TYPES

    (** [typ] value for the graphql schema *)
    val typ :
      unit -> (unit, out_before_modifiers modifier final_option_modifier) typ

    type 'a query

    val response_of_json :
      'a query -> Yojson.Basic.t -> 'a modifier final_option_modifier

    val mk_query : 'a query -> string
  end

  module type NON_NULLABLE_TYP = sig
    include TYP

    val typ_nullable : unit -> (unit, out_before_modifiers modifier option) typ
  end

  module NullableScalar (Input : NON_NULLABLE_SCALAR) = struct
    type 'a final_option_modifier = 'a option

    type 'a modifier = 'a Input.modifier

    type out_before_modifiers = Input.out_before_modifiers

    type out = out_before_modifiers modifier final_option_modifier

    let response_of_json = function
      | `Null ->
          None
      | json ->
          Some (Input.response_of_json json)

    let typ = Input.typ_nullable
  end

  module NullableTyp
      (Input : NON_NULLABLE_TYP with type 'a final_option_modifier = 'a) =
  struct
    type 'a final_option_modifier = 'a option

    type 'a modifier = 'a Input.modifier

    type out_before_modifiers = Input.out

    type 'a query = 'a Input.query

    let response_of_json query json =
      Json.nullable Input.response_of_json query json

    let typ = Input.typ_nullable

    let mk_query = Input.mk_query
  end

  module ListScalar (Input : SCALAR) = struct
    type 'a final_option_modifier = 'a

    type 'a modifier = 'a Input.modifier Input.final_option_modifier list

    type out_before_modifiers = Input.out_before_modifiers

    type out = out_before_modifiers modifier final_option_modifier

    let response_of_json json =
      match json with
      | `List l ->
          Stdlib.List.map Input.response_of_json l
      | _ ->
          Json.fail_parsing "list" json

    let typ_nullable () = list (Input.typ ())

    let typ () = non_null @@ typ_nullable ()
  end

  module ListTyp (Input : TYP) = struct
    type 'a final_option_modifier = 'a

    type 'a modifier = 'a Input.modifier Input.final_option_modifier list

    type out_before_modifiers = Input.out_before_modifiers

    type out = out_before_modifiers modifier final_option_modifier

    type 'a query = 'a Input.query

    let response_of_json query json =
      Json.non_null_list_of_json Input.response_of_json query json

    let typ_nullable () = list (Input.typ ())

    let typ () = non_null @@ typ_nullable ()

    let mk_query = Input.mk_query
  end

  module Make_non_null_scalar (Input : sig
    type t

    val typ_nullable : unit -> ('a, t option) typ

    val response_of_json : Yojson.Basic.t -> t
  end) =
  struct
    type 'a final_option_modifier = 'a

    type 'a modifier = 'a

    type out_before_modifiers = Input.t

    type out = out_before_modifiers modifier final_option_modifier

    let typ_nullable () = Input.typ_nullable ()

    let typ () = non_null (typ_nullable ())

    let response_of_json = Input.response_of_json
  end

  module Gql_int = Make_non_null_scalar (struct
    type t = int

    let typ_nullable () = int

    let response_of_json = Json.get_int
  end)

  module Gql_string = Make_non_null_scalar (struct
    type t = string

    let typ_nullable () = string

    let response_of_json = function
      | `String s ->
          s
      | json ->
          Json.fail_parsing "string" json
  end)

  module Gql_float = Make_non_null_scalar (struct
    type t = float

    let typ_nullable () = float

    let response_of_json = function
      | `Float f ->
          f
      | json ->
          Json.fail_parsing "float" json
  end)

  module Gql_bool = Make_non_null_scalar (struct
    type t = bool

    let typ_nullable () = bool

    let response_of_json = function
      | `Bool b ->
          b
      | json ->
          Json.fail_parsing "bool" json
  end)

  module Gql_guid = Make_non_null_scalar (struct
    type t = string

    let typ_nullable () = guid

    let response_of_json = function
      | `String s ->
          s
      | json ->
          Json.fail_parsing "guid (as string)" json
  end)
end
