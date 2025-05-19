open Async
open Core

module PingMessage = struct
  type t = Ping [@@deriving yojson]
end

module PongMessage = struct
  type t = Pong [@@deriving yojson]
end

module Ponger = Actor.Make (PingMessage)
module Pinger = Actor.Make (PongMessage)

let test_case () =
  let emitted_numbers = Queue.create () in
  let logger = Logger.create () in
  let data_handler =
    ref (fun ~state:_ ~message:_ -> failwith "unimplemented")
  in
  let pinger =
    Pinger.create ~name:(`String "pinger")
      ~data_channel_type:(With_capacity (`Capacity 1, `Overflow Push_back))
      ~data_handler:(fun ~state ~message:Pong ->
        !data_handler ~state ~message:PongMessage.Pong )
      ~control_handler:(fun ~state ~message:() ->
        Deferred.return (Pinger.Next state) )
      ~logger ~state:10
  in
  let ponger =
    Ponger.create ~name:(`String "ponger")
      ~data_channel_type:(With_capacity (`Capacity 1, `Overflow Push_back))
      ~data_handler:(fun ~state ~message:Ping ->
        Queue.enqueue emitted_numbers state ;
        let%bind.Deferred () = Pinger.send_data ~actor:pinger ~message:Pong in
        Deferred.return (Ponger.Next (state - 1)) )
      ~control_handler:(fun ~state ~message:() ->
        Deferred.return (Ponger.Next state) )
      ~logger ~state:99
  in
  (data_handler :=
     fun ~state ~message:Pong ->
       Queue.enqueue emitted_numbers state ;
       if 0 = state - 1 then (
         Ponger.terminate ~actor:ponger ;
         Deferred.return Pinger.Exit )
       else
         let%bind.Deferred () = Ponger.send_data ~actor:ponger ~message:Ping in
         Deferred.return (Pinger.Next (state - 1)) ) ;
  let all_deferred () =
    Deferred.all
      [ Ponger.spawn ponger
      ; Pinger.spawn pinger
      ; (let%bind () = Pinger.send_data ~actor:pinger ~message:Pong in
         Deferred.Or_error.return () )
      ]
  in

  let _ = Async.Thread_safe.block_on_async all_deferred in

  Alcotest.(check (list int))
    "ping pong emitted number is expected"
    (Queue.to_list emitted_numbers)
    [ 10; 99; 9; 98; 8; 97; 7; 96; 6; 95; 5; 94; 4; 93; 3; 92; 2; 91; 1 ]
