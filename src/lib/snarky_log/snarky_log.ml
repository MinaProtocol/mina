open Snarky
open Webkit_trace_event
open Webkit_trace_event.Output.JSON
open Yojson

let to_string ?buf ?len ?std events =
  to_string ?buf ?len ?std @@ json_of_events events

let to_channel ?buf ?len ?std out_channel events =
  to_channel ?buf ?len ?std out_channel @@ json_of_events events

let to_file ?buf ?len ?std filename events =
  to_channel ?buf ?len ?std (open_out filename) events

(** Create flamechart events for Snarky constraints.

  This creates a chart of labels, associating each label with a 'timestamp'
  equal to the number of constraints at its start and end. *)

(** Generate a flamechart for the labels of a checked computation. *)
let log (t : (_, _, _) Checked.t) : events =
  let rev_events = ref [] in
  let _total =
    Checked.constraint_count t ~log:(fun ?(start = false) label count ->
        rev_events :=
          create_event label
            ~phase:(if start then Measure_start else Measure_end)
            ~timestamp:count
          :: !rev_events )
  in
  List.rev !rev_events

(** Same as [log], but for functions which take [Var.t] arguments.

  - [input] gives the data spec. for the snarky types
  - Use [apply_args] to apply the corresponding OCaml-typed arguments.
  - [conv] is the function from [Snark_intf.S] that converts the OCaml
    arguments according to the data spec. given by [input]
  For example:
{[
open Snarky
module Snark = Snark.Make (Backends.Bn128.Default)
open Snark

let () = Snarky_log.to_file "output.json" @@
  Snarky_log.log_func ~input:Data_spec.[Field.typ; Field.typ] Field.Checked.mul
    ~apply_args:(fun mul -> mul Field.one Field.one) ~conv
}]
*)
let log_func
    ~(input :
       ( 'r_value
       , 'r_value
       , 'k_var
       , 'k_value
       , 'field
       , (unit, unit, 'field) Types.Checked.t )
       Types.Data_spec.t) ~(apply_args : 'k_value -> (_, _, _) Checked.t) ~conv
    (f : 'k_var) : events =
  let f' = conv (fun c -> c) input f in
  log (apply_args f')
