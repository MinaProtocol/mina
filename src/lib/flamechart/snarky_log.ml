open Snarky
open Flamechart_base

module Constraints (Snarky : Snark_intf.Basic) = struct
  (** Create flamechart events for Snarky constraints.
  
    This creates a chart of labels, associating each label with a 'timestamp'
    equal to the number of constraints at its start and end. *)
  open Snarky

  (** Generate a flamechart for the labels of a checked computation. *)
  let log (t : (_, _) Checked.t) : events =
    let rev_events = ref [] in
    let _total =
      constraint_count t ~log:(fun ?(start = false) label count ->
          rev_events :=
            create_event label
              ~phase:(if start then Begin else End)
              ~timestamp:count
            :: !rev_events )
    in
    List.rev !rev_events

  (** Same as [log], but for functions which take [Var.t] arguments.
    Use [apply_args] to apply the corresponding OCaml-typed arguments.
    For example: {[
log_func ~input:Field.typ Field.Checked.mul
  ~apply_args:(fun mul -> mul Field.one Field.one)
    }] *)
  let log_func ~(input : ('r_value, 'r_value, 'k_var, 'k_value) Data_spec.t)
      ~(apply_args : 'k_value -> (_, _) Checked.t) (f : 'k_var) : events =
    let f' = conv (fun c -> c) input f in
    log (apply_args f')
end
