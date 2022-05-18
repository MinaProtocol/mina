open Snark_params.Tick

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
         ; js_layout : [> `String of string ] ref
         ; js_layout_accumulator : 'k list ref
         ; map : ('l -> 'm) ref
         ; nullable_graphql_arg : (unit -> 'n) ref
         ; nullable_graphql_fields :
             'o Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; of_json : ('p -> 'q) ref
         ; of_json_creator :
             (string, 'r, Base.String.comparator_witness) Base.Map.t ref
         ; skip : bool ref
         ; to_json : ('s -> 't) ref
         ; to_json_accumulator : 'u list ref >
      -> < contramap : ('v -> 'w) ref
         ; graphql_arg :
             (unit -> 'x Fields_derivers_graphql.Schema.Arg.arg_typ) ref
         ; graphql_fields :
             'w Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; graphql_query : string option ref
         ; js_layout : Yojson.Safe.t ref
         ; map : ('x -> 'y) ref
         ; nullable_graphql_arg :
             (unit -> 'z Fields_derivers_graphql.Schema.Arg.arg_typ) ref
         ; nullable_graphql_fields :
             'a1 Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
         ; of_json : (Yojson.Safe.t -> 'x) ref
         ; skip : bool ref
         ; to_json : ('w -> Yojson.Safe.t) ref
         ; .. > )
  -> (< contramap : ('v As_record.t -> 'v As_record.t) ref
      ; graphql_arg :
          (unit -> 'y As_record.t Fields_derivers_graphql.Schema.Arg.arg_typ)
          ref
      ; graphql_arg_accumulator :
          'y As_record.t Fields_derivers_graphql.Graphql.Args.Acc.T.t ref
      ; graphql_creator : ('b1 -> 'y As_record.t) ref
      ; graphql_fields :
          'v As_record.t Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
      ; graphql_fields_accumulator :
          'v As_record.t Fields_derivers_graphql.Graphql.Fields.Accumulator.T.t
          list
          ref
      ; graphql_query : string option ref
      ; graphql_query_accumulator : (string * string option) option list ref
      ; js_layout : [> `Assoc of (string * Yojson.Safe.t) list ] ref
      ; js_layout_accumulator :
          Fields_derivers_zkapps.Js_layout.Accumulator.field option list ref
      ; map : ('y As_record.t -> 'y As_record.t) ref
      ; nullable_graphql_arg :
          (unit -> 'c1 Fields_derivers_graphql.Schema.Arg.arg_typ) ref
      ; nullable_graphql_fields :
          'v As_record.t option Fields_derivers_graphql.Graphql.Fields.Input.T.t
          ref
      ; of_json :
          ([> `Assoc of (string * Yojson.Safe.t) list ] -> 'y As_record.t) ref
      ; of_json_creator : Yojson.Safe.t Core_kernel.String.Map.t ref
      ; skip : bool ref
      ; to_json :
          ('v As_record.t -> [> `Assoc of (string * Yojson.Safe.t) list ]) ref
      ; to_json_accumulator :
          (string * ('v As_record.t -> Yojson.Safe.t)) option list ref
      ; .. >
      as
      'b1 )
  -> 'b1
