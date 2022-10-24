open Snark_params.Step

(** An in-circuit commitment to some data, without explicitly exposing this
    data within the circuit.

    For example, a [string t] might be used to 'talk about' a string into the
    circuit -- potentially as an argument to a recursively-verified proof --
    but if the string itself isn't useful in this circuit, its actual contents
    can be elided.

[{
    let%bind x = exists (Data_as_hash.typ ~hash:hash_foo) ~request:Foo in
    ...
    let x_hash = Data_as_hash.hash x in
    (* Use the hash representing x *) ...
    let%bind () =
      as_prover As_prover.(
        let%map x = As_prover.Ref.get (Data_as_hash.ref x) in
        printf "%s\n" (Foo.to_string x)
      )
    in
    ...
}]
*)
type 'value t

val hash : _ t -> Field.Var.t

val ref : 'value t -> 'value As_prover.Ref.t

val typ : hash:('value -> Field.t) -> ('value t, 'value) Typ.t

val optional_typ :
     hash:('value -> Field.t)
  -> non_preimage:Field.t
  -> dummy_value:'value
  -> ('value t, 'value option) Typ.t

val to_input : _ t -> Field.Var.t Random_oracle_input.Chunked.t

val if_ : Boolean.var -> then_:'value t -> else_:'value t -> 'value t

val make_unsafe : Field.Var.t -> 'value As_prover.Ref.t -> 'value t

module As_record : sig
  type 'a t = { data : 'a; hash : Field.t } [@@deriving annot, fields]
end

(*
  This type definition was created by hovering over the definition in data_as_hash.ml and copying the type.
  Would be nice to find a shorter way to declare it.
*)
val deriver :
     (   < contramap : ('a -> 'b) ref
         ; graphql_arg : (unit -> 'c) ref
         ; graphql_arg_accumulator :
             'd Fields_derivers_graphql.Graphql.Args.Acc.T.t ref
         ; graphql_creator : ('e -> 'f) ref
         ; graphql_fields :
             'g Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; graphql_fields_accumulator : 'h list ref
         ; graphql_query : 'i option ref
         ; graphql_query_accumulator : 'j list ref
         ; js_layout : [> `Assoc of 'k list ] ref
         ; js_layout_accumulator : 'l list ref
         ; map : ('m -> 'n) ref
         ; nullable_graphql_arg : (unit -> 'o) ref
         ; nullable_graphql_fields :
             'p Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; of_json : ('q -> 'r) ref
         ; of_json_creator :
             (string, 's, Base.String.comparator_witness) Base.Map.t ref
         ; skip : bool ref
         ; to_json : ('t -> 'u) ref
         ; to_json_accumulator : 'v list ref >
      -> < contramap : ('w -> 'x) ref
         ; graphql_arg :
             (unit -> 'y Fields_derivers_graphql.Schema.Arg.arg_typ) ref
         ; graphql_fields :
             'x Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; graphql_query : string option ref
         ; js_layout : Yojson.Safe.t ref
         ; map : ('y -> 'z) ref
         ; nullable_graphql_arg :
             (unit -> 'a1 Fields_derivers_graphql.Schema.Arg.arg_typ) ref
         ; nullable_graphql_fields :
             'b1 Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; of_json : (Yojson.Safe.t -> 'y) ref
         ; skip : bool ref
         ; to_json : ('x -> Yojson.Safe.t) ref
         ; .. > )
  -> (< contramap : ('w As_record.t -> 'w As_record.t) ref
      ; graphql_arg :
          (unit -> 'z As_record.t Fields_derivers_graphql.Schema.Arg.arg_typ)
          ref
      ; graphql_arg_accumulator :
          'z As_record.t Fields_derivers_graphql.Graphql.Args.Acc.T.t ref
      ; graphql_creator : ('c1 -> 'z As_record.t) ref
      ; graphql_fields :
          'w As_record.t Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
      ; graphql_fields_accumulator :
          'w As_record.t Fields_derivers_graphql.Graphql.Fields.Accumulator.T.t
          list
          ref
      ; graphql_query : string option ref
      ; graphql_query_accumulator : (string * string option) option list ref
      ; js_layout : [> `Assoc of (string * Yojson.Safe.t) list ] ref
      ; js_layout_accumulator :
          Fields_derivers_zkapps.Js_layout.Accumulator.field option list ref
      ; map : ('z As_record.t -> 'z As_record.t) ref
      ; nullable_graphql_arg :
          (unit -> 'd1 Fields_derivers_graphql.Schema.Arg.arg_typ) ref
      ; nullable_graphql_fields :
          'w As_record.t option Fields_derivers_graphql.Graphql.Fields.Input.T.t
          ref
      ; of_json :
          ([> `Assoc of (string * Yojson.Safe.t) list ] -> 'z As_record.t) ref
      ; of_json_creator : Yojson.Safe.t Core_kernel.String.Map.t ref
      ; skip : bool ref
      ; to_json :
          ('w As_record.t -> [> `Assoc of (string * Yojson.Safe.t) list ]) ref
      ; to_json_accumulator :
          (string * ('w As_record.t -> Yojson.Safe.t)) option list ref
      ; .. >
      as
      'c1 )
  -> 'c1
