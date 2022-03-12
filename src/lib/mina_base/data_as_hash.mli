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
