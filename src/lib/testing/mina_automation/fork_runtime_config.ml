(** Runtime configs as a daemon announces them to its archive: only the fork
    stanza matters. *)

open Async

let to_json ?fork () =
  Runtime_config.make ~proof:(Runtime_config.Proof_keys.make ?fork ()) ()
  |> Runtime_config.to_yojson |> Yojson.Safe.to_string

(** A config naming the fork at [state_hash], [height] blocks after genesis
    and [slot] slots after it ([height] by default). *)
let naming ~state_hash ~height ?(slot = height) () =
  to_json
    ~fork:
      { state_hash
      ; blockchain_length = height
      ; global_slot_since_genesis = slot
      }
    ()

(** A config with no fork stanza: a network that has not forked. *)
let without_fork () = to_json ()

let save ~path json =
  let%map () = Writer.save path ~contents:json in
  path
