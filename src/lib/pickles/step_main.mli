(** [step_main] is the SNARK function corresponding to the input inductive rule. **)
val step_main :
  'proofs_verified 'self_branches 'prev_vars 'prev_values 'var 'value 'a_var
  'a_value 'ret_var 'ret_value 'auxiliary_var 'auxiliary_value
  'max_proofs_verified 'local_branches 'local_signature.
     (module Requests.Step.S
        with type auxiliary_value = 'auxiliary_value
         and type local_branches = 'local_branches
         and type local_signature = 'local_signature
         and type max_proofs_verified = 'max_proofs_verified
         and type prev_values = 'prev_values
         and type return_value = 'ret_value
         and type statement = 'a_value )
  -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
  -> self_branches:'self_branches Pickles_types.Nat.t
  -> local_signature:
       'local_signature Pickles_types.Hlist.H1.T(Pickles_types.Nat).t
  -> local_signature_length:
       ('local_signature, 'proofs_verified) Pickles_types.Hlist.Length.t
  -> local_branches:
       'local_branches Pickles_types.Hlist.H1.T(Pickles_types.Nat).t
  -> local_branches_length:
       ('local_branches, 'proofs_verified) Pickles_types.Hlist.Length.t
  -> proofs_verified:('prev_vars, 'proofs_verified) Pickles_types.Hlist.Length.t
  -> lte:('proofs_verified, 'max_proofs_verified) Pickles_types.Nat.Lte.t
  -> public_input:
       ( 'var
       , 'value
       , 'a_var
       , 'a_value
       , 'ret_var
       , 'ret_value )
       Inductive_rule.public_input
  -> auxiliary_typ:('auxiliary_var, 'auxiliary_value) Impls.Step.Typ.t
  -> basic:
       ( 'var
       , 'value
       , 'max_proofs_verified
       , 'self_branches )
       Types_map.Compiled.basic
  -> self:('var, 'value, 'max_proofs_verified, 'self_branches) Tag.t
  -> ( 'prev_vars
     , 'prev_values
     , 'local_signature
     , 'local_branches
     , 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'auxiliary_var
     , 'auxiliary_value )
     Inductive_rule.t
  -> (   unit
      -> ( (Unfinalized.t, 'max_proofs_verified) Pickles_types.Vector.t
         , Impls.Step.Field.t
         , (Impls.Step.Field.t, 'max_proofs_verified) Pickles_types.Vector.t )
         Import.Types.Step.Statement.t )
     Core_kernel.Staged.t
