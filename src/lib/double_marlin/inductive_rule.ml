open Core_kernel
open Rugelach_types.Hlist

module B = struct type t = Impls.Pairing_based.Boolean.var end

type ('prev_vars, 'prev_values, 'widths, 'heights, 'a_var, 'a_value) t =
  { prevs:
      ('prev_vars, 'prev_values, 'widths, 'heights)
        H4.T(Tag).t
  ; main:
      ( 'prev_vars H1.T(Id).t
        -> 'a_var
        -> 'prev_vars H1.T(E01(B)).t )
  ; main_value:
      ( 'prev_values H1.T(Id).t
        -> 'a_value
        -> 'prev_vars H1.T(E01(Bool)).t )
  }

module T(Statement: T0)(Statement_value : T0) = struct
  type nonrec ('prev_vars, 'prev_values, 'widths, 'heights) t =
  ('prev_vars, 'prev_values, 'widths, 'heights, Statement.t, Statement_value.t) t
end

(*
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
*)
