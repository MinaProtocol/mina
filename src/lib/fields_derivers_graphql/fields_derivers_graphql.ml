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
module Nullable = struct
  type ('actual, 'nullable) t =
    | Nullable : ('a option, 'a option) t
    | Non_null : ('a, 'a option) t
end

module Graphql_fields_raw = struct
  module Make (IO : Graphql_intf.IO) = struct
    module Schema = Graphql_schema.Make (IO)

    module Input = struct
      module T = struct
        type 'input_type t =
          { run : 'ctx. unit -> ('ctx, 'input_type) Schema.typ }
      end

      type ('input_type, 'a, 'c, 'nullable) t =
        < graphql_fields : 'input_type T.t ref
        ; contramap : ('c -> 'input_type) ref
        ; nullable_graphql_fields : 'nullable T.t ref
        ; .. >
        as
        'a
    end

    module Accumulator = struct
      module T = struct
        type 'input_type t =
          { run : 'ctx. unit -> ('ctx, 'input_type) Schema.field }
      end

      (** thunks generating the schema in reverse *)
      type ('input_type, 'a, 'c, 'nullable) t =
        < graphql_fields_accumulator : 'input_type T.t list ref ; .. > as 'a
        constraint
          ('input_type, 'a, 'c, 'nullable) t =
          ('input_type, 'a, 'c, 'nullable) Input.t
    end

    let add_field (type f input_type orig nullable c' nullable') :
           (orig, 'a, f, nullable) Input.t
        -> ( [< `Read | `Set_and_create ]
           , input_type
           , f )
           Fieldslib.Field.t_with_perm
        -> (input_type, 'row2, c', nullable') Accumulator.t
        -> (_ -> f) * (input_type, 'row2, c', nullable') Accumulator.t =
     fun t_field field acc ->
      let rest = !(acc#graphql_fields_accumulator) in
      acc#graphql_fields_accumulator :=
        { Accumulator.T.run =
            (fun () ->
              Schema.field
                (Fields_derivers_util.name_under_to_camel field)
                ~args:Schema.Arg.[]
                ?doc:None ?deprecated:None
                ~typ:(!(t_field#graphql_fields).Input.T.run ())
                ~resolve:(fun _ x -> !(t_field#contramap) (Field.get field x)))
        }
        :: rest ;
      ((fun _ -> failwith "Unused"), acc)

    (* TODO: Do we need doc and deprecated and name on finish? *)
    let finish ~name ?doc ((_creator, obj) : 'u * _ Accumulator.t) : _ Input.t =
      let graphql_fields_accumulator = !(obj#graphql_fields_accumulator) in
      let graphql_fields =
        { Input.T.run =
            (fun () ->
              Schema.obj name ?doc ~fields:(fun _ ->
                  List.rev
                  @@ List.map graphql_fields_accumulator ~f:(fun g ->
                         g.Accumulator.T.run ()))
              |> Schema.non_null)
        }
      in
      let nullable_graphql_fields =
        { Input.T.run =
            (fun () ->
              Schema.obj name ?doc ~fields:(fun _ ->
                  List.rev
                  @@ List.map graphql_fields_accumulator ~f:(fun g ->
                         g.Accumulator.T.run ())))
        }
      in
      obj#graphql_fields := graphql_fields ;
      obj#nullable_graphql_fields := nullable_graphql_fields ;
      obj

    let int obj =
      (obj#graphql_fields := Input.T.{ run = (fun () -> Schema.(non_null int)) }) ;
      obj#contramap := Fn.id ;
      obj#graphql_fields_accumulator := !(obj#graphql_fields_accumulator) ;
      (obj#nullable_graphql_fields := Input.T.{ run = (fun () -> Schema.int) }) ;
      obj

    let string obj =
      (obj#graphql_fields :=
         Input.T.{ run = (fun () -> Schema.(non_null string)) }) ;
      obj#contramap := Fn.id ;
      obj#graphql_fields_accumulator := !(obj#graphql_fields_accumulator) ;
      (obj#nullable_graphql_fields :=
         Input.T.{ run = (fun () -> Schema.string) }) ;
      obj

    let list x obj : ('input_type list, _, _, _) Input.t =
      (obj#graphql_fields :=
         Input.T.
           { run =
               (fun () -> Schema.(non_null (list (!(x#graphql_fields).run ()))))
           }) ;
      obj#contramap := List.map ~f:!(x#contramap) ;
      obj#graphql_fields_accumulator := !(x#graphql_fields_accumulator) ;
      (obj#nullable_graphql_fields :=
         Input.T.
           { run = (fun () -> Schema.(list (!(x#graphql_fields).run ()))) }) ;
      obj

    (* I can't get OCaml to typecheck this poperly unless we pass the same fresh function twice *)
    let option (x : ('input_type, 'b, 'c, 'nullable) Input.t) obj :
        ('input_type option, _, 'c option, _) Input.t =
      obj#graphql_fields := !(x#nullable_graphql_fields) ;
      obj#nullable_graphql_fields := !(x#nullable_graphql_fields) ;
      obj#contramap := Option.map ~f:!(x#contramap) ;
      obj#graphql_fields_accumulator := !(x#graphql_fields_accumulator) ;
      obj

    let contramap ~(f : 'd -> 'c) (x : ('input_type, 'b, 'c, 'nullable) Input.t)
        obj : ('input_type, _, 'd, _) Input.t =
      obj#graphql_fields := !(x#graphql_fields) ;
      (obj#contramap := fun a -> !(x#contramap) (f a)) ;
      obj#nullable_graphql_fields := !(x#nullable_graphql_fields) ;
      obj#graphql_fields_accumulator := !(x#graphql_fields_accumulator) ;
      obj
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

    let deriver (type a b c d) () :
        < contramap : (a -> b) ref
        ; graphql_fields : c Graphql_fields.Input.T.t ref
        ; nullable_graphql_fields : d Graphql_fields.Input.T.t ref
        ; .. >
        as
        'row =
      let open Graphql_fields in
      let graphql_fields =
        ref Input.T.{ run = (fun () -> failwith "unimplemented") }
      in
      let contramap = ref (fun _ -> failwith "unimplemented") in
      let nullable_graphql_fields =
        ref Input.T.{ run = (fun () -> failwith "unimplemented") }
      in
      let graphql_fields_accumulator = ref [] in
      object
        method graphql_fields = graphql_fields

        method contramap = contramap

        method nullable_graphql_fields = nullable_graphql_fields

        method graphql_fields_accumulator = graphql_fields_accumulator
      end

    let o () = deriver ()

    let ( !. ) x fd acc = Graphql_fields.add_field (x (o ())) fd acc

    let hit_server (typ : _ Graphql_fields.Schema.typ) v =
      let query_top_level =
        Graphql_fields.Schema.(
          field "query" ~typ:(non_null typ)
            ~args:Arg.[]
            ~doc:"sample query"
            ~resolve:(fun _ _ -> v))
      in
      let schema =
        Graphql_fields.Schema.(
          schema [ query_top_level ] ~mutations:[] ~subscriptions:[])
      in
      let res =
        Graphql_fields.Schema.execute schema () (introspection_query ())
      in
      match res with
      | Ok (`Response data) ->
          data |> Yojson.Basic.to_string
      | _ ->
          failwith "Unexpected response"

    module T1 = struct
      type t = { foo_hello : int option; bar : string list } [@@deriving fields]

      let _v = { foo_hello = Some 1; bar = [ "baz1"; "baz2" ] }

      let manual_typ =
        Graphql_fields.Schema.(
          obj "T1" ?doc:None ~fields:(fun _ ->
              [ field "fooHello"
                  ~args:Arg.[]
                  ~typ:int
                  ~resolve:(fun _ t -> t.foo_hello)
              ; field "bar"
                  ~args:Arg.[]
                  ~typ:(non_null (list (non_null string)))
                  ~resolve:(fun _ t -> t.bar)
              ]))

      let derived init =
        let open Graphql_fields in
        Fields.make_creator init
          ~foo_hello:!.(option @@ int @@ o ())
          ~bar:!.(list @@ string @@ o ())
        |> finish ~name:"T1" ?doc:None
    end

    module Or_ignore_test = struct
      type 'a t = Check of 'a | Ignore

      let _of_option = function None -> Ignore | Some x -> Check x

      let to_option = function Ignore -> None | Check x -> Some x

      let derived
          (inner : 'o -> ('input_type, 'b, 'c, _) Graphql_fields.Input.t) init :
          (_, _, 'c t, _) Graphql_fields.Input.t =
        let open Graphql_fields in
        contramap ~f:to_option ((option @@ inner @@ o ()) (o ())) init

      (*
      let derived (type input_type)
          (obj : (input_type, 'row) Graphql_fields.Output.t ) =
        let open Graphql_fields in
        object
          method graphql_fields =
            ref (Input.T.{ run = fun () -> !(obj#graphql_fields).run ~f:of_option () })
          method graphql_fields_non_null =
            ref (Input.T.{ run = fun () -> !(obj#graphql_fields_non_null).run () })
        end
    *)

      (*let ( ~!. )   =*)
      (*add_field ~nullable:Nullable of_option*)
    end

    (*
    let%test_unit "folding creates a graphql object we expect" =
      let open Graphql_fields in
      let generated_typ =
        let typ_input = T1.(option derived) in
        !(typ_input#graphql_fields).run ()
      in
      [%test_eq: string]
        (hit_server generated_typ T1.v)
        (hit_server T1.manual_typ T1.v)
  *)

    module T2 = struct
      type t = { foo : T1.t Or_ignore_test.t } [@@deriving fields]

      let v1 =
        { foo = Check { T1.foo_hello = Some 1; bar = [ "baz1"; "baz2" ] } }

      let v2 = { foo = Ignore }

      let manual_typ =
        Graphql_fields.Schema.(
          obj "T2" ?doc:None ~fields:(fun _ ->
              [ field "foo"
                  ~args:Arg.[]
                  ~typ:T1.manual_typ
                  ~resolve:(fun _ t -> Or_ignore_test.to_option t.foo)
              ]))

      let derived init =
        let open Graphql_fields in
        Fields.make_creator init ~foo:!.(Or_ignore_test.derived @@ T1.derived)
        |> finish ~name:"T2" ?doc:None
    end

    let%test_unit "T2 fold" =
      let open Graphql_fields in
      let generated_typ =
        let typ_input = T2.(option @@ derived @@ o ()) (o ()) in
        !(typ_input#graphql_fields).run ()
      in
      [%test_eq: string]
        (hit_server generated_typ T2.v1)
        (hit_server T2.manual_typ T2.v1) ;
      [%test_eq: string]
        (hit_server generated_typ T2.v2)
        (hit_server T2.manual_typ T2.v2)
  end )
