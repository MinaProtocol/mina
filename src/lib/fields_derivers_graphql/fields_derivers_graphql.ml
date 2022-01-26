open Core_kernel
open Fieldslib

module Graphql_args = struct
  module Input = struct
    open Graphql_async

    type 'input_type t = 'input_type Schema.Arg.arg_typ
  end

  module Creator = struct
    open Graphql_async

    type 'input_type t =  String.Map.t

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
     ((fun (E (args, coerce)) -> failwith "Unused")
     , ())

  let finish ((_creator, _x) : 'u * 'input_type Accumulator.t) :
      'input_type Output.t =
    failwith "TODO"
end

module Graphql_fields = struct
  module Input = struct
    open Graphql_async

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
    open Graphql_async

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
            Graphql_async.Schema.field (Field.name field)
              ~args:Graphql_async.Schema.Arg.[]
              ?doc:None ?deprecated:None ~typ:(t_field.run ())
              ~resolve:(fun _ x -> Field.get field x))
      }
      :: acc )

  (* TODO: Do we need doc and deprecated and name on finish? *)
  let finish ((_creator, schema_rev_thunk) : 'u * 'input_type Accumulator.t) :
      'input_type Output.t =
    { run =
        (fun ?doc () ->
          let open Graphql_async in
          Schema.obj "TODO" ?doc ~fields:(fun _ ->
              List.rev
              @@ List.map schema_rev_thunk ~f:(fun f ->
                     f.Accumulator.Elem.run ())))
    }

  module Prim = struct
    open Graphql_async

    let int field acc =
      add_field Input.{ run = (fun ?doc:_ () -> Schema.int) } field acc

    let nn_int field acc =
      add_field
        Input.{ run = (fun ?doc:_ () -> Schema.(non_null int)) }
        field acc

    let string field acc =
      add_field Input.{ run = (fun ?doc:_ () -> Schema.string) } field acc

    let nn_string field acc =
      add_field
        Input.{ run = (fun ?doc:_ () -> Schema.(non_null string)) }
        field acc
  end
end

(* Make sure that this is a deriver *)
module Graphql_fields_ : Fields_derivers.Deriver = Graphql_fields

let%test_module "Test" =
  ( module struct
    (*
    type t = { foo : int; bar : string } [@@deriving fields]

    let v = { foo = 1; bar = "baz" }
    let%test "folding creates a graphql object we expect" =
      let open Graphql_fields.Prim in
      let typ1 =
        Fields.make_creator (Graphql_fields.init ()) ~foo:nn_int ~bar:nn_string
        |> Graphql_fields.finish
      in
      let typ2 =
        Graphql_async.Schema.(
          obj "TODO" ?doc:None ~fields:(fun _ ->
              [ field "foo"
                  ~args:Arg.[]
                  ~typ:(non_null int)
                  ~resolve:(fun _ t -> t.foo)
              ; field "bar"
                  ~args:Arg.[]
                  ~typ:(non_null string)
                  ~resolve:(fun _ t -> t.bar)
              ]))
      in

      let hit_server typ =
        let schema =
          Graphql_async.Schema.(
            schema Queries.commands ~mutations:[]
              ~subscriptions:[])
        in
        let res =
          Async.Thread_safe.block_on_async_exn (fun () ->
              Graphql_async.Schema.execute Mina_graphql.schema fake_mina_lib
                introspection_query)
        in
        let response =
          match res with
          | Ok (`Response data) ->
            data
          | _ ->
            failwith "Unexpected response"
        in
      in
      *)
  
  end )
