type ( 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'auxiliary_var
     , 'auxiliary_value
     , 'max_proofs_verified
     , 'branches
     , 'prev_vars
     , 'prev_values
     , 'local_widths
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
             with type statement = 'a_value
              and type max_proofs_verified = 'max_proofs_verified
              and type prev_values = 'prev_values
              and type local_signature = 'local_widths
              and type local_branches = 'local_heights
              and type return_value = 'ret_value
              and type auxiliary_value = 'auxiliary_value )
      }
      -> ( 'a_var
         , 'a_value
         , 'ret_var
         , 'ret_value
         , 'auxiliary_var
         , 'auxiliary_value
         , 'max_proofs_verified
         , 'branches
         , 'prev_vars
         , 'prev_values
         , 'local_widths
         , 'local_heights )
         t

val create :
     index:int
  -> self:('var, 'value, 'max_proofs_verified, 'branches) Tag.t
  -> wrap_domains:Import.Domains.t
  -> step_uses_lookup:Pickles_types.Plonk_types.Opt.Flag.t
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
