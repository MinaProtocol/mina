open Async
open Core
open Actor

module PingMessage = struct
  type t = Ping [@@deriving yojson]
end

module PongMessage = struct
  type t = Pong [@@deriving yojson]
end

module rec PingerLogic : sig
  type state =
    { count : int; partner : Ponger.instance Lazy.t; emitted : int Queue.t }

  type data_returns = unit Deferred.t

  type data_overflew = [ `Push_back ]

  type control_msg = unit

  val data_channel_type :
    (state, PongMessage.t, data_returns, data_overflew) channel_type

  val data_handler :
    state:state -> message:PongMessage.t -> state msg_processed Deferred.t

  val control_handler :
    state:state -> message:control_msg -> state msg_processed Deferred.t
end = struct
  type state =
    { count : int; partner : Ponger.instance Lazy.t; emitted : int Queue.t }

  type data_returns = unit Deferred.t

  type data_overflew = [ `Push_back ]

  type control_msg = unit

  let data_channel_type = With_capacity (`Capacity 1, `Overflow Push_back)

  let data_handler ~state ~message:PongMessage.Pong =
    Queue.enqueue state.emitted state.count ;
    if state.count - 1 = 0 then (
      Ponger.terminate ~instance:(Lazy.force state.partner) ;
      Deferred.return MExit )
    else
      let%map.Deferred () =
        Ponger.send_data ~instance:(Lazy.force state.partner)
          ~message:PingMessage.Ping
      in
      MNext { state with count = state.count - 1 }

  let control_handler ~state ~message:() = Deferred.return (MNext state)
end

and PongerLogic : sig
  type state =
    { count : int; partner : Pinger.instance Lazy.t; emitted : int Queue.t }

  type data_returns = unit Deferred.t

  type data_overflew = [ `Push_back ]

  type control_msg = unit

  val data_channel_type :
    (state, PingMessage.t, data_returns, data_overflew) channel_type

  val data_handler :
    state:state -> message:PingMessage.t -> state msg_processed Deferred.t

  val control_handler :
    state:state -> message:control_msg -> state msg_processed Deferred.t
end = struct
  type state =
    { count : int; partner : Pinger.instance Lazy.t; emitted : int Queue.t }

  type data_returns = unit Deferred.t

  type data_overflew = [ `Push_back ]

  type control_msg = unit

  let data_channel_type = With_capacity (`Capacity 1, `Overflow Push_back)

  let data_handler ~state ~message:PingMessage.Ping =
    Queue.enqueue state.emitted state.count ;
    let%map.Deferred () =
      Pinger.send_data ~instance:(Lazy.force state.partner)
        ~message:PongMessage.Pong
    in
    MNext { state with count = state.count - 1 }

  let control_handler ~state ~message:() = Deferred.return (MNext state)
end

and Pinger :
  (Actor.S
    with type state = PingerLogic.state
     and type message = PongMessage.t
     and type data_returns = unit Deferred.t) =
  Actor.Regular (PongMessage) (PingerLogic)

and Ponger :
  (Actor.S
    with type state = PongerLogic.state
     and type message = PingMessage.t
     and type data_returns = unit Deferred.t) =
  Actor.Regular (PingMessage) (PongerLogic)

let test_case () =
  let emitted_numbers = Queue.create () in
  let logger = Logger.create () in
  let rec pinger =
    lazy
      (Pinger.create
         ~state:{ count = 10; partner = ponger; emitted = emitted_numbers }
         ~logger ~name:(`String "pinger") )
  and ponger =
    lazy
      (Ponger.create
         ~state:{ count = 99; partner = pinger; emitted = emitted_numbers }
         ~logger ~name:(`String "ponger") )
  in
  let all_deferred () =
    Deferred.all
      [ Or_error.ok_exn (Ponger.spawn @@ Lazy.force ponger)
      ; Or_error.ok_exn (Pinger.spawn @@ Lazy.force pinger)
      ; Pinger.send_data ~instance:(Lazy.force pinger) ~message:PongMessage.Pong
      ]
  in
  let _ = Async.Thread_safe.block_on_async all_deferred in
  Alcotest.(check (list int))
    "ping pong emitted number is expected"
    (Queue.to_list emitted_numbers)
    [ 10; 99; 9; 98; 8; 97; 7; 96; 6; 95; 5; 94; 4; 93; 3; 92; 2; 91; 1 ]
