open Core

type host = Host_and_port.t [@@deriving sexp]

module type S = sig
  type t

  type peer

  val create : ban_threshold:int -> timeout:Time.Span.t -> t

  val record : t -> peer -> Offense.t -> unit Or_error.t

  val compute_score : Offense.t -> int

  val compute_punishment : t -> Offense.t list -> Punishment.t option

  val ban : t -> peer -> Punishment.t -> unit

  val unban : t -> peer -> unit

  val lookup :
       t
    -> peer
    -> [`Normal | `Punished of Punishment.t | `Suspicious of Offense.t list]

  val close : t -> unit
end

module Make (Peer : sig
  include Hashable.S

  val sexp_of_t : t -> Sexp.t
end)
(Suspicious : Key_value_database.S
              with type key := Peer.t
               and type value := Offense.t list)
(Punished : Key_value_database.S
            with type key := Peer.t
             and type value := Punishment.t) (Score : sig
    val score : Offense.t -> int
end) :
  S with type peer := Peer.t =
struct
  (* TODO: implement timeout feature *)
  type t =
    { suspicious: Suspicious.t
    ; punished: Punished.t
    ; ban_threshold: int
    ; timeout: Time.Span.t }

  let create ~ban_threshold ~timeout =
    let suspicious = Suspicious.create () in
    let punished = Punished.create () in
    {suspicious; punished; ban_threshold; timeout}

  let compute_score = Score.score

  (* TODO: Include Punishment.Forever logic *)
  let compute_punishment {ban_threshold; timeout; _} offenses =
    let score = List.sum (module Int) offenses ~f:compute_score in
    if score < ban_threshold then None
    else Some (Punishment.Timeout (Time.add (Time.now ()) timeout))

  let ban {punished; _} peer punishment =
    Punished.set punished ~key:peer ~data:punishment

  let unban {punished; _} peer = Punished.remove punished ~key:peer

  let lookup {suspicious; punished; _} peer =
    match Suspicious.get suspicious ~key:peer with
    | Some offenses -> `Suspicious offenses
    | None ->
        Option.map (Punished.get punished ~key:peer) ~f:(fun punishment ->
            `Punished punishment )
        |> Option.value ~default:`Normal

  let close {suspicious; punished; _} =
    Suspicious.close suspicious ;
    Punished.close punished

  let record ({suspicious; _} as t) peer offense =
    let write_penalty offenses =
      ( match compute_punishment t offenses with
      | None -> Suspicious.set suspicious ~key:peer ~data:offenses
      | Some punishment -> ban t peer punishment ) ;
      Or_error.return ()
    in
    match lookup t peer with
    | `Suspicious existing_offenses ->
        write_penalty (offense :: existing_offenses)
    | `Punished _ ->
        Or_error.errorf
          !"Peer %{sexp:Peer.t} should not be able to make more offenses \
            since they are blacklisted"
          peer
    | `Normal -> write_penalty [offense]
end

let%test_module "banlist" =
  ( module struct
    module Suspicious =
      Key_value_database.Make_mock (Host_and_port)
        (struct
          type t = Offense.t list
        end)

    module Punished = Key_value_database.Make_mock (Host_and_port) (Punishment)

    let ban_threshold = 100

    let timeout = Time.Span.of_sec 10.0

    module Score = struct
      open Offense

      let score = function
        | Failed_to_connect -> ban_threshold + 1
        | Send_bad_hash -> ban_threshold / 2
        | Send_bad_aux -> ban_threshold / 4
    end

    module Banlist = Make (Host_and_port) (Suspicious) (Punished) (Score)

    let host = Host_and_port.create ~host:"127.0.0.1" ~port:0

    let%test "if no bans, then peer_state is normal" =
      let t = Banlist.create ~ban_threshold ~timeout in
      match Banlist.lookup t host with
      | `Normal -> true
      | `Suspicious _ -> false
      | `Punished _ -> false

    let%test "if a host has offenses, and their combination do not exceed the \
              threshold, then the peer is considered to be normal" =
      let open Offense in
      let t = Banlist.create ~ban_threshold ~timeout in
      let offenses = [Send_bad_hash; Send_bad_aux] in
      List.iter offenses ~f:(fun offense ->
          Banlist.record t host offense |> Or_error.ok_exn ) ;
      match Banlist.lookup t host with
      | `Suspicious recorded_offenses ->
          [%eq : Offense.t list] (List.rev offenses) recorded_offenses
      | `Normal -> false
      | `Punished _ -> false

    let%test "if a host has offenses, and their combination do not exceed the \
              threshold, then the host is considered to be normal" =
      let open Offense in
      let t = Banlist.create ~ban_threshold ~timeout in
      let offenses = [Failed_to_connect] in
      List.iter offenses ~f:(fun offense ->
          Banlist.record t host offense |> Or_error.ok_exn ) ;
      match Banlist.lookup t host with
      | `Punished (Punishment.Timeout time) ->
          Time.Span.compare (Time.diff (Time.now ()) time) timeout < 0
      | _ -> false
  end )
