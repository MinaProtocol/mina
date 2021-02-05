open Core_kernel

type t = Epochs of int | Slots of int | Literal of Time.Span.t

let to_span t ~(constants : Test_config.constants) =
  let open Int64 in
  let slots n =
    Time.Span.of_ms
      (to_float (n * of_int constants.constraints.block_window_duration_ms))
  in
  match t with
  | Epochs n ->
      slots (of_int n * of_int constants.genesis.protocol.slots_per_epoch)
  | Slots n ->
      slots (of_int n)
  | Literal span ->
      span

let to_string ~constants t =
  match t with
  | Epochs n ->
      Printf.sprintf "%d epochs == %s" n
        (Time.Span.to_string_hum (to_span ~constants t))
  | Slots n ->
      Printf.sprintf "%d slots == %s" n
        (Time.Span.to_string_hum (to_span ~constants t))
  | Literal t ->
      Time.Span.to_string_hum t
