module rec Typ : sig
  open Typ_monads

  type ('var, 'value, 'field, 'field_var, 'sys) t =
    { store: 'value -> ('var, 'field, 'field_var) Store.t
    ; read: 'var -> ('value, 'field, 'field_var) Read.t
    ; alloc: ('var, 'field_var) Alloc.t
    ; check: 'var -> (unit, unit, 'field, 'field_var, 'sys) Checked.t }
end =
  Typ

and Checked : sig
  (* TODO-someday: Consider having an "Assembly" type with only a store constructor for straight up Var.t's
    that this gets compiled into. *)

  type ('a, 's, 'f, 'v, 'sys) t =
    | Pure : 'a -> ('a, 's, 'f, 'v, 'sys) t
    | Add_constraint :
        'v Constraint.t * ('a, 's, 'f, 'v, 'sys) t
        -> ('a, 's, 'f, 'v, 'sys) t
    | With_constraint_system :
        ('sys -> unit) * ('a, 's, 'f, 'v, 'sys) t
        -> ('a, 's, 'f, 'v, 'sys) t
    | As_prover :
        (unit, 'v -> 'f, 's) As_prover0.t * ('a, 's, 'f, 'v, 'sys) t
        -> ('a, 's, 'f, 'v, 'sys) t
    | With_label :
        string * ('a, 's, 'f, 'v, 'sys) t * ('a -> ('b, 's, 'f, 'v, 'sys) t)
        -> ('b, 's, 'f, 'v, 'sys) t
    | With_state :
        ('s1, 'v -> 'f, 's) As_prover0.t
        * ('s1 -> (unit, 'v -> 'f, 's) As_prover0.t)
        * ('b, 's1, 'f, 'v, 'sys) t
        * ('b -> ('a, 's, 'f, 'v, 'sys) t)
        -> ('a, 's, 'f, 'v, 'sys) t
    | With_handler :
        Request.Handler.single
        * ('a, 's, 'f, 'v, 'sys) t
        * ('a -> ('b, 's, 'f, 'v, 'sys) t)
        -> ('b, 's, 'f, 'v, 'sys) t
    | Clear_handler :
        ('a, 's, 'f, 'v, 'sys) t * ('a -> ('b, 's, 'f, 'v, 'sys) t)
        -> ('b, 's, 'f, 'v, 'sys) t
    | Exists :
        ('var, 'value, 'f, 'v, 'sys) Typ.t
        * ('value, 'v -> 'f, 's) Provider.t
        * (('var, 'value) Handle.t -> ('a, 's, 'f, 'v, 'sys) t)
        -> ('a, 's, 'f, 'v, 'sys) t
    | Next_auxiliary :
        (int -> ('a, 's, 'f, 'v, 'sys) t)
        -> ('a, 's, 'f, 'v, 'sys) t
end =
  Checked
