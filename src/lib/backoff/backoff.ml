open Core_kernel
open Async_kernel

module Strategy = struct
  type t =
    { base : Time_ns.Span.t
    ; max_delay : Time_ns.Span.t
    ; max_attempts : int option
    ; rng : Random.State.t
    }

  let create ~base ~max_delay ?max_attempts
      ?(random_state = Random.State.default) () =
    { base; max_delay; max_attempts; rng = Random.State.copy random_state }
end

module type Monad = sig
  type 'a t

  val return : 'a -> 'a t

  val bind : 'a t -> f:('a -> 'b t) -> 'b t

  val sleep : Time_ns.Span.t -> unit t
end

let full_jitter ~base ~max_delay ~attempt ~rng =
  let max_multiplier = Time_ns.Span.( // ) max_delay base in
  let multiplier = 2. ** Float.of_int attempt in
  let capped =
    if Float.( >= ) multiplier max_multiplier then max_delay
    else Time_ns.Span.scale base multiplier
  in
  Time_ns.Span.scale capped (Random.State.float rng 1.0)

let exhausted ~max_attempts ~attempts =
  match max_attempts with Some max -> attempts >= max - 1 | None -> false

module Make (M : Monad) = struct
  let retry ?(log_errors = false) (strategy : Strategy.t) ~logger ~f =
    let rng = strategy.rng in
    let attempts = ref 0 in
    let rec go () =
      M.bind (f ()) ~f:(function
        | Ok ok ->
            M.return (Ok ok)
        | Error e ->
            let attempt = !attempts in
            if exhausted ~max_attempts:strategy.max_attempts ~attempts:attempt
            then M.return (Error e)
            else (
              attempts := attempt + 1 ;
              let delay =
                full_jitter ~base:strategy.base ~max_delay:strategy.max_delay
                  ~attempt ~rng
              in
              if log_errors then
                [%log warn] "Backoff: attempt %d failed, retrying after %s"
                  attempt
                  (Time_ns.Span.to_string_hum delay)
                  ~metadata:[ ("error", Error_json.error_to_yojson e) ]
              else
                [%log debug] "Backoff: retrying after %s (attempt %d)"
                  (Time_ns.Span.to_string_hum delay)
                  attempt ;
              M.bind (M.sleep delay) ~f:(fun () ->
                  (* Trampoline via M.return () to keep the call stack
                     bounded. Without this, synchronous monads (e.g. the
                     Identity monad used in tests) would tail-recurse
                     inside the bind closure and overflow the stack.
                     For Deferred.t the bind already schedules
                     asynchronously, so this is a no-op. *)
                  M.bind (M.return ()) ~f:go ) ) )
    in
    go ()
end

module Deferred = Make (struct
  type 'a t = 'a Deferred.t

  let return = Deferred.return

  let bind = Deferred.bind

  let sleep span = after span
end)
