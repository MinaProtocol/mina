open Core_kernel
open Fieldslib

(*
module Graphql_args = struct
  module Input = struct
    open Graphql_async

    type 'input_type t = 'input_type Schema.Arg.arg_typ
  end

  module Creator = struct
    open Graphql_async

    type 'input_type t = String.Map.t

    (*
    type 'input_type t =
      | E :
          ('input_type, 'fields) Schema.Arg.arg_list * 'fields
          -> 'input_type t
          *)
  end

  module Output = struct
    type 'input_type t = 'input_type option Input.t
  end

  module Accumulator = struct
    type 'input_type t = unit
  end

  let init () = ()

  let add_field (type f input_type) :
         f Input.t
      -> ( [< `Read | `Set_and_create ]
         , input_type
         , f )
         Fieldslib.Field.t_with_perm
      -> input_type Accumulator.t
      -> (input_type Creator.t -> f) * input_type Accumulator.t =
   fun _t_field _field _acc ->
    ((fun (E (args, coerce)) -> failwith "Unused"), ())

  let finish ((_creator, _x) : 'u * 'input_type Accumulator.t) :
      'input_type Output.t =
    failwith "TODO"
end
*)

module Graphql_fields_raw = struct
  module Make (IO : Graphql_intf.IO) = struct
    module Schema = Graphql_schema.Make (IO)

    module Deriver_basic = struct
      module Input = struct
        type 'input_type t =
          { run : 'ctx. ?doc:string -> unit -> ('ctx, 'input_type) Schema.typ }
      end

      module Creator = struct
        type 'input_type t = unit
      end

      module Output = struct
        type 'input_type t = 'input_type option Input.t
      end

      module Accumulator = struct
        module Elem = struct
          type 'input_type t =
            { run : 'ctx. unit -> ('ctx, 'input_type) Schema.field }
        end

        (** thunks generating the schema in reverse *)
        type 'input_type t = 'input_type Elem.t list
      end

      let init () = []

      let add_field (type f input_type) :
             f Input.t
          -> ( [< `Read | `Set_and_create ]
             , input_type
             , f )
             Fieldslib.Field.t_with_perm
          -> input_type Accumulator.t
          -> (input_type Creator.t -> f) * input_type Accumulator.t =
       fun t_field field acc ->
        ( (fun _ -> failwith "Unused")
        , { Accumulator.Elem.run =
              (fun () ->
                Schema.field
                  (Fields_derivers.name_under_to_camel field)
                  ~args:Schema.Arg.[]
                  ?doc:None ?deprecated:None ~typ:(t_field.run ())
                  ~resolve:(fun _ x -> Field.get field x))
          }
          :: acc )

      (* TODO: Do we need doc and deprecated and name on finish? *)
      let finish ((_creator, schema_rev_thunk) : 'u * 'input_type Accumulator.t)
          : 'input_type Output.t =
        { run =
            (fun ?doc () ->
              Schema.obj "TODO" ?doc ~fields:(fun _ ->
                  List.rev
                  @@ List.map schema_rev_thunk ~f:(fun f ->
                         f.Accumulator.Elem.run ())))
        }

      let int_opt_ = Input.{ run = (fun ?doc:_ () -> Schema.int) }

      let int_ = Input.{ run = (fun ?doc:_ () -> Schema.(non_null int)) }

      let string_opt_ = Input.{ run = (fun ?doc:_ () -> Schema.string) }

      let string_ = Input.{ run = (fun ?doc:_ () -> Schema.(non_null string)) }

      let bool_opt_ = Input.{ run = (fun ?doc:_ () -> Schema.bool) }

      let bool_ = Input.{ run = (fun ?doc:_ () -> Schema.(non_null bool)) }
    end

    include Fields_derivers.Make (Deriver_basic)
  end
end

module Graphql_fields = Graphql_fields_raw.Make (struct
  include Async_kernel.Deferred

  let bind x f = bind x ~f

  module Stream = struct
    type 'a t = 'a Async_kernel.Pipe.Reader.t

    let map t f =
      Async_kernel.Pipe.map' t ~f:(fun q ->
          Async_kernel.Deferred.Queue.map q ~f)

    let iter t f = Async_kernel.Pipe.iter t ~f

    let close = Async_kernel.Pipe.close_read
  end
end)

(** Convert this async Graphql_fields schema type into the official
    Graphql_async one. The real Graphql_async functor application *is*
    equivalent but the way the library is designed we can't actually see it so
    this boils down to an Obj.magic. *)
let typ_conv (typ : ('a, 'b) Graphql_fields.Schema.typ) :
    ('a, 'b) Graphql_async.Schema.typ =
  Obj.magic typ

(* Make sure that this is a deriver *)
module Graphql_fields_ : Fields_derivers.Deriver_intf = Graphql_fields

let%test_module "Test" =
  ( module struct
    (* Pure -- just like Graphql libraries functor application *)
    module Graphql_fields = Graphql_fields_raw.Make (struct
      type +'a t = 'a

      let bind t f = f t

      let return t = t

      module Stream = struct
        type 'a t = 'a Seq.t

        let map t f = Seq.map f t

        let iter t f = Seq.iter f t

        let close _t = ()
      end
    end)

    let introspection_query_raw =
      {graphql|
query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      subscriptionType { name }
      types {
        ...FullType
      }
      directives {
        name
        description
        locations
        args {
          ...InputValue
        }
      }
    }
  }
  fragment FullType on __Type {
    kind
    name
    description
    fields(includeDeprecated: true) {
      name
      description
      args {
        ...InputValue
      }
      type {
        ...TypeRef
      }
      isDeprecated
      deprecationReason
    }
    inputFields {
      ...InputValue
    }
    interfaces {
      ...TypeRef
    }
    enumValues(includeDeprecated: true) {
      name
      description
      isDeprecated
      deprecationReason
    }
    possibleTypes {
      ...TypeRef
    }
  }
  fragment InputValue on __InputValue {
    name
    description
    type { ...TypeRef }
    defaultValue
  }
  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                }
              }
            }
          }
        }
      }
    }
  }
|graphql}

    let introspection_query () =
      match Graphql_parser.parse introspection_query_raw with
      | Ok res ->
          res
      | Error err ->
          failwith err

    type t = { foo_hello : int; bar : string } [@@deriving fields]

    let v = { foo_hello = 1; bar = "baz" }

    let%test_unit "folding creates a graphql object we expect" =
      let open Graphql_fields.Prim in
      let typ1 =
        let typ_input =
          Fields.make_creator (Graphql_fields.init ()) ~foo_hello:int
            ~bar:string
          |> Graphql_fields.finish
        in
        typ_input.run ()
      in
      let typ2 =
        Graphql_fields.Schema.(
          obj "TODO" ?doc:None ~fields:(fun _ ->
              [ field "fooHello"
                  ~args:Arg.[]
                  ~typ:(non_null int)
                  ~resolve:(fun _ t -> t.foo_hello)
              ; field "bar"
                  ~args:Arg.[]
                  ~typ:(non_null string)
                  ~resolve:(fun _ t -> t.bar)
              ]))
      in
      let hit_server (typ : _ Graphql.Schema.typ) =
        let query_top_level =
          Graphql.Schema.(
            field "query" ~typ:(non_null typ)
              ~args:Arg.[]
              ~doc:"sample query"
              ~resolve:(fun _ _ -> v))
        in
        let schema =
          Graphql.Schema.(
            schema [ query_top_level ] ~mutations:[] ~subscriptions:[])
        in
        let res = Graphql.Schema.execute schema () (introspection_query ()) in
        match res with
        | Ok (`Response data) ->
            data |> Yojson.Basic.to_string
        | _ ->
            failwith "Unexpected response"
      in
      [%test_eq: string]
        (hit_server (Obj.magic typ1))
        (hit_server (Obj.magic typ2))
  end )
