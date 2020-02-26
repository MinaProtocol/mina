open Core_kernel
open Rugelach_types.Hlist

module B = struct type t = Impls.Pairing_based.Boolean.var end

type (_, _, _) t =
  | T : 
      ('prev_var, 'prev_value, < statement: 'a; statement_constant: 'a_const > as 'env) H2_1.T(E23(Tag)).t *
      ( ('prev_var, 'prev_value, 'env) H2_1.T(Fst).t
        -> 'a
        -> Impls.Pairing_based.Boolean.var
            * ('prev_var, 'prev_value, 'env)
              H2_1.T(E03(B)).t )
      *
      ( ('prev_var, 'prev_value, 'env) H2_1.T(Snd).t
        -> 'a_const
        -> bool
            * ('prev_var, 'prev_value, 'env)
              H2_1.T(E03(Bool)).t )
      -> ('prev_var, 'prev_value, 'env) t

