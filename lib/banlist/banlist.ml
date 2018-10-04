open Core
open Unsigned

type host = Host_and_port.t [@@deriving sexp]

module Score = UInt32

module Punishment_record = struct
  type t = {score: Score.t; punishment: Punishment.t}

  let evict_time {punishment; _} = Punishment.evict_time punishment

  let create_timeout score = {score; punishment= Punishment.create_timeout ()}
end

module type S = sig
  type t

  type peer

  type offense

  type punishment

  val create : ban_threshold:int -> t

  val record : t -> peer -> offense -> unit Or_error.t

  val ban : t -> peer -> punishment -> unit

  val unban : t -> peer -> unit

  val lookup :
    t -> peer -> [`Normal | `Punished of punishment | `Suspicious of Score.t]

  val close : t -> unit
end

module Make (Peer : sig
  include Hashable.S

  val sexp_of_t : t -> Sexp.t
end)
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
   and type punishment := Punishment_record.t =
struct
  type t =
    {suspicious: Suspicious_db.t; 
    punished: Punished_db.t; 
    ban_threshold: Score.t}

  let create ~ban_threshold =
    let suspicious = Suspicious_db.create () in
    let punished = Punished_db.create () in
    {suspicious; punished; ban_threshold= Score.of_int ban_threshold}

  let compute_punishment {ban_threshold; _} score =
    if Score.compare score ban_threshold < 0 then None
    else Some (Punishment_record.create_timeout score)

  let ban {punished; _} peer punishment =
    Punished_db.set punished ~key:peer ~data:punishment

  let unban {punished; _} peer = Punished_db.remove punished ~key:peer

  let lookup {suspicious; punished; _} peer =
    match Suspicious_db.get suspicious ~key:peer with
    | Some score -> `Suspicious score
    | None ->
        Option.map (Punished_db.get punished ~key:peer) ~f:(fun punishment ->
            `Punished punishment )
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
        | Some punishment -> ban t peer punishment )
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

let%test_module "banlist" =
  ( module struct
    module Suspicious_db = Key_value_database.Make_mock (Int) (Score)
    module Punished_db =
      Key_value_database.Make_mock (Int) (Punishment_record)

    let ban_threshold = 100

    module Score_mechanism = struct
      open Offense

      let score offense =
        Score.of_int ( match offense with
        | Failed_to_connect -> ban_threshold + 1
        | Send_bad_hash -> ban_threshold / 2
        | Send_bad_aux -> ban_threshold / 4 )
    end

    let compute_score offenses =
      List.fold offenses ~init:Score.zero ~f:(fun acc offense ->
          let score = Score_mechanism.score offense in
          Score.add acc score )

    module Banlist = Make (Int) (Suspicious_db) (Punished_db) (Score_mechanism)

    let peer = 1

    let%test "if no bans, then peer is normal" =
      let t = Banlist.create ~ban_threshold in
      match Banlist.lookup t peer with
      | `Normal -> true
      | `Suspicious _ -> false
      | `Punished _ -> false

    let%test "if a host has offenses, and their combination do not exceed the ban \
              threshold, then the peer is considered to be suspicious" =
      let open Offense in
      let t = Banlist.create ~ban_threshold in
      let offenses = [Send_bad_hash; Send_bad_aux] in
      List.iter offenses ~f:(fun offense ->
          Banlist.record t peer offense |> Or_error.ok_exn ) ;
      match Banlist.lookup t peer with
      | `Suspicious score -> Score.compare score (compute_score offenses) = 0
      | `Normal -> false
      | `Punished _ -> false

    let%test "if a host has offenses, and their combination does exceed the ban \
              threshold, then the host is considered to be punished" =
      let open Offense in
      let t = Banlist.create ~ban_threshold in
      let offenses = [Failed_to_connect] in
      List.iter offenses ~f:(fun offense ->
          Banlist.record t peer offense |> Or_error.ok_exn ) ;
      match Banlist.lookup t peer with
      | `Punished {Punishment_record.punishment= Timeout _exiction_date; _} ->
          true
      | _ -> false
  end )
