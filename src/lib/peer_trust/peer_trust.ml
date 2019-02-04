open Core
open Async
open Pipe_lib

module Trust_response = struct
  type t = Insta_ban | Trust_increase of float | Trust_decrease of float
end

module Banned_status = Banned_status
module Peer_status = Peer_status

module type Action_intf = sig
  type t [@@deriving sexp_of]

  val to_trust_response : t -> Trust_response.t
end

let max_rate secs =
  let interval = 1. /. secs in
  (* The amount of trust that decays in `interval` seconds, when we're at the
     ban threshold (-1) *)
  1. -. (Record.decay_rate ** interval)

module type S = sig
  type t

  type peer

  type action

  val create : db_dir:string -> t

  val ban_pipe : t -> peer Strict_pipe.Reader.t

  val record : t -> Logger.t -> peer -> action -> unit Deferred.t

  val lookup : t -> peer -> Peer_status.t

  val close : t -> unit
end

module Make (Peer : sig
  include Hashable.S

  val sexp_of_t : t -> Sexp.t
end) (Now : sig
  val now : unit -> Time.t
end)
(Action : Action_intf)
(Db : Key_value_database.S with type key := Peer.t and type value := Record.t) =
struct
  type t =
    { db: Db.t
    ; bans_reader: Peer.t Strict_pipe.Reader.t
    ; bans_writer:
        (Peer.t, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t
    }

  module Record_inst = Record.Make (Now)

  let create ~db_dir =
    let reader, writer = Strict_pipe.create Strict_pipe.Synchronous in
    {db= Db.create ~directory:db_dir; bans_reader= reader; bans_writer= writer}

  let ban_pipe {bans_reader} = bans_reader

  let lookup {db} peer =
    match Db.get db peer with
    | Some record -> Record_inst.to_simple record
    | None -> Record_inst.to_simple @@ Record_inst.init ()

  let close {db; bans_writer} =
    Db.close db ;
    Strict_pipe.Writer.close bans_writer

  let record {db; bans_writer} log peer action =
    let log' = Logger.child log "peer_trust" in
    let old_record =
      match Db.get db peer with
      | None -> Record_inst.init ()
      | Some trust_record -> trust_record
    in
    let new_record =
      match Action.to_trust_response action with
      | Insta_ban -> Record_inst.ban old_record
      (* I don't like runtime exceptions, but the trust change constructors
         should only be called with constant arguments, so I think any bugs
         that trigger this will be very visible in testing. *)
      | Trust_increase incr ->
          [%test_pred: Float.t] Float.is_positive incr ;
          Record_inst.add_trust old_record incr
      | Trust_decrease incr ->
          [%test_pred: Float.t] Float.is_positive incr ;
          Record_inst.add_trust old_record (-.incr)
    in
    let simple_old = Record_inst.to_simple old_record in
    let simple_new = Record_inst.to_simple new_record in
    let%map () =
      match (simple_old.banned, simple_new.banned) with
      | Unbanned, Banned_until expiration ->
          Logger.faulty_peer log'
            !"Banning peer %{sexp:Peer.t} until %{sexp:Time.t} due to action \
              %{sexp:Action.t}."
            peer expiration action ;
          Strict_pipe.Writer.write bans_writer peer
      | _, _ ->
          let verb =
            if simple_new.trust >. simple_old.trust then "Increasing"
            else "Decreasing"
          in
          Logger.debug log'
            !"%s trust for peer %{sexp:Peer.t} due to action \
              %{sexp:Action.t}. New trust is %f."
            verb peer action simple_new.trust ;
          Deferred.unit
    in
    Db.set db ~key:peer ~data:new_record
end

let%test_module "peer_trust" =
  ( module struct
    (* Mock the current time *)
    module Mock_now = struct
      let current_time = ref Time.epoch

      let now () = !current_time

      let advance span = current_time := Time.add !current_time span
    end

    module Mock_record = Record.Make (Mock_now)
    module Db = Key_value_database.Make_mock (Int) (Record)

    module Action = struct
      type t = Insta_ban | Slow_punish | Slow_credit | Big_credit
      [@@deriving sexp]

      let to_trust_response t =
        match t with
        | Insta_ban -> Trust_response.Insta_ban
        | Slow_punish -> Trust_response.Trust_decrease (max_rate 1.)
        | Slow_credit -> Trust_response.Trust_increase (max_rate 1.)
        | Big_credit -> Trust_response.Trust_increase 0.2
    end

    module Peer_trust_test = Make (Int) (Mock_now) (Action) (Db)

    (* We want to check the output of the pipe in these tests, but it's
       synchronous, so we need to read from it in a different "thread",
       otherwise it would hang. *)
    let ban_pipe_out = ref []

    let assert_ban_pipe expected =
      [%test_eq: int list] expected !ban_pipe_out ;
      ban_pipe_out := []

    let setup_mock_db () =
      let res = Peer_trust_test.create ~db_dir:"fake" in
      don't_wait_for
      @@ Strict_pipe.Reader.iter_without_pushback res.bans_reader ~f:(fun v ->
             ban_pipe_out := v :: !ban_pipe_out ) ;
      res

    let nolog = Logger.null ()

    let%test "Peers are unbanned and have 0 trust at initialization" =
      let db = setup_mock_db () in
      match Peer_trust_test.lookup db 0 with
      | {trust= 0.0; banned= Unbanned} -> assert_ban_pipe [] ; true
      | _ -> false

    let%test "Insta-bans actually do so" =
      let db = setup_mock_db () in
      Thread_safe.block_on_async_exn (fun () ->
          Peer_trust_test.record db nolog 0 Insta_ban ) ;
      match Peer_trust_test.lookup db 0 with
      | {trust= -1.0; banned= Banned_until time} ->
          [%test_eq: Time.t] time
          @@ Time.add !Mock_now.current_time Time.Span.day ;
          assert_ban_pipe [0] ;
          true
      | _ -> false

    let%test "trust decays by half in 24 hours" =
      let db = setup_mock_db () in
      Thread_safe.block_on_async_exn (fun () ->
          Peer_trust_test.record db nolog 0 Action.Big_credit ) ;
      match Peer_trust_test.lookup db 0 with
      | {trust= start_trust; banned= Unbanned} -> (
          Mock_now.advance Time.Span.day ;
          assert_ban_pipe [] ;
          match Peer_trust_test.lookup db 0 with
          | {trust= decayed_trust; banned= Unbanned} ->
              decayed_trust =. start_trust /. 2.0
          | _ -> false )
      | _ -> false

    let do_constant_rate rate f =
      (* simulate running the function at the specified rate for a week *)
      let instances = Float.to_int @@ (60. *. 60. *. 24. *. 7. *. rate) in
      let rec go n =
        if n < instances then (
          let%bind () = f () in
          Mock_now.advance Time.Span.(second / rate) ;
          go (n + 1) )
        else Deferred.unit
      in
      go 0

    let act_constant_rate db rate act =
      (* simulate performing an action at the specified rate for a week *)
      do_constant_rate rate (fun () -> Peer_trust_test.record db nolog 0 act)

    let%test "peers don't get banned for acting at the maximum rate" =
      let db = setup_mock_db () in
      Thread_safe.block_on_async_exn (fun () ->
          act_constant_rate db 1. Action.Slow_punish ) ;
      match Peer_trust_test.lookup db 0 with
      | {banned= Banned_until _} -> false
      | {banned= Unbanned} -> assert_ban_pipe [] ; true

    let%test "peers do get banned for acting faster than the maximum rate" =
      let db = setup_mock_db () in
      Thread_safe.block_on_async_exn (fun () ->
          act_constant_rate db 1.1 Action.Slow_punish ) ;
      match Peer_trust_test.lookup db 0 with
      | {trust; banned= Banned_until _} ->
          assert_ban_pipe [0] ;
          true
      | {trust; banned= Unbanned} -> false

    let%test "good cancels bad" =
      let db = setup_mock_db () in
      Thread_safe.block_on_async_exn (fun () ->
          do_constant_rate 1.1 (fun () ->
              let%bind () =
                Peer_trust_test.record db nolog 0 Action.Slow_punish
              in
              Peer_trust_test.record db nolog 0 Action.Slow_credit ) ) ;
      match Peer_trust_test.lookup db 0 with
      | {trust; banned= Banned_until _} -> false
      | {trust; banned= Unbanned} -> assert_ban_pipe [] ; true

    let%test "insta-bans ignore positive trust" =
      let db = setup_mock_db () in
      Thread_safe.block_on_async_exn (fun () ->
          act_constant_rate db 1. Action.Big_credit ) ;
      ( match Peer_trust_test.lookup db 0 with
      | {trust; banned= Unbanned} ->
          assert (trust >. 0.99) ;
          assert_ban_pipe []
      | {trust; banned= Banned_until _} ->
          failwith "Peer is banned after credits" ) ;
      Thread_safe.block_on_async_exn (fun () ->
          Peer_trust_test.record db nolog 0 Action.Insta_ban ) ;
      match Peer_trust_test.lookup db 0 with
      | {trust= -1.0; banned= Banned_until _} ->
          assert_ban_pipe [0] ;
          true
      | {trust; banned= Banned_until _} -> failwith "Trust not set to -1"
      | {trust; banned= Unbanned} -> failwith "Peer not banned"
  end )
