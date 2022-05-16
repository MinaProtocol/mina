(** A module providing the typ value used to build the graphql schema as well as
    well as utility functions to build queries and parse responses. *)

module Make (Schema : Graphql_intf.Schema) = struct
  open Schema

  module type SCALAR = sig
    type 'a final_option_modifier

    type 'a modifier

    type out_before_modifiers

    type out = out_before_modifiers modifier final_option_modifier

    val typ :
      unit -> (unit, out_before_modifiers modifier final_option_modifier) typ

    val response_of_json : Yojson.Basic.t -> out
  end

  module type NON_NULLABLE_SCALAR = sig
    include SCALAR with type 'a final_option_modifier = 'a

    val typ_nullable : unit -> (unit, out_before_modifiers modifier option) typ
  end

  module type MAYBE_NULLABLE_TYP = sig
    type 'a final_option_modifier

    type 'a modifier

    type out_before_modifiers

    type out = out_before_modifiers modifier final_option_modifier

    (** [typ] value for the graphql schema *)
    val typ :
      unit -> (unit, out_before_modifiers modifier final_option_modifier) typ

    type 'a query

    val response_of_json :
      'a query -> Yojson.Basic.t -> 'a modifier final_option_modifier

    val mk_query : 'a query -> string
  end

  module type NOT_NULLABLE_TYP = sig
    include MAYBE_NULLABLE_TYP

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

  module Nullable
      (Input : NOT_NULLABLE_TYP with type 'a final_option_modifier = 'a) =
  struct
    type 'a final_option_modifier = 'a option

    type 'a modifier = 'a Input.modifier

    type out_before_modifiers =
      Input.out_before_modifiers Input.modifier Input.final_option_modifier

    type 'a query = 'a Input.query

    let response_of_json query json =
      Json.nullable Input.response_of_json query json

    let typ = Input.typ_nullable

    let mk_query = Input.mk_query
  end

  module List (Input : MAYBE_NULLABLE_TYP) = struct
    type 'a final_option_modifier = 'a

    type 'a modifier = 'a Input.modifier Input.final_option_modifier list

    type out_before_modifiers = Input.out_before_modifiers

    type out = out_before_modifiers modifier final_option_modifier

    type 'a query = 'a Input.query

    type 'a res = 'a Input.modifier Input.final_option_modifier list

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
