open Core
open Async
open Pipe_lib

module Trust_response = struct
  type t = Insta_ban | Trust_increase of float | Trust_decrease of float
end

module type Action_intf = sig
  type t

  val to_trust_response : t -> Trust_response.t

  val to_log : t -> string * (string, Yojson.Safe.json) List.Assoc.t
end

let max_rate secs =
  let interval = 1. /. secs in
  (* The amount of trust that decays in `interval` seconds, when we're at the
     ban threshold (-1) *)
  1. -. (Record.decay_rate ** interval)

module Make0 (Peer_id : sig
  type t [@@deriving sexp, to_yojson]
end) (Now : sig
  val now : unit -> Time.t
end)
(Db : Key_value_database.S
      with type key := Peer_id.t
       and type value := Record.t)
(Action : Action_intf) =
struct
  type t =
    { db: Db.t option
          (* This is an option to allow using a fake trust system in tests. This is
       ugly, but the alternative is functoring half of Coda over the trust
       system. *)
    ; bans_reader: (Peer_id.t * Time.t) Strict_pipe.Reader.t
    ; bans_writer:
        ( Peer_id.t * Time.t
        , Strict_pipe.synchronous
        , unit Deferred.t )
        Strict_pipe.Writer.t
    ; mutable actions_writers: (Action.t * Peer_id.t) Pipe.Writer.t list }

  module Record_inst = Record.Make (Now)

  let create ~db_dir =
    let reader, writer = Strict_pipe.create Strict_pipe.Synchronous in
    { db= Some (Db.create ~directory:db_dir)
    ; bans_reader= reader
    ; bans_writer= writer
    ; actions_writers= [] }

  let null : unit -> t =
   fun () ->
    let bans_reader, bans_writer =
      Strict_pipe.create Strict_pipe.Synchronous
    in
    {db= None; bans_reader; bans_writer; actions_writers= []}

  let ban_pipe {bans_reader; _} = bans_reader

  let get_db {db; _} peer = Option.bind db ~f:(fun db' -> Db.get db' ~key:peer)

  let lookup t peer =
    match get_db t peer with
    | Some record ->
        Record_inst.to_peer_status record
    | None ->
        Record_inst.to_peer_status @@ Record_inst.init ()

  let peer_statuses {db; _} =
    Option.value_map db ~default:[] ~f:(fun db' ->
        Db.to_alist db'
        |> List.map ~f:(fun (peer, record) ->
               (peer, Record_inst.to_peer_status record) ) )

  let reset ({db; _} as t) peer =
    Option.value_map db ~default:() ~f:(fun db' -> Db.remove db' ~key:peer) ;
    lookup t peer

  let close {db; bans_writer; _} =
    Option.iter db ~f:Db.close ;
    Strict_pipe.Writer.close bans_writer

  let record ({db; bans_writer; _} as t) logger peer action =
    t.actions_writers
    <- List.filter t.actions_writers ~f:(Fn.compose not Pipe.is_closed) ;
    List.iter t.actions_writers
      ~f:(Fn.flip Pipe.write_without_pushback (action, peer)) ;
    let old_record =
      match get_db t peer with
      | None ->
          Record_inst.init ()
      | Some trust_record ->
          trust_record
    in
    let new_record =
      match Action.to_trust_response action with
      | Insta_ban ->
          Record_inst.ban old_record
      | Trust_increase incr ->
          [%test_pred: Float.t] Float.is_positive incr ;
          Record_inst.add_trust old_record incr
      | Trust_decrease incr ->
          [%test_pred: Float.t] Float.is_positive incr ;
          Record_inst.add_trust old_record (-.incr)
    in
    let simple_old = Record_inst.to_peer_status old_record in
    let simple_new = Record_inst.to_peer_status new_record in
    let action_fmt, action_metadata = Action.to_log action in
    let log_trust_change () =
      let verb =
        if simple_new.trust >. simple_old.trust then "Increasing"
        else "Decreasing"
      in
      Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:([("peer", Peer_id.to_yojson peer)] @ action_metadata)
        "%s trust for peer $peer due to action %s. New trust is %f." verb
        action_fmt simple_new.trust
    in
    let%map () =
      match (simple_old.banned, simple_new.banned) with
      | Unbanned, Banned_until expiration ->
          Logger.faulty_peer_without_punishment logger ~module_:__MODULE__
            ~location:__LOC__
            ~metadata:
              ( [ ("peer", Peer_id.to_yojson peer)
                ; ( "expiration"
                  , `String (Time.to_string_abs expiration ~zone:Time.Zone.utc)
                  ) ]
              @ action_metadata )
            "Banning peer $peer until $expiration because it %s" action_fmt ;
          if Option.is_some db then (
            Coda_metrics.Gauge.inc_one Coda_metrics.Trust_system.banned_peers ;
            Strict_pipe.Writer.write bans_writer (peer, expiration) )
          else Deferred.unit
      | Banned_until _, Unbanned ->
          Coda_metrics.Gauge.dec_one Coda_metrics.Trust_system.banned_peers ;
          log_trust_change () ;
          Deferred.unit
      | _, _ ->
          log_trust_change () ; Deferred.unit
    in
    Option.iter db ~f:(fun db' -> Db.set db' ~key:peer ~data:new_record)

  module For_tests = struct
    let get_action_pipe : t -> (Action.t * Peer_id.t) Pipe.Reader.t =
     fun t ->
      let reader, writer = Pipe.create () in
      t.actions_writers <- writer :: t.actions_writers ;
      reader
  end
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

    module Peer_id = struct
      type t = int [@@deriving sexp, yojson]
    end

    module Action = struct
      type t = Insta_ban | Slow_punish | Slow_credit | Big_credit
      [@@deriving compare, sexp, yojson]

      let to_trust_response t =
        match t with
        | Insta_ban ->
            Trust_response.Insta_ban
        | Slow_punish ->
            Trust_response.Trust_decrease (max_rate 1.)
        | Slow_credit ->
            Trust_response.Trust_increase (max_rate 1.)
        | Big_credit ->
            Trust_response.Trust_increase 0.2

      let to_log t = (string_of_sexp @@ sexp_of_t t, [])
    end

    module Peer_trust_test = Make0 (Peer_id) (Mock_now) (Db) (Action)

    (* We want to check the output of the pipe in these tests, but it's
       synchronous, so we need to read from it in a different "thread",
       otherwise it would hang. *)
    let ban_pipe_out = ref []

    let assert_ban_pipe expected =
      [%test_eq: int list] expected
        (List.map !ban_pipe_out ~f:(fun (peer, _banned_until) -> peer)) ;
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
      | {trust= 0.0; banned= Unbanned} ->
          assert_ban_pipe [] ; true
      | _ ->
          false

    let%test "Insta-bans actually do so" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%map () = Peer_trust_test.record db nolog 0 Insta_ban in
          match Peer_trust_test.lookup db 0 with
          | {trust= -1.0; banned= Banned_until time} ->
              [%test_eq: Time.t] time
              @@ Time.add !Mock_now.current_time Time.Span.day ;
              assert_ban_pipe [0] ;
              true
          | _ ->
              false )

    let%test "trust decays by half in 24 hours" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%map () = Peer_trust_test.record db nolog 0 Action.Big_credit in
          match Peer_trust_test.lookup db 0 with
          | {trust= start_trust; banned= Unbanned} -> (
              Mock_now.advance Time.Span.day ;
              assert_ban_pipe [] ;
              match Peer_trust_test.lookup db 0 with
              | {trust= decayed_trust; banned= Unbanned} ->
                  (* N.b. the floating point equality operator has a built in
                 tolerance i.e. it's approximate equality. *)
                  decayed_trust =. start_trust /. 2.0
              | _ ->
                  false )
          | _ ->
              false )

    let do_constant_rate rate f =
      (* Simulate running the function at the specified rate, in actions/sec,
         for a week. *)
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
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%map () = act_constant_rate db 1. Action.Slow_punish in
          match Peer_trust_test.lookup db 0 with
          | {banned= Banned_until _; _} ->
              false
          | {banned= Unbanned; _} ->
              assert_ban_pipe [] ; true )

    let%test "peers do get banned for acting faster than the maximum rate" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%map () = act_constant_rate db 1.1 Action.Slow_punish in
          match Peer_trust_test.lookup db 0 with
          | {banned= Banned_until _; _} ->
              assert_ban_pipe [0] ;
              true
          | {banned= Unbanned; _} ->
              false )

    let%test "good cancels bad" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%map () =
            do_constant_rate 1.1 (fun () ->
                let%bind () =
                  Peer_trust_test.record db nolog 0 Action.Slow_punish
                in
                Peer_trust_test.record db nolog 0 Action.Slow_credit )
          in
          match Peer_trust_test.lookup db 0 with
          | {banned= Banned_until _; _} ->
              false
          | {banned= Unbanned; _} ->
              assert_ban_pipe [] ; true )

    let%test "insta-bans ignore positive trust" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%bind () = act_constant_rate db 1. Action.Big_credit in
          ( match Peer_trust_test.lookup db 0 with
          | {trust; banned= Unbanned} ->
              assert (trust >. 0.99) ;
              assert_ban_pipe []
          | {banned= Banned_until _; _} ->
              failwith "Peer is banned after credits" ) ;
          let%map () = Peer_trust_test.record db nolog 0 Action.Insta_ban in
          match Peer_trust_test.lookup db 0 with
          | {trust= -1.0; banned= Banned_until _} ->
              assert_ban_pipe [0] ;
              true
          | {banned= Banned_until _; _} ->
              failwith "Trust not set to -1"
          | {banned= Unbanned; _} ->
              failwith "Peer not banned" )

    let%test "multiple peers getting banned causes multiple ban events" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let%bind () = Peer_trust_test.record db nolog 0 Action.Insta_ban in
          let%map () = Peer_trust_test.record db nolog 1 Action.Insta_ban in
          assert_ban_pipe [1; 0] (* Reverse order since it's a snoc list. *) ;
          true )

    let%test_unit "actions are written to the pipe" =
      Thread_safe.block_on_async_exn (fun () ->
          let db = setup_mock_db () in
          let pipe = Peer_trust_test.For_tests.get_action_pipe db in
          let%bind () = Peer_trust_test.record db nolog 0 Action.Insta_ban in
          let%bind () = Peer_trust_test.record db nolog 1 Action.Big_credit in
          let%bind () = Peer_trust_test.record db nolog 1 Action.Slow_credit in
          match%bind Pipe.read_exactly pipe ~num_values:3 with
          | `Exactly queue ->
              [%test_eq: (Action.t * int) list]
                Action.[(Insta_ban, 0); (Big_credit, 1); (Slow_credit, 1)]
                (Queue.to_list queue) ;
              Pipe.close_read pipe ;
              let%bind () =
                Peer_trust_test.record db nolog 2 Action.Insta_ban
              in
              assert (List.is_empty db.actions_writers) ;
              Deferred.unit
          | _ ->
              failwith "wrong number of actions written to pipe" )
  end )

module Make =
  Make0 (struct
      include Unix.Inet_addr.Blocking_sexp

      let to_yojson x = `String (Unix.Inet_addr.to_string x)
    end)
    (struct
      let now = Time.now
    end)
    (Rocksdb.Serializable.Make (Unix.Inet_addr.Blocking_sexp) (Record))
