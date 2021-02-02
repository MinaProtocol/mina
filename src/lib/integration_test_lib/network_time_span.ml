open Core_kernel

type t = Epochs of int | Slots of int | Literal of Time.Span.t | None

let to_span t ~(constants : Test_config.constants) =
  let open Int64 in
  let slots n =
    Time.Span.of_ms
      (to_float (n * of_int constants.constraints.block_window_duration_ms))
  in
  match t with
  | Epochs n ->
      Some
        (slots (of_int n * of_int constants.genesis.protocol.slots_per_epoch))
  | Slots n ->
      Some (slots (of_int n))
  | Literal span ->
      Some span
  | None ->
      None
