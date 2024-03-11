open Pickles_types

(** The data obtained from "compiling" an inductive rule into a circuit. *)
type ( 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'auxiliary_var
     , 'auxiliary_value
     (* type level nat *)
     , 'max_proofs_verified
     , 'branches
     , 'prev_vars
     , 'prev_values
     (* type level nat *)
     , 'local_widths
     (* type level nat *)
     , 'local_heights )
     t =
  | T :
      { proofs_verified :
          'proofs_verified Pickles_types.Nat.t
          * ('prev_vars, 'proofs_verified) Pickles_types.Hlist.Length.t
      ; index : int
      ; lte : ('proofs_verified, 'max_proofs_verified) Pickles_types.Nat.Lte.t
      ; domains : Import.Domains.t
      ; rule :
          ( 'prev_vars
          , 'prev_values
          , 'local_widths
          , 'local_heights
          , 'a_var
          , 'a_value
          , 'ret_var
          , 'ret_value
          , 'auxiliary_var
          , 'auxiliary_value )
          Inductive_rule.t
            (* Main functions to compute *)
      ; main :
             step_domains:(Import.Domains.t, 'branches) Pickles_types.Vector.t
          -> unit
          -> ( (Unfinalized.t, 'max_proofs_verified) Pickles_types.Vector.t
             , Impls.Step.Field.t
             , (Impls.Step.Field.t, 'max_proofs_verified) Pickles_types.Vector.t
             )
             Import.Types.Step.Statement.t
      ; requests :
          (module Requests.Step.S
             with type auxiliary_value = 'auxiliary_value
              and type local_branches = 'local_heights
              and type local_signature = 'local_widths
              and type max_proofs_verified = 'max_proofs_verified
              and type prev_values = 'prev_values
              and type proofs_verified = 'proofs_verified
              and type return_value = 'ret_value
              and type statement = 'a_value )
      ; feature_flags : bool Plonk_types.Features.t
      }
      -> ( 'a_var
         , 'a_value
         , 'ret_var
         , 'ret_value
         , 'auxiliary_var
         , 'auxiliary_value
         (* type level nat *)
         , 'max_proofs_verified
         , 'branches
         , 'prev_vars
         , 'prev_values
         (* type level nat *)
         , 'local_widths
         (* type level nat *)
         , 'local_heights )
         t

(** Compile one rule into a value of type [t]
    [create idx self wrap_domains feature_flags actual_feature_flags
    max_proofs_verified branches public_input aux_typ var_to_field_elem
    val_to_field_elem rule]
*)
val create :
     index:int
  -> self:('var, 'value, 'max_proofs_verified, 'branches) Tag.t
  -> wrap_domains:Import.Domains.t
  -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
  -> actual_feature_flags:bool Plonk_types.Features.t
  -> max_proofs_verified:'max_proofs_verified Pickles_types.Nat.t
  -> proofs_verifieds:(int, 'branches) Pickles_types.Vector.t
  -> branches:'branches Pickles_types.Nat.t
  -> public_input:
       ( 'var
       , 'value
       , 'a_var
       , 'a_value
       , 'ret_var
       , 'ret_value )
       Inductive_rule.public_input
  -> auxiliary_typ:('a, 'b) Impls.Step.Typ.t
  -> 'c
  -> 'd
  -> ( 'e
     , 'f
     , 'g
     , 'h
     , 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'a
     , 'b )
     Inductive_rule.t
  -> ( 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'a
     , 'b
     , 'max_proofs_verified
     , 'branches
     , 'e
     , 'f
     , 'g
     , 'h )
     t
