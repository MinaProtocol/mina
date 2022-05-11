(**
   This file provides a wrapper around an ocaml-graphql-server [Schema] module
   order to additionaly build a [to_string] function for query [fields].
   These will be used to serialize queries.
   Instead of a string, this could be extented to build a [variables] json objects.
 *)

module Make (Schema : Graphql_intf.Schema) = struct
  module Arg = struct
    type ('obj_arg, 'a) arg_typ =
      { typ : 'obj_arg Schema.Arg.arg_typ; to_string : 'a -> string }

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

    let get_name : type obj_arg a. (obj_arg, a) arg -> string = function
      | Arg { name; _ } | DefaultArg { name; _ } ->
          name

    let get_doc : type obj_arg a. (obj_arg, a) arg -> string option = function
      | Arg { doc; _ } | DefaultArg { doc; _ } ->
          doc

    type (_, _, _, _) args =
      | [] : ('ctx, 'out, 'out, string) args
      | ( :: ) :
          ('a, 'to_string_input) arg * ('ctx, 'out, 'args, 'args_string) args
          -> ('ctx, 'out, 'a -> 'args, 'to_string_input -> 'args_string) args

    let rec to_string :
        type ctx out arg args_string.
           string
        -> (ctx, out, arg, args_string) args
        -> string list
        -> args_string =
     fun field_name l acc ->
      match l with
      | [] -> (
          match acc with
          | [] ->
              field_name
          | _ ->
              Format.sprintf "%s(%s)" field_name (String.concat ", " acc) )
      | Arg { typ; name; _ } :: t ->
          fun x ->
            to_string field_name t
              (Format.asprintf "%s: %s" name (typ.to_string x) :: acc)
      | DefaultArg { typ; name; _ } :: t ->
          fun x ->
            to_string field_name t
              (Format.asprintf "%s: %s" name (typ.to_string x) :: acc)

    let rec to_string_arg_obj :
        type ctx out arg args_string.
        (ctx, out, arg, args_string) args -> string list -> args_string =
     fun l acc ->
      match l with
      | [] -> (
          match acc with
          | [] ->
              ""
          | _ ->
              Format.sprintf "{%s}" (String.concat ", " acc) )
      | Arg { name; typ; _ } :: t ->
          fun x ->
            to_string_arg_obj t
              (Format.asprintf "%s: %s" name (typ.to_string x) :: acc)
      | DefaultArg { name; typ; _ } :: t ->
          fun x ->
            to_string_arg_obj t
              (Format.asprintf "%s: %s" name (typ.to_string x) :: acc)

    (** build the ocaml-graphql-server [Arg.arg_list]*)
    let rec args_of_myargs :
        type ctx out args_server args_string.
           (ctx, out, args_server, args_string) args
        -> (out, args_server) Schema.Arg.arg_list = function
      | [] ->
          Schema.Arg.[]
      | Arg { name; doc; typ } :: t ->
          let graphql_arg = Schema.Arg.arg ?doc name ~typ:typ.typ in
          Schema.Arg.(graphql_arg :: args_of_myargs t)
      | DefaultArg { name; doc; typ; default } :: t ->
          let graphql_arg = Schema.Arg.arg' ?doc name ~typ:typ.typ ~default in
          Schema.Arg.(graphql_arg :: args_of_myargs t)

    let int =
      { typ = Schema.Arg.int; to_string = Json.string_of_option string_of_int }

    let scalar ?doc name ~coerce ~to_string =
      { typ = Schema.Arg.scalar ?doc name ~coerce
      ; to_string = Json.string_of_option to_string
      }

    let string =
      { typ = Schema.Arg.string
      ; to_string =
          Json.string_of_option (function s ->
              String.escaped ({|"|} ^ s ^ {|"|}))
      }

    let float = { typ = Schema.Arg.float; to_string = string_of_float }

    let bool =
      { typ = Schema.Arg.bool
      ; to_string = Json.string_of_option string_of_bool
      }

    let guid =
      { typ = Schema.Arg.guid
      ; to_string =
          Json.string_of_option (function s ->
              String.escaped ({|"|} ^ s ^ {|"|}))
          (* TODO: Maybe take an int as input of to_sting or (int, string) either *)
      }

    let obj ?doc name ~fields ~coerce ~to_string =
      let build_obj_string = to_string_arg_obj fields [] in
      let gql_server_fields = args_of_myargs fields in
      let typ = Schema.Arg.obj name ?doc ~fields:gql_server_fields ~coerce in
      { typ; to_string = Json.string_of_option @@ to_string build_obj_string }

    let non_null (typ : _ arg_typ) =
      { typ = Schema.Arg.non_null typ.typ
      ; to_string = (function x -> typ.to_string (Some x))
      }

    let list (typ : _ arg_typ) =
      { typ = Schema.Arg.list typ.typ
      ; to_string =
          Json.string_of_option
            (Format.asprintf "%a"
               (Format.pp_print_list (fun fmt s ->
                    Format.fprintf fmt "%s" (typ.to_string s))))
      }

    type 'a enum_value =
      { as_string : string; value : 'a; enum_value : 'a Schema.enum_value }

    let enum_value ?doc ?deprecated as_string ~value =
      { as_string
      ; value
      ; enum_value = Schema.enum_value ?doc ?deprecated as_string ~value
      }

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
      { typ = Schema.Arg.enum ?doc name ~values:ocaml_graphql_server_values
      ; to_string = Json.string_of_option (to_string values)
      }

    let arg ?doc name ~typ = Arg { name; typ; doc }

    let arg' ?doc name ~typ ~default = DefaultArg { name; typ; doc; default }
  end

  module Fields = struct
    (** a record contraining the ocaml-graphql-server [field], its [name]
        and a [to_string] function to be used when serializing a query *)
    type ('ctx, 'src, 'args_to_string, 'out, 'subquery) field =
      { field : ('ctx, 'src) Schema.field
      ; to_string : 'args_to_string
      ; name : string
      }

    type ('ctx, 'src, 'acc) fields =
      | [] : ('ctx, 'src, unit) fields
      | ( :: ) :
          ('ctx, 'src, 'args_to_string, 'out, 'subquery) field
          * ('ctx, 'src, 'acc) fields
          -> ('ctx, 'src, unit -> 'acc) fields

    let rec to_ocaml_grapql_server_fields :
        type acc. ('ctx, 'src, acc) fields -> ('ctx, 'src) Schema.field list =
      function
      | [] ->
          Stdlib.List.[]
      | h :: t ->
          h.field :: to_ocaml_grapql_server_fields t

    let field ?doc ?deprecated name ~typ ~(args : (_, 'out, _, _) Arg.args)
        ~resolve : (_, _, _, 'out, _) field =
      let to_string = Arg.to_string name args [] in
      let args = Arg.args_of_myargs args in
      let field = Schema.field ?doc ?deprecated name ~args ~typ ~resolve in
      { name; field; to_string }

    let io_field ?doc ?deprecated name ~typ ~(args : (_, 'out, _, _) Arg.args)
        ~resolve : (_, _, _, 'out, _) field =
      let to_string = Arg.to_string name args [] in
      let args = Arg.args_of_myargs args in
      let field = Schema.io_field ?doc ?deprecated name ~args ~typ ~resolve in
      { name; field; to_string }
  end

  module Subscription_fields = struct
    (** a record contraining the ocaml-graphql-server [field], its [name]
        and a [to_string] function to be used when serializing a query *)
    type ('ctx, 'src, 'args_to_string, 'out, 'subquery) subscription_field =
      { field : 'ctx Schema.subscription_field
      ; to_string : 'args_to_string
      ; name : string
      }

    type ('ctx, 'src, 'acc) subscription_fields =
      | [] : ('ctx, 'src, unit) subscription_fields
      | ( :: ) :
          ('ctx, 'src, 'args_to_string, 'out, 'subquery) subscription_field
          * ('ctx, 'src, 'acc) subscription_fields
          -> ('ctx, 'src, unit -> 'acc) subscription_fields

    let rec to_ocaml_grapql_server_fields :
        type acc.
           ('ctx, 'src, acc) subscription_fields
        -> 'ctx Schema.subscription_field list = function
      | [] ->
          Stdlib.List.[]
      | h :: t ->
          h.field :: to_ocaml_grapql_server_fields t

    let subscription_field ?doc ?deprecated name ~typ
        ~(args : (_, 'out, _, _) Arg.args) ~resolve :
        (_, _, _, 'out, _) subscription_field =
      let to_string = Arg.to_string name args [] in
      let args = Arg.args_of_myargs args in
      let field =
        Schema.subscription_field ?doc ?deprecated name ~args ~typ ~resolve
      in
      { name; field; to_string }
  end

  let field = Fields.field

  let io_field = Fields.io_field

  let subscription_field = Subscription_fields.subscription_field

  let obj ?doc name ~(fields : unit -> _ Fields.fields) =
    let fields = lazy (Fields.to_ocaml_grapql_server_fields (fields ())) in
    Schema.obj ?doc name ~fields:(fun _ -> Lazy.force fields)

  let non_null = Schema.non_null

  let string = Schema.string

  let enum = Schema.enum

  let int = Schema.int

  let enum_value = Schema.enum_value

  type ('a, 'b) typ = ('a, 'b) Schema.typ
end

module Make2 (Schema : Graphql_intf.Schema) = struct
  include Schema
  include Make (Schema)
end
