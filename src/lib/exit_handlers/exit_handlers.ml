(* exit_handlers -- code to call at daemon exit *)

open Core_kernel

(* register a thunk to be called at exit; log registration and execution *)
let register_handler ~logger ~description (f : unit -> unit) =
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Registering exit handler: $description"
    ~metadata:[("description", `String description)] ;
  let logging_thunk () =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Running exit handler: $description"
      ~metadata:[("description", `String description)] ;
    (* if there's an exception, log it, allow other handlers to run *)
    try f ()
    with exn ->
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "When running exit handler: $description, got exception $exn"
        ~metadata:
          [ ("description", `String description)
          ; ("exn", `String (Exn.to_string exn)) ]
  in
  Stdlib.at_exit logging_thunk
