(* logger.ml : the fake one *)

open Core_kernel

let not_implemented () = failwith "Not implemented"

module Level = struct
  type t =
    | Internal
    | Spam
    | Trace
    | Debug
    | Info
    | Warn
    | Error
    | Faulty_peer
    | Fatal
  [@@deriving sexp, equal, compare, show { with_path = false }, enumerate]

  let of_string _ = not_implemented ()

  let to_yojson _ = not_implemented ()

  let of_yojson _ = not_implemented ()
end

(* Core modules extended with Yojson converters *)
module Time = struct
  include Time

  let to_yojson _ = not_implemented ()

  let of_yojson _ = not_implemented ()

  let pp _ _ = not_implemented ()

  let set_pretty_to_string _ = not_implemented ()

  let pretty_to_string _ = not_implemented ()
end

module Source = struct
  type t = { module_ : string [@key "module"]; location : string }
  [@@deriving yojson]

  let create ~module_:_ ~location:_ = not_implemented ()
end

module Metadata = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Yojson.Safe.t String.Map.t

      let to_latest = Fn.id

      let to_yojson _ = not_implemented ()

      let of_yojson _ = not_implemented ()

      include
        Binable.Of_binable_without_uuid
          (Core_kernel.String.Stable.V1)
          (struct
            type nonrec t = t

            let to_binable _ = not_implemented ()

            let of_binable _ = not_implemented ()
          end)
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  let empty = String.Map.empty
end

let append_to_global_metadata _ = not_implemented ()

module Message = struct
  type t =
    { timestamp : Time.t
    ; level : Level.t
    ; source : Source.t option [@default None]
    ; message : string
    ; metadata : Metadata.t
    ; event_id : Structured_log_events.id option [@default None]
    }
  [@@deriving yojson]
end

module Processor = struct
  module type S = sig
    type t

    val process : t -> Message.t -> string option
  end

  type t

  let create _ _ = not_implemented ()

  let raw ?log_level:_ () = not_implemented ()

  let raw_structured_log_events _ = not_implemented ()

  let pretty ~log_level:_ ~config:_ = not_implemented ()
end

module Transport = struct
  module type S = sig
    type t

    val transport : t -> string -> unit
  end

  type t

  let create _ _ = not_implemented ()

  let raw _ = not_implemented ()

  let stdout () = not_implemented ()
end

module Consumer_registry = struct
  type id = string

  let register ~id:_ ~processor:_ ~transport:_ = not_implemented ()
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { null : bool; metadata : Metadata.Stable.V1.t; id : string }

    let to_latest = Fn.id
  end
end]

let metadata t = t.metadata

let create ?metadata:_ ?(id = "default") () =
  { null = false; metadata = Metadata.empty; id }

let null () = { null = true; metadata = Metadata.empty; id = "default" }

let extend t _ = t

let change_id { null; metadata; id = _ } ~id = { null; metadata; id }

let raw _ _ = not_implemented ()

let log _t ~level:_ ~module_:_ ~location:_ ?metadata:_ ?event_id:_ fmt =
  let f _message = () in
  ksprintf f fmt

type 'a log_function =
     t
  -> module_:string
  -> location:string
  -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
  -> ?event_id:Structured_log_events.id
  -> ('a, unit, string, unit) format4
  -> 'a

let trace = log ~level:Level.Trace

let internal = log ~level:Level.Internal

let debug = log ~level:Level.Debug

let info = log ~level:Level.Info

let warn = log ~level:Level.Warn

let error = log ~level:Level.Error

let fatal = log ~level:Level.Fatal

let faulty_peer_without_punishment = log ~level:Level.Faulty_peer

let spam = log ~level:Level.Spam ~module_:"" ~location:"" ?event_id:None

(* deprecated, use Trust_system.record instead *)
let faulty_peer = faulty_peer_without_punishment

module Structured = struct
  type log_function =
       t
    -> module_:string
    -> location:string
    -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
    -> Structured_log_events.t
    -> unit

  let log _t ~level:_ ~module_:_ ~location:_ ?metadata:_ _event = ()

  let trace : log_function = log ~level:Level.Trace

  let debug = log ~level:Level.Debug

  let info = log ~level:Level.Info

  let warn = log ~level:Level.Warn

  let error = log ~level:Level.Error

  let fatal = log ~level:Level.Fatal

  let faulty_peer_without_punishment = log ~level:Level.Faulty_peer

  let best_tip_diff = log ~level:Level.Spam ~module_:"" ~location:""
end

module Str = Structured

module Logger_id = struct
  let invalid = "fake"

  let mina = invalid

  let best_tip_diff = invalid

  let rejected_blocks = invalid

  let snark_worker = invalid

  let oversized_logs = invalid
end
