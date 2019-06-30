open Snarky

module Make
    (M : Snark_intf.Run with type prover_state = unit)
    (Impl : Snark_intf.S with type field = M.field)
    (Inputs : Inputs_intf.S
              with type field := M.field
               and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t) : sig
  open Impl

  val hash :
       ?message:Boolean.var array
    -> a:M.Field.t * M.Field.t
    -> b:Inputs.Fqe.t * Inputs.Fqe.t
    -> c:M.Field.t * M.Field.t
    -> delta_prime:Inputs.Fqe.t * Inputs.Fqe.t
    -> (M.Field.t * M.Field.t, _) Checked.t
end
