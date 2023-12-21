open Snarky_backendless
open Webkit_trace_event
open Webkit_trace_event.Output.JSON
open Yojson

let to_string ?buf ?len ?std events =
  to_string ?buf ?len ?std @@ json_of_events events

let to_channel ?buf ?len ?std out_channel events =
  to_channel ?buf ?len ?std out_channel @@ json_of_events events

let to_file ?buf ?len ?std filename events =
  let oc = open_out filename in
  to_channel ?buf ?len ?std oc events ;
  close_out oc

module Constraints (Snarky_backendless : Snark_intf.Basic) = struct
  (** Create flamechart events for Snarky_backendless constraints.

    This creates a chart of labels, associating each label with a 'timestamp'
    equal to the number of constraints at its start and end. *)
  open Snarky_backendless

  (** Generate a flamechart for the labels of a checked computation. *)
  let log ?weight (t : unit -> _ Checked.t) : events =
    let rev_events = ref [] in
    let _total =
      constraint_count ?weight t ~log:(fun ?(start = false) label count ->
          rev_events :=
            create_event label
              ~phase:(if start then Measure_start else Measure_end)
              ~timestamp:count
            :: !rev_events )
    in
    List.rev !rev_events

  (** Same as [log], but for functions which take [Var.t] arguments.
    Use [apply_args] to apply the corresponding OCaml-typed arguments.
    For example: {[
open Snarky_backendless
module Snark = Snark.Make (Backends.Bn128.Default)
open Snark
module Constraints = Snarky_log.Constraints (Snark)

let () = Snarky_log.to_file "output.json" @@
  Constraints.log_func ~input:Data_spec.[Field.typ; Field.typ] Field.Checked.mul
    ~apply_args:(fun mul -> mul Field.one Field.one)
    }] *)
  let log_func ~input_typ ~return_typ ~(apply_args : 'k_value -> _ Checked.t)
      (f : 'k_var) : events =
    let f' = conv (fun c -> c) input_typ return_typ f in
    log (fun () -> apply_args f')
end
