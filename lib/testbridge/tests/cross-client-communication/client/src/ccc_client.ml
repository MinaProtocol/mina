open Core
open Async

let () = Random.self_init ()

let rand_name () =
  let rand_char () = Char.of_int_exn (Char.to_int 'a' + Random.int 26) in
  String.init 10 ~f:(fun _ -> rand_char ())

let value = ref (rand_name ())

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]

    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0 ~bin_query ~bin_response
  end

  module Fetch = struct
    type query = Host_and_port.Stable.V1.t [@@deriving bin_io]

    type response = String.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Fetch" ~version:0 ~bin_query ~bin_response
  end

  module Get = struct
    type query = unit [@@deriving bin_io]

    type response = String.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get" ~version:0 ~bin_query ~bin_response
  end

  module Set = struct
    type query = String.t [@@deriving bin_io]

    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Set" ~version:0 ~bin_query ~bin_response
  end
end

let fetch _ target =
  let%map res =
    Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port target)
      ~timeout:(Time.Span.of_sec 2.) (fun _ r w ->
        match%bind
          Rpc.Connection.create r w ~connection_state:(fun _ -> ())
        with
        | Error exn -> return (Or_error.of_exn exn)
        | Ok conn -> Rpc.Rpc.dispatch Rpcs.Get.rpc conn () )
  in
  match res with Ok msg -> msg | Error e -> Error.to_string_hum e

let set _ new_value =
  value := new_value ;
  Deferred.unit

let get _ () = return !value

let external_implementations =
  [ Rpc.Rpc.implement Rpcs.Fetch.rpc fetch
  ; Rpc.Rpc.implement Rpcs.Set.rpc set
  ; Rpc.Rpc.implement Rpcs.Ping.rpc (fun _ () -> return ()) ]

let internal_implementations = [Rpc.Rpc.implement Rpcs.Get.rpc get]

let external_implementations =
  Rpc.Implementations.create_exn ~implementations:external_implementations
    ~on_unknown_rpc:`Close_connection

let internal_implementations =
  Rpc.Implementations.create_exn ~implementations:internal_implementations
    ~on_unknown_rpc:`Close_connection

;; Tcp.Server.create
     ~on_handler_error:
       (`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
     (Tcp.Where_to_listen.of_port 8000)
     (fun address reader writer ->
       Rpc.Connection.server_with_close reader writer
         ~implementations:external_implementations
         ~connection_state:(fun _ -> ())
         ~on_handshake_error:`Ignore )

;; Tcp.Server.create
     ~on_handler_error:
       (`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
     (Tcp.Where_to_listen.of_port 8001)
     (fun address reader writer ->
       Rpc.Connection.server_with_close reader writer
         ~implementations:internal_implementations
         ~connection_state:(fun _ -> ())
         ~on_handshake_error:`Ignore )

let () = never_returns (Scheduler.go ())
