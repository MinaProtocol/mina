open Async
open Core
open Actor_new

module PingMessage = struct
  type t = Ping [@@deriving yojson]
end

module PongMessage = struct
  type t = Pong [@@deriving yojson]
end

module NotUsedRequest = struct
  type _ t = Nothing : unit t
end

(* Pinger: receives Pong messages, sends Ping back, counts down *)
module rec PingerLogic : sig
  type state =
    { count : int
    ; partner : Ponger.instance Lazy.t
    ; emitted : int Queue.t
    }

  type _ key = Pong_chan : (PongMessage.t, unit Deferred.t) key

  val channels : (state, state key) chan_entry list
end = struct
  type state =
    { count : int
    ; partner : Ponger.instance Lazy.t
    ; emitted : int Queue.t
    }

  type _ key = Pong_chan : (PongMessage.t, unit Deferred.t) key

  let handler ~state ~message:PongMessage.Pong =
    Queue.enqueue state.emitted state.count ;
    if state.count - 1 = 0 then (
      Ponger.terminate ~instance:(Lazy.force state.partner) ;
      Deferred.return MExit )
    else
      let%map.Deferred () =
        Ponger.send
          ~instance:(Lazy.force state.partner)
          ~key:PongerLogic.Ping_chan
          ~message:PingMessage.Ping
      in
      MNext { state with count = state.count - 1 }

  let channels =
    [ MsgChan
        ( Pong_chan
        , { channel_type = With_capacity (`Capacity 1, `Overflow Push_back)
          ; handler
          ; to_yojson = Some PongMessage.to_yojson
          } )
    ]
end

and PongerLogic : sig
  type state =
    { count : int
    ; partner : Pinger.instance Lazy.t
    ; emitted : int Queue.t
    }

  type _ key = Ping_chan : (PingMessage.t, unit Deferred.t) key

  val channels : (state, state key) chan_entry list
end = struct
  type state =
    { count : int
    ; partner : Pinger.instance Lazy.t
    ; emitted : int Queue.t
    }

  type _ key = Ping_chan : (PingMessage.t, unit Deferred.t) key

  let handler ~state ~message:PingMessage.Ping =
    Queue.enqueue state.emitted state.count ;
    let%map.Deferred () =
      Pinger.send
        ~instance:(Lazy.force state.partner)
        ~key:PingerLogic.Pong_chan
        ~message:PongMessage.Pong
    in
    MNext { state with count = state.count - 1 }

  let channels =
    [ MsgChan
        ( Ping_chan
        , { channel_type = With_capacity (`Capacity 1, `Overflow Push_back)
          ; handler
          ; to_yojson = Some PingMessage.to_yojson
          } )
    ]
end

and Pinger : (module type of Make (NotUsedRequest) (PingerLogic)) =
  Make (NotUsedRequest) (PingerLogic)

and Ponger : (module type of Make (NotUsedRequest) (PongerLogic)) =
  Make (NotUsedRequest) (PongerLogic)

let test_case () =
  let emitted_numbers = Queue.create () in
  let logger = Logger.create () in

  let rec pinger_instance_v =
    lazy
      (Pinger.create
         ~state:
           { count = 10; partner = ponger_instance_v; emitted = emitted_numbers }
         ~logger
         ~name:(`String "pinger") )
  and ponger_instance_v =
    lazy
      (Ponger.create
         ~state:
           { count = 99; partner = pinger_instance_v; emitted = emitted_numbers }
         ~logger
         ~name:(`String "ponger") )
  in

  let all_deferred () =
    Deferred.all
      [ Pinger.spawn ~instance:(Lazy.force pinger_instance_v) |> Or_error.ok_exn
      ; Ponger.spawn ~instance:(Lazy.force ponger_instance_v) |> Or_error.ok_exn
      ; Pinger.send
          ~instance:(Lazy.force pinger_instance_v)
          ~key:PingerLogic.Pong_chan
          ~message:PongMessage.Pong
      ]
  in
  let _ = Async.Thread_safe.block_on_async_exn all_deferred in
  Alcotest.(check (list int))
    "ping pong emitted number is expected"
    (Queue.to_list emitted_numbers)
    [ 10; 99; 9; 98; 8; 97; 7; 96; 6; 95; 5; 94; 4; 93; 3; 92; 2; 91; 1 ]
