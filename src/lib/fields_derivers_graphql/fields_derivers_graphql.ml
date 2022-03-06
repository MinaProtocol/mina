open Core_kernel
open Fieldslib

module Graphql_raw = struct
  module Make (Schema : Graphql_intf.Schema) = struct
    module Args = struct
      module Input = struct
        type ('row, 'result, 'ty, 'nullable) t =
          < graphql_arg : (unit -> 'ty Schema.Arg.arg_typ) ref
          ; nullable_graphql_arg : (unit -> 'nullable Schema.Arg.arg_typ) ref
          ; map : ('ty -> 'result) ref
          ; .. >
          as
          'row
      end

      module Acc = struct
        module T = struct
          type ('ty, 'fields) t_inner =
            { graphql_arg_fields : ('ty, 'fields) Schema.Arg.arg_list
            ; graphql_arg_coerce : 'fields
            }

          type 'ty t = Init | Acc : ('ty, 'fields) t_inner -> 'ty t
        end

        type ('row, 'result, 'ty, 'nullable) t =
          < graphql_arg_accumulator : 'result T.t ref ; .. > as 'row
          constraint
            ('row, 'c, 'ty, 'nullable) t =
            ('row, 'c, 'ty, 'nullable) Input.t
      end

      module Creator = struct
        type ('row, 'c, 'ty, 'nullable) t = < .. > as 'row
          constraint
            ('row, 'c, 'ty, 'nullable) t =
            ('row, 'c, 'ty, 'nullable) Input.t
      end

      module Output = struct
        type ('row, 'c, 'ty, 'nullable) t = < .. > as 'row
          constraint
            ('row, 'c, 'ty, 'nullable) t =
            ('row, 'c, 'ty, 'nullable) Input.t
      end

      let add_field (type f f' ty ty' nullable1 nullable2) :
             ('f_row, f', f, nullable1) Input.t
          -> ([< `Read | `Set_and_create ], _, _) Field.t_with_perm
          -> ('row, ty', ty, nullable2) Acc.t
          -> (('row, ty', ty, nullable2) Creator.t -> f')
             * ('row_after, ty', ty, nullable2) Acc.t =
       fun f_input field acc ->
        let ref_as_pipe = ref None in
        let arg =
          Schema.Arg.arg
            (Fields_derivers.name_under_to_camel field)
            ~typ:(!(f_input#graphql_arg) ())
        in
        let () =
          let inner_acc = acc#graphql_arg_accumulator in
          match !inner_acc with
          | Init ->
              inner_acc :=
                Acc
                  { graphql_arg_coerce =
                      (fun x ->
                        ref_as_pipe := Some x ;
                        !(acc#graphql_creator) acc)
                  ; graphql_arg_fields = [ arg ]
                  }
          | Acc { graphql_arg_fields; graphql_arg_coerce } -> (
              match graphql_arg_fields with
              | [] ->
                  inner_acc :=
                    Acc
                      { graphql_arg_coerce =
                          (fun x ->
                            ref_as_pipe := Some x ;
                            !(acc#graphql_creator) acc)
                      ; graphql_arg_fields = [ arg ]
                      }
              | _ ->
                  inner_acc :=
                    Acc
                      { graphql_arg_coerce =
                          (fun x ->
                            ref_as_pipe := Some x ;
                            graphql_arg_coerce)
                      ; graphql_arg_fields = arg :: graphql_arg_fields
                      } )
        in
        ( (fun _creator_input -> !(f_input#map) @@ Option.value_exn !ref_as_pipe)
        , acc )

      let finish ?doc ~name (type ty result nullable) :
             (('row, result, ty, nullable) Input.t -> result)
             * ('row, result, ty, nullable) Acc.t
          -> _ Output.t =
       fun (creator, acc) ->
        acc#graphql_creator := creator ;
        (acc#graphql_arg :=
           fun () ->
             match !(acc#graphql_arg_accumulator) with
             | Init ->
                 failwith "Graphql args need at least one field"
             | Acc { graphql_arg_fields; graphql_arg_coerce } ->
                 (* TODO: Figure out why the typechecker doesn't like this
                  * expression and remove Obj.magic. *)
                 Obj.magic
                 @@ Schema.Arg.(
                      obj ?doc (name ^ "Input") ~fields:graphql_arg_fields
                        ~coerce:graphql_arg_coerce
                      |> non_null)) ;
        (acc#nullable_graphql_arg :=
           fun () ->
             match !(acc#graphql_arg_accumulator) with
             | Init ->
                 failwith "Graphql args need at least one field"
             | Acc { graphql_arg_fields; graphql_arg_coerce } ->
                 (* TODO: See above *)
                 Obj.magic
                 @@ Schema.Arg.(
                      obj ?doc (name ^ "Input") ~fields:graphql_arg_fields
                        ~coerce:graphql_arg_coerce)) ;
        acc

      let int obj =
        (obj#graphql_arg := fun () -> Schema.Arg.(non_null int)) ;
        obj#map := Fn.id ;
        obj#graphql_arg_accumulator := !(obj#graphql_arg_accumulator) ;
        (obj#nullable_graphql_arg := fun () -> Schema.Arg.int) ;
        obj

      let string obj =
        (obj#graphql_arg := fun () -> Schema.Arg.(non_null string)) ;
        obj#map := Fn.id ;
        obj#graphql_arg_accumulator := !(obj#graphql_arg_accumulator) ;
        (obj#nullable_graphql_arg := fun () -> Schema.Arg.string) ;
        obj

      let bool obj =
        (obj#graphql_arg := fun () -> Schema.Arg.(non_null bool)) ;
        obj#map := Fn.id ;
        obj#graphql_arg_accumulator := !(obj#graphql_arg_accumulator) ;
        (obj#nullable_graphql_arg := fun () -> Schema.Arg.bool) ;
        obj

      let list x obj : (_, 'result list, 'input_type list, _) Input.t =
        (obj#graphql_arg :=
           fun () -> Schema.Arg.(non_null (list (!(x#graphql_arg) ())))) ;
        obj#map := List.map ~f:!(x#map) ;
        obj#graphql_arg_accumulator := !(x#graphql_arg_accumulator) ;
        (obj#nullable_graphql_arg :=
           fun () -> Schema.Arg.(list (!(x#graphql_arg) ()))) ;
        obj

      let option (x : (_, 'result, 'input_type, _) Input.t) obj =
        obj#graphql_arg := !(x#nullable_graphql_arg) ;
        obj#nullable_graphql_arg := !(x#nullable_graphql_arg) ;
        obj#map := Option.map ~f:!(x#map) ;
        obj#graphql_arg_accumulator := !(x#graphql_arg_accumulator) ;
        obj

      let map ~(f : 'c -> 'd) (x : (_, 'c, 'input_type, _) Input.t) obj :
          (_, 'd, 'input_type, _) Input.t =
        obj#graphql_arg := !(x#graphql_arg) ;
        (obj#map := fun a -> f (!(x#map) a)) ;
        obj#nullable_graphql_arg := !(x#nullable_graphql_arg) ;
        obj#graphql_arg_accumulator := !(x#graphql_arg_accumulator) ;
        obj
    end

    module Fields = struct
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
          < graphql_fields_accumulator : 'c T.t list ref ; .. > as 'a
          constraint
            ('input_type, 'a, 'c, 'nullable) t =
            ('input_type, 'a, 'c, 'nullable) Input.t
      end

      let add_field (type f input_type orig nullable c' nullable') :
             (orig, 'a, f, nullable) Input.t
          -> ([< `Read | `Set_and_create ], c', f) Fieldslib.Field.t_with_perm
          -> (input_type, 'row2, c', nullable') Accumulator.t
          -> (_ -> f) * (input_type, 'row2, c', nullable') Accumulator.t =
       fun t_field field acc ->
        let rest = !(acc#graphql_fields_accumulator) in
        acc#graphql_fields_accumulator :=
          { Accumulator.T.run =
              (fun () ->
                Schema.field
                  (Fields_derivers.name_under_to_camel field)
                  ~args:Schema.Arg.[]
                  ?doc:None ?deprecated:None
                  ~typ:(!(t_field#graphql_fields).Input.T.run ())
                  ~resolve:(fun _ x -> !(t_field#contramap) (Field.get field x)))
          }
          :: rest ;
        ((fun _ -> failwith "Unused"), acc)

      let finish ~name ?doc ((_creator, obj) : 'u * _ Accumulator.t) : _ Input.t
          =
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
        obj#contramap := Fn.id ;
        obj

      let int obj =
        (obj#graphql_fields :=
           Input.T.{ run = (fun () -> Schema.(non_null int)) }) ;
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

      let bool obj =
        (obj#graphql_fields :=
           Input.T.{ run = (fun () -> Schema.(non_null bool)) }) ;
        obj#contramap := Fn.id ;
        obj#graphql_fields_accumulator := !(obj#graphql_fields_accumulator) ;
        (obj#nullable_graphql_fields :=
           Input.T.{ run = (fun () -> Schema.bool) }) ;
        obj

      let list x obj : ('input_type list, _, _, _) Input.t =
        (obj#graphql_fields :=
           Input.T.
             { run =
                 (fun () ->
                   Schema.(non_null (list (!(x#graphql_fields).run ()))))
             }) ;
        obj#contramap := List.map ~f:!(x#contramap) ;
        obj#graphql_fields_accumulator := !(x#graphql_fields_accumulator) ;
        (obj#nullable_graphql_fields :=
           Input.T.
             { run = (fun () -> Schema.(list (!(x#graphql_fields).run ()))) }) ;
        obj

      let option (x : ('input_type, 'b, 'c, 'nullable) Input.t) obj :
          ('input_type option, _, 'c option, _) Input.t =
        obj#graphql_fields := !(x#nullable_graphql_fields) ;
        obj#nullable_graphql_fields := !(x#nullable_graphql_fields) ;
        obj#contramap := Option.map ~f:!(x#contramap) ;
        obj#graphql_fields_accumulator := !(x#graphql_fields_accumulator) ;
        obj

      let contramap ~(f : 'd -> 'c)
          (x : ('input_type, 'b, 'c, 'nullable) Input.t) obj :
          ('input_type, _, 'd, _) Input.t =
        obj#graphql_fields := !(x#graphql_fields) ;
        (obj#contramap := fun a -> !(x#contramap) (f a)) ;
        obj#nullable_graphql_fields := !(x#nullable_graphql_fields) ;
        obj#graphql_fields_accumulator := !(x#graphql_fields_accumulator) ;
        obj
    end

    let rec arg_to_yojson_rec (arg : Graphql_parser.const_value) : Yojson.Safe.t
        =
      match arg with
      | `Null ->
          `Null
      | `Int x ->
          `Int x
      | `Float x ->
          `Float x
      | `String x ->
          `String x
      | `Bool x ->
          `Bool x
      | `Enum x ->
          `String x
      | `List x ->
          `List (List.map x ~f:arg_to_yojson_rec)
      | `Assoc x ->
          `Assoc
            (List.map x ~f:(fun (key, value) -> (key, arg_to_yojson_rec value)))

    let arg_to_yojson arg : (Yojson.Safe.t, string) result =
      Ok (arg_to_yojson_rec arg)
  end
end

module Graphql_query = struct
  module Input = struct
    type 'a t = < graphql_query : string option ref ; .. > as 'a
  end

  module Accumulator = struct
    type 'a t =
      < graphql_query_accumulator : (string * string option) list ref ; .. >
      as
      'a
      constraint 'a t = 'a Input.t
  end

  let add_field : 'a Input.t -> 'field -> 'obj -> 'creator * 'obj =
   fun t_field field acc_obj ->
    let rest = !(acc_obj#graphql_query_accumulator) in
    acc_obj#graphql_query_accumulator :=
      (Fields_derivers.name_under_to_camel field, !(t_field#graphql_query))
      :: rest ;
    ((fun _ -> failwith "unused"), acc_obj)

  let finish (_creator, obj) =
    let graphql_query_accumulator = !(obj#graphql_query_accumulator) in
    obj#graphql_query :=
      Some
        (sprintf "{\n%s\n}"
           ( List.map graphql_query_accumulator ~f:(fun (k, v) ->
                 match v with None -> k | Some v -> sprintf "%s %s" k v)
           |> List.rev |> String.concat ~sep:"\n" )) ;
    obj

  let scalar obj =
    obj#graphql_query := None ;
    obj

  let int obj = scalar obj

  let string obj = scalar obj

  let bool obj = scalar obj

  (* nullable and lists of things are projected to the inner thing ONLY IF inner
   * projectable. *)
  let wrapped x obj =
    obj#graphql_query := !(x#graphql_query) ;
    obj

  let option x obj = wrapped x obj

  let list x obj = wrapped x obj

  let inner_query obj = !(obj#graphql_query)
end

module IO = struct
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
end

module Schema = Graphql_schema.Make (IO)
module Graphql = Graphql_raw.Make (Schema)

module Test = struct
  let parse_query str =
    match Graphql_parser.parse str with
    | Ok res ->
        res
    | Error err ->
        failwith err

  let introspection_query () =
    parse_query Fields_derivers.introspection_query_raw
end

let%test_module "Test" =
  ( module struct
    (* Pure -- just like Graphql libraries functor application *)
    module IO = struct
      type +'a t = 'a

      let bind t f = f t

      let return t = t

      module Stream = struct
        type 'a t = 'a Seq.t

        let map t f = Seq.map f t

        let iter t f = Seq.iter f t

        let close _t = ()
      end
    end

    module Schema = Graphql_schema.Make (IO)
    module Graphql = Graphql_raw.Make (Schema)
    module Graphql_fields = Graphql.Fields
    module Graphql_args = Graphql.Args

    let deriver (type a b c d) () :
        < contramap : (a -> b) ref
        ; graphql_fields : c Graphql_fields.Input.T.t ref
        ; nullable_graphql_fields : d Graphql_fields.Input.T.t ref
        ; .. >
        as
        'row =
      (* We have to declare these outside of the object, otherwise the method
       * will create a new ref each time it is called. *)
      let open Graphql_fields in
      let graphql_fields =
        ref Input.T.{ run = (fun () -> failwith "unimplemented1") }
      in
      let graphql_arg = ref (fun () -> failwith "unimplemented2") in
      let contramap = ref (fun _ -> failwith "unimplemented3") in
      let map = ref (fun _ -> failwith "unimplemented4") in
      let nullable_graphql_fields =
        ref Input.T.{ run = (fun () -> failwith "unimplemented5") }
      in
      let nullable_graphql_arg = ref (fun () -> failwith "unimplemented6") in
      let graphql_fields_accumulator = ref [] in
      let graphql_arg_accumulator = ref Graphql_args.Acc.T.Init in
      let graphql_creator = ref (fun _ -> failwith "unimplemented7") in
      let graphql_query = ref None in
      let graphql_query_accumulator = ref [] in
      object
        method graphql_fields = graphql_fields

        method graphql_arg = graphql_arg

        method contramap = contramap

        method map = map

        method nullable_graphql_fields = nullable_graphql_fields

        method nullable_graphql_arg = nullable_graphql_arg

        method graphql_fields_accumulator = graphql_fields_accumulator

        method graphql_arg_accumulator = graphql_arg_accumulator

        method graphql_creator = graphql_creator

        method graphql_query = graphql_query

        method graphql_query_accumulator = graphql_query_accumulator
      end

    let o () = deriver ()

    let raw_server q c =
      let schema = Schema.(schema [ q ] ~mutations:[] ~subscriptions:[]) in
      let res = Schema.execute schema () c in
      match res with
      | Ok (`Response data) ->
          data |> Yojson.Basic.to_string
      | Error err ->
          failwithf "Unexpected error: %s" (Yojson.Basic.to_string err) ()
      | _ ->
          failwith "Unexpected response"

    let query_schema typ v =
      Schema.(
        field "query" ~typ:(non_null typ)
          ~args:Arg.[]
          ~doc:"sample query"
          ~resolve:(fun _ _ -> v))

    let query_for_all typ v str =
      raw_server (query_schema typ v) (Test.parse_query str)

    let hit_server q = raw_server q (Test.introspection_query ())

    let hit_server_query (typ : _ Schema.typ) v =
      hit_server (query_schema typ v)

    let hit_server_args (arg_typ : 'a Schema.Arg.arg_typ) =
      hit_server
        Schema.(
          field "args" ~typ:(non_null int)
            ~args:Arg.[ arg "input" ~typ:arg_typ ]
            ~doc:"sample args query"
            ~resolve:(fun _ _ _ -> 0))

    module T1 = struct
      type t = { foo_hello : int option; bar : string list } [@@deriving fields]

      let _v = { foo_hello = Some 1; bar = [ "baz1"; "baz2" ] }

      let manual_typ =
        Schema.(
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
        let ( !. ) x fd acc = add_field (x (o ())) fd acc in
        Fields.make_creator init
          ~foo_hello:!.(option @@ int @@ o ())
          ~bar:!.(list @@ string @@ o ())
        |> finish ~name:"T1" ?doc:None

      module Args = struct
        let manual_typ =
          Schema.Arg.(
            obj "T1_argInput" ?doc:None
              ~fields:
                [ arg "bar" ~typ:(non_null (list (non_null string)))
                ; arg "fooHello" ~typ:int
                ]
              ~coerce:(fun bar foo_hello -> { bar; foo_hello }))

        let derived init =
          let open Graphql_args in
          let ( !. ) x fd acc = add_field (x (o ())) fd acc in
          Fields.make_creator init
            ~foo_hello:!.(option @@ int @@ o ())
            ~bar:!.(list @@ string @@ o ())
          |> finish ~name:"T1_arg" ?doc:None
      end

      module Query = struct
        let derived init =
          let open Graphql_query in
          let ( !. ) x fd acc = add_field (x (o ())) fd acc in
          Fields.make_creator init
            ~foo_hello:!.(option @@ int @@ o ())
            ~bar:!.(list @@ string @@ o ())
          |> finish
      end
    end

    module Or_ignore_test = struct
      type 'a t = Check of 'a | Ignore

      let of_option = function None -> Ignore | Some x -> Check x

      let to_option = function Ignore -> None | Check x -> Some x

      let derived (x : ('input_type, 'b, 'c, _) Graphql_fields.Input.t) init :
          (_, _, 'c t, _) Graphql_fields.Input.t =
        let open Graphql_fields in
        let opt = option x (o ()) in
        contramap ~f:to_option opt init

      module Args = struct
        let derived (x : ('row1, 'c, 'input_type, _) Graphql_args.Input.t) init
            : ('row2, 'c t, 'input_type option, _) Graphql_args.Input.t =
          let open Graphql_args in
          let opt = option x (o ()) in
          map ~f:of_option opt init
      end

      module Query = struct
        let derived x init =
          let open Graphql_query in
          option x init
      end
    end

    module T2 = struct
      type t = { foo : T1.t Or_ignore_test.t } [@@deriving fields]

      let v1 =
        { foo = Check { T1.foo_hello = Some 1; bar = [ "baz1"; "baz2" ] } }

      let v2 = { foo = Ignore }

      let manual_typ =
        Schema.(
          obj "T2" ?doc:None ~fields:(fun _ ->
              [ field "foo"
                  ~args:Arg.[]
                  ~typ:T1.manual_typ
                  ~resolve:(fun _ t -> Or_ignore_test.to_option t.foo)
              ]))

      let derived init =
        let open Graphql_fields in
        let ( !. ) x fd acc = add_field (x (o ())) fd acc in
        Fields.make_creator init
          ~foo:!.(Or_ignore_test.derived @@ T1.derived @@ o ())
        |> finish ~name:"T2" ?doc:None

      module Args = struct
        let manual_typ =
          Schema.Arg.(
            obj "T2_argInput" ?doc:None
              ~fields:[ arg "foo" ~typ:T1.Args.manual_typ ] ~coerce:(fun foo ->
                Or_ignore_test.of_option foo))

        let derived init =
          let open Graphql_args in
          let ( !. ) x fd acc = add_field (x (o ())) fd acc in
          Fields.make_creator init
            ~foo:!.(Or_ignore_test.Args.derived @@ T1.Args.derived @@ o ())
          |> finish ~name:"T2_arg" ?doc:None
      end

      module Query = struct
        let manual =
          {|
            {
              foo {
                fooHello
                bar
              }
            }
          |}

        let derived init =
          let open Graphql_query in
          let ( !. ) x fd acc = add_field (x (o ())) fd acc in
          Fields.make_creator init
            ~foo:!.(Or_ignore_test.Query.derived @@ T1.Query.derived @@ o ())
          |> finish
      end
    end

    let%test_unit "T2 fold" =
      let open Graphql_fields in
      let generated_typ =
        let typ_input = T2.(option @@ derived @@ o ()) (o ()) in
        !(typ_input#graphql_fields).run ()
      in
      [%test_eq: string]
        (hit_server_query generated_typ T2.v1)
        (hit_server_query T2.manual_typ T2.v1) ;
      [%test_eq: string]
        (hit_server_query generated_typ T2.v2)
        (hit_server_query T2.manual_typ T2.v2)

    let%test_unit "T2 unfold" =
      let open Graphql_args in
      let generated_arg_typ =
        let obj = T2.(option @@ Args.derived @@ o ()) (o ()) in
        !(obj#graphql_arg) ()
      in
      [%test_eq: string]
        (hit_server_args generated_arg_typ)
        (hit_server_args T2.Args.manual_typ)

    let%test_unit "T2 query expected & parses" =
      let open Graphql_fields in
      let generated_typ =
        let typ_input = T2.(option @@ derived @@ o ()) (o ()) in
        !(typ_input#graphql_fields).run ()
      in
      let open Graphql_query in
      let generated_query =
        T2.Query.(option @@ derived @@ o ()) (o ())
        |> inner_query |> Option.value_exn
      in
      let prefix = "query TestQuery { query" in
      let suffix = "}" in
      [%test_eq: string]
        (query_for_all generated_typ T2.v1 (prefix ^ generated_query ^ suffix))
        (query_for_all generated_typ T2.v1 (prefix ^ T2.Query.manual ^ suffix))
  end )
