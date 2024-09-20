open Core_kernel

type t = Epochs of int | Slots of int | Literal of Time.Span.t

let to_span t ~(genesis_constants : Genesis_constants.t) ~(constraint_constants : Genesis_constants.Constraint_constants.t)=
  let open Int64 in
  let slots n =
    Time.Span.of_ms
      (to_float
         (n * of_int constraint_constants.block_window_duration_ms) )
  in
  match t with
  | Epochs n ->
      slots
        (of_int n * of_int genesis_constants.protocol.slots_per_epoch)
  | Slots n ->
      slots (of_int n)
  | Literal span ->
      span

let to_string ~genesis_constants ~constraint_constants t =
  match t with
  | Epochs n ->
      Printf.sprintf "%d epochs == %s" n
        (Time.Span.to_string_hum (to_span ~genesis_constants ~constraint_constants t))
  | Slots n ->
      Printf.sprintf "%d slots == %s" n
        (Time.Span.to_string_hum (to_span ~genesis_constants ~constraint_constants t))
  | Literal t ->
      Time.Span.to_string_hum t
