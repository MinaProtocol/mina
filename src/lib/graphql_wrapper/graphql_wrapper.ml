(**
   This file provides a wrapper around an ocaml-graphql-server [Schema] module,
   in order to build [to_json] functions for query [fields].
   These can later be used to serialize queries.

   - The [Arg.scalar] function has a new [~to_json] argument that is
   morally the inverse of [coerce].  The most common case where these
   functions are not inverse of one another is when the [coerce] function can fail
   during parsing and return a [result] type, but it does not make
   sense for the [to_json] function to take a result type as input.

   - The [Arg.obj] function has a new [~split] argument, which is also morally the inverse of coerce:
     while the [coerce] function for [obj] arguments builds an ocaml value from the fields of the objects,
   the [split] describes how to split an ocaml value into these fields.

    The [split] argument is used as such:
          {[
          let add_payment_reciept_input =
              obj "AddPaymentReceiptInput"
              ~coerce:(fun payment added_time -> { payment; added_time })
              ~split:(fun f (t : t) -> f t.payment t.added_time)
              ~fields:[...]
          ]}

    The [to_json] function from the [add_payment_reciept_input] can then be used as such :
    {[let input_as_json = add_payment_reciept_input.to_json
                          {payment = "..."; added_time = "..."}]}
 *)

module Make (Schema : Graphql_intf.Schema) = struct
  (** wrapper around the [enum_value] type *)
  type 'a enum_value =
    { as_string : string; value : 'a; enum_value : 'a Schema.enum_value }

  (** wrapper around the [enum_value] function *)
  let enum_value ?doc ?deprecated as_string ~value =
    { as_string
    ; value
    ; enum_value = Schema.enum_value ?doc ?deprecated as_string ~value
    }

  module Arg = struct
    (** wrapper around the [Arg.arg_typ] type *)
    type ('obj_arg, 'a) arg_typ =
      { arg_typ : 'obj_arg Schema.Arg.arg_typ; to_json : 'a -> Yojson.Basic.t }

    (** wrapper around the [Arg.arg] type *)
    type ('obj_arg, 'a) arg =
      | Arg :
          { name : string; doc : string option; typ : ('obj_arg, 'a) arg_typ }
          -> ('obj_arg, 'a) arg
      | DefaultArg :
          { name : string
          ; doc : string option
          ; typ : ('obj_arg option, 'a) arg_typ
          ; default : 'obj_arg
          }
          -> ('obj_arg, 'a) arg

    (**
       Wrapper around the [Arg.arg_list] type.

       The ocaml-graphql-server library uses this gadt type for lists of
       arguments used with [fields] and [obj] argument types.

       This enables to the correct types for the [coerce] and [resolve] functions,
       in the ['args] parameter below.

       We wrap around this and do the same thing to build the types of the [to_json] functions.
     *)

    type (_, _, _, _, _) args =
      | [] : ('ctx, 'out, 'out, string * Yojson.Basic.t, Yojson.Basic.t) args
      | ( :: ) :
          ('a, 'input) arg
          * ('ctx, 'out, 'args, 'field_to_json, 'obj_to_json) args
          -> ( 'ctx
             , 'out
             , 'a -> 'args
             , 'input -> 'field_to_json
             , 'input -> 'obj_to_json )
             args

    (** [field_to_json] builds the serializer function for a field, based on the list of its arguments.*)
    let rec field_to_json :
        type ctx out arg field_to_json obj_to_json.
           string
        -> (ctx, out, arg, field_to_json, obj_to_json) args
        -> (string * Yojson.Basic.t) list
        -> field_to_json =
     fun field_name l acc ->
      match l with
      | [] ->
          (field_name, `Assoc acc)
      | Arg { typ; name; _ } :: t ->
          fun x -> field_to_json field_name t ((name, typ.to_json x) :: acc)
      | DefaultArg { typ; name; _ } :: t ->
          fun x -> field_to_json field_name t ((name, typ.to_json x) :: acc)

    (** [arg_obj_to_json] builds the serializer function for an obj argument, based on the list of its fields.*)
    let rec arg_obj_to_json :
        type ctx out arg field_to_json obj_to_json.
           (ctx, out, arg, field_to_json, obj_to_json) args
        -> (string * Yojson.Basic.t) list
        -> obj_to_json =
     fun l acc ->
      match l with
      | [] ->
          `Assoc acc
      | Arg { name; typ; _ } :: t ->
          fun x -> arg_obj_to_json t ((name, typ.to_json x) :: acc)
      | DefaultArg { name; typ; _ } :: t ->
          fun x -> arg_obj_to_json t ((name, typ.to_json x) :: acc)

    (** extracts the wrapped [Arg.arg_list] to pass to ocaml-graphql-server functions *)
    let rec to_ocaml_graphql_server_args :
        type ctx out args_server field_to_json obj_to_json.
           (ctx, out, args_server, field_to_json, obj_to_json) args
        -> (out, args_server) Schema.Arg.arg_list = function
      | [] ->
          Schema.Arg.[]
      | Arg { name; doc; typ } :: t ->
          let graphql_arg = Schema.Arg.arg ?doc name ~typ:typ.arg_typ in
          Schema.Arg.(graphql_arg :: to_ocaml_graphql_server_args t)
      | DefaultArg { name; doc; typ; default } :: t ->
          let graphql_arg =
            Schema.Arg.arg' ?doc name ~typ:typ.arg_typ ~default
          in
          Schema.Arg.(graphql_arg :: to_ocaml_graphql_server_args t)

    let int =
      { arg_typ = Schema.Arg.int
      ; to_json = Json.json_of_option (fun i -> `Int i)
      }

    let scalar ?doc name ~coerce ~to_json =
      { arg_typ = Schema.Arg.scalar ?doc name ~coerce
      ; to_json = Json.json_of_option to_json
      }

    let string =
      { arg_typ = Schema.Arg.string
      ; to_json = Json.json_of_option (function s -> `String s)
      }

    let float =
      { arg_typ = Schema.Arg.float
      ; to_json = Json.json_of_option (function f -> `Float f)
      }

    let bool =
      { arg_typ = Schema.Arg.bool
      ; to_json = Json.json_of_option (function f -> `Bool f)
      }

    let guid =
      { arg_typ = Schema.Arg.guid
      ; to_json = Json.json_of_option (function s -> `String s)
      }

    let obj ?doc name ~fields ~coerce ~split =
      let build_obj_json = arg_obj_to_json fields [] in
      let gql_server_fields = to_ocaml_graphql_server_args fields in
      let arg_typ =
        Schema.Arg.obj name ?doc ~fields:gql_server_fields ~coerce
      in
      { arg_typ; to_json = Json.json_of_option @@ split build_obj_json }

    let non_null (arg_typ : _ arg_typ) =
      { arg_typ = Schema.Arg.non_null arg_typ.arg_typ
      ; to_json = (function x -> arg_typ.to_json (Some x))
      }

    let list (arg_typ : _ arg_typ) =
      { arg_typ = Schema.Arg.list arg_typ.arg_typ
      ; to_json =
          Json.json_of_option (function l -> `List (List.map arg_typ.to_json l))
      }

    (** wrapper around the enum arg_typ.
        For this type, the [to_json] function can be infered from the list of enum_value.*)
    let enum ?doc name ~(values : _ enum_value list) =
      let rec to_string (values : _ enum_value list) v =
        match values with
        | { as_string; value; _ } :: _ when value = v ->
            as_string
        | _ :: q ->
            to_string q v
        | _ ->
            failwith
            @@ Format.asprintf
                 "Could not convert GraphQL query argument to string for enum \
                  type <%s>. Was this argument declared via an enum_value ?"
                 name
      in
      let ocaml_graphql_server_values =
        List.map (function { enum_value; _ } -> enum_value) values
      in
      { arg_typ = Schema.Arg.enum ?doc name ~values:ocaml_graphql_server_values
      ; to_json = Json.json_of_option (fun v -> `String (to_string values v))
      }

    let arg ?doc name ~typ = Arg { name; typ; doc }

    let arg' ?doc name ~typ ~default = DefaultArg { name; typ; doc; default }
  end

  module Fields = struct
    (** a record contraining the ocaml-graphql-server [field], its [name]
        and a [to_string] function to be used when serializing a query *)
    type ('ctx, 'src, 'args_to_json, 'out, 'subquery) field =
      { field : ('ctx, 'src) Schema.field
      ; to_json : 'args_to_json
      ; name : string
      }

    (** wrapper around the [field] typ *)
    let field ?doc ?deprecated name ~typ ~(args : (_, 'out, _, _, _) Arg.args)
        ~resolve : (_, _, _, 'out, _) field =
      let to_json = Arg.field_to_json name args [] in
      let args = Arg.to_ocaml_graphql_server_args args in
      let field = Schema.field ?doc ?deprecated name ~args ~typ ~resolve in
      { name; field; to_json }

    (** wrapper around the [io_field] typ*)
    let io_field ?doc ?deprecated name ~typ
        ~(args : (_, 'out, _, _, _) Arg.args) ~resolve :
        (_, _, _, 'out, _) field =
      let to_json = Arg.field_to_json name args [] in
      let args = Arg.to_ocaml_graphql_server_args args in
      let field = Schema.io_field ?doc ?deprecated name ~args ~typ ~resolve in
      { name; field; to_json }
  end

  module Abstract_fields = struct
    type ('ctx, 'src, 'args_to_json, 'out, 'subquery) abstract_field =
      { field : Schema.abstract_field; to_json : 'args_to_json; name : string }

    (** wrapper around the [abstract_field] typ*)
    let abstract_field ?doc ?deprecated name ~typ
        ~(args : (_, 'out, _, _, _) Arg.args) :
        (_, _, _, 'out, _) abstract_field =
      let to_json = Arg.field_to_json name args [] in
      let args = Arg.to_ocaml_graphql_server_args args in
      let field = Schema.abstract_field ?doc ?deprecated name ~typ ~args in
      { name; field; to_json }
  end

  module Subscription_fields = struct
    (** A record contraining the ocaml-graphql-server [subscription_fields], its [name]
        and a [to_json] function to be used when serializing a query *)
    type ('ctx, 'src, 'args_to_json, 'out, 'subquery) subscription_field =
      { field : 'ctx Schema.subscription_field
      ; to_json : 'args_to_json
      ; name : string
      }

    (** wrapper around the [subscription_field] typ*)
    let subscription_field ?doc ?deprecated name ~typ
        ~(args : (_, 'out, _, _, _) Arg.args) ~resolve :
        (_, _, _, 'out, _) subscription_field =
      let to_json = Arg.field_to_json name args [] in
      let args = Arg.to_ocaml_graphql_server_args args in
      let field =
        Schema.subscription_field ?doc ?deprecated name ~args ~typ ~resolve
      in
      { name; field; to_json }
  end

  let field ?doc ?deprecated name ~typ ~args ~resolve =
    (Fields.field ?doc ?deprecated name ~typ ~args ~resolve).field

  let io_field ?doc ?deprecated name ~typ ~args ~resolve =
    (Fields.io_field ?doc ?deprecated name ~typ ~args ~resolve).field

  let subscription_field ?doc ?deprecated name ~typ ~args ~resolve =
    (Subscription_fields.subscription_field ?doc ?deprecated name ~typ ~args
       ~resolve )
      .field

  let abstract_field ?doc ?deprecated name ~typ ~args =
    (Abstract_fields.abstract_field ?doc ?deprecated name ~typ ~args).field

  let enum ?doc name ~values =
    Schema.enum ?doc name
      ~values:(List.map (function v -> v.enum_value) values)

  (** The [Propagated] module contains the parts of the Schema we do not modify *)
  module Propagated = struct
    let obj = Schema.obj

    let schema = Schema.schema

    let interface = Schema.interface

    let non_null = Schema.non_null

    let string = Schema.string

    let list = Schema.list

    let bool = Schema.bool

    let int = Schema.int

    type ('a, 'b) typ = ('a, 'b) Schema.typ

    let scalar = Schema.scalar

    type ('a, 'b) abstract_value = ('a, 'b) Schema.abstract_value

    let guid = Schema.guid

    let add_type = Schema.add_type

    let float = Schema.float

    type 'ctx resolve_info = 'ctx Schema.resolve_info =
      { ctx : 'ctx
      ; field : Graphql_parser.field
      ; fragments : Schema.fragment_map
      ; variables : Schema.variable_map
      }

    type 'a schema = 'a Schema.schema

    type ('a, 'b) field = ('a, 'b) Schema.field

    type 'a subscription_field = 'a Schema.subscription_field

    type deprecated = Schema.deprecated

    type variable_map = Schema.variable_map

    type fragment_map = Schema.fragment_map

    let execute = Schema.execute

    type 'a response = 'a Schema.response

    type variables = (string * Graphql_parser.const_value) list

    type abstract_field = Schema.abstract_field

    let union = Schema.union

    type ('a, 'b) abstract_typ = ('a, 'b) Schema.abstract_typ

    module StringMap = Schema.StringMap
    module Io = Schema.Io
  end

  include Propagated
end
