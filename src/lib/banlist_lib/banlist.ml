open Core

module Offense = struct
  (* TODO: add more offenses. See https://github.com/o1-labs/nanobit/issues/852 *)
  type t = Send_bad_hash | Send_bad_aux | Failed_to_connect [@@deriving eq]
end

module type S = sig
  type t

  type peer

  type offense

  type record

  val create :
    suspicious_dir:string -> punished_dir:string -> ban_threshold:int -> t

  val record : t -> peer -> offense -> unit Or_error.t

  val ban : t -> peer -> record -> unit

  val unban : t -> peer -> unit

  val lookup :
    t -> peer -> [`Normal | `Punished of record | `Suspicious of Score.t]

  val close : t -> unit
end

module Make (Peer : sig
  include Hashable.S

  val sexp_of_t : t -> Sexp.t
end)
(Punishment_record : Punishment.Record.S with type score := Score.t)
(Suspicious_db : Key_value_database.S
                 with type key := Peer.t
                  and type value := Score.t)
(Punished_db : Key_value_database.S
               with type key := Peer.t
                and type value := Punishment_record.t) (Score_mechanism : sig
    val score : Offense.t -> Score.t
end) :
  S
  with type peer := Peer.t
   and type offense := Offense.t
   and type record := Punishment_record.t = struct
  type t =
    { suspicious: Suspicious_db.t
    ; punished: Punished_db.t
    ; ban_threshold: Score.t }

  let create ~suspicious_dir ~punished_dir ~ban_threshold =
    let suspicious = Suspicious_db.create ~directory:suspicious_dir in
    let punished = Punished_db.create ~directory:punished_dir in
    {suspicious; punished; ban_threshold= Score.of_int ban_threshold}

  let compute_punishment {ban_threshold; _} score =
    if Score.compare score ban_threshold < 0 then None
    else Some (Punishment_record.create_timeout score)

  let ban {punished; _} peer record =
    Punished_db.set punished ~key:peer ~data:record

  let unban {punished; _} peer = Punished_db.remove punished ~key:peer

  let lookup {suspicious; punished; _} peer =
    match Suspicious_db.get suspicious ~key:peer with
    | Some score -> `Suspicious score
    | None ->
        Option.map (Punished_db.get punished ~key:peer) ~f:(fun record ->
            `Punished record )
        |> Option.value ~default:`Normal

  let close {suspicious; punished; _} =
    Suspicious_db.close suspicious ;
    Punished_db.close punished

  let record ({suspicious; _} as t) peer offense =
    let write_penalty score offense =
      let new_score = Score.add score (Score_mechanism.score offense) in
      Or_error.return
        ( match compute_punishment t new_score with
        | None -> Suspicious_db.set suspicious ~key:peer ~data:new_score
        | Some record -> ban t peer record )
    in
    match lookup t peer with
    | `Suspicious score -> write_penalty score offense
    | `Punished _ ->
        Or_error.errorf
          !"Peer %{sexp:Peer.t} should not be able to make more offenses \
            since they are blacklisted"
          peer
    | `Normal -> write_penalty Score.zero offense
end

module Key_value_database = Key_value_database
module Punished_db = Punished_db
module Punishment = Punishment
module Score = Score

let%test_module "banlist" =
  ( module struct
    module Suspicious_db = Key_value_database.Make_mock (Int) (Score)

    module Mocked_punishment_record = struct
      type t = Int.t

      type time = Int.t

      let eviction_time _ = 0

      let create_timeout score = Score.to_int score
    end

    module Mocked_punished_db =
      Key_value_database.Make_mock (Int) (Mocked_punishment_record)

    let ban_threshold = 100

    module Score_mechanism = struct
      open Offense

      let score offense =
        Score.of_int
          ( match offense with
          | Failed_to_connect -> ban_threshold + 1
          | Send_bad_hash -> ban_threshold / 2
          | Send_bad_aux -> ban_threshold / 4 )
    end

    let compute_score offenses =
      List.fold offenses ~init:Score.zero ~f:(fun acc offense ->
          let score = Score_mechanism.score offense in
          Score.add acc score )

    module Make_test (Peer : sig
      include Hashable.S

      val sexp_of_t : t -> Sexp.t
    end)
    (Punishment_record : Punishment.Record.S with type score := Score.t)
    (Suspicious_db : Key_value_database.S
                     with type key := Peer.t
                      and type value := Score.t)
    (Punished_db : Key_value_database.S
                   with type key := Peer.t
                    and type value := Punishment_record.t)
                                                         (Score_mechanism : sig
        val score : Offense.t -> Score.t
    end) =
    struct
      include Make (Peer) (Punishment_record) (Suspicious_db) (Punished_db)
                (Score_mechanism)

      let create ~ban_threshold =
        create ~suspicious_dir:"" ~punished_dir:"" ~ban_threshold
    end

    module Mocked_banlist =
      Make_test (Int) (Mocked_punishment_record) (Suspicious_db)
        (Mocked_punished_db)
        (Score_mechanism)

    let peer = 1

    let%test "if no bans, then peer is normal" =
      let t = Mocked_banlist.create ~ban_threshold in
      match Mocked_banlist.lookup t peer with
      | `Normal -> true
      | `Suspicious _ -> false
      | `Punished _ -> false

    let%test "if a peer has offenses, and their combination do not exceed the \
              ban threshold, then the peer is considered to be suspicious" =
      let open Offense in
      let t = Mocked_banlist.create ~ban_threshold in
      let offenses = [Send_bad_hash; Send_bad_aux] in
      List.iter offenses ~f:(fun offense ->
          Mocked_banlist.record t peer offense |> Or_error.ok_exn ) ;
      match Mocked_banlist.lookup t peer with
      | `Suspicious score -> Score.compare score (compute_score offenses) = 0
      | `Normal -> false
      | `Punished _ -> false

    let%test "if a peer has offenses, and their combination does exceed the \
              ban threshold, then the peer is considered to be punished" =
      let t = Mocked_banlist.create ~ban_threshold in
      let offenses = [Offense.Failed_to_connect] in
      List.iter offenses ~f:(fun offense ->
          Mocked_banlist.record t peer offense |> Or_error.ok_exn ) ;
      match Mocked_banlist.lookup t peer with
      | `Punished _ -> true
      | _ -> false

    module Timeout = struct
      let duration = Time.Span.of_sec 5.0
    end

    module Timed_punishment_record = struct
      type time = Time.t

      include Punishment.Record.Make (Timeout)
    end

    module Timed_punished_db =
      Punished_db.Make (Int) (Time) (Timed_punishment_record)
        (Key_value_database.Make_mock (Int) (Timed_punishment_record))
    module Timed_banlist =
      Make_test (Int) (Timed_punishment_record) (Suspicious_db)
        (Timed_punished_db)
        (Score_mechanism)

    let%test "if a peer has offenses, and their combination does exceed the \
              ban threshold, then the peer is considered to be punished for \
              some time" =
      let open Async in
      Thread_safe.block_on_async_exn (fun () ->
          let t = Timed_banlist.create ~ban_threshold in
          let offenses = [Offense.Failed_to_connect] in
          List.iter offenses ~f:(fun offense ->
              Timed_banlist.record t peer offense |> Or_error.ok_exn ) ;
          assert (
            match Timed_banlist.lookup t peer with
            | `Punished _ -> true
            | _ -> false ) ;
          let%map () = after Timeout.duration in
          match Timed_banlist.lookup t peer with `Normal -> true | _ -> false
      )
  end )
