(** The query and reply of [Announce_hardfork] (see {!Rpc.announce_hardfork}),
    and the archive's decision on an announcement.

    These types are versioned: an announcement crosses the fork, so a daemon of
    one era may talk to an archive of the other. *)

open Core_kernel
open Mina_base

(** Which side of the fork the sender is on.

    [Before_fork]: the sender is announcing the fork that ends its own era -- a
    daemon that generated the fork config at slot_chain_end, or an operator.
    [After_fork]: the sender is re-sending the fork that started its own era --
    the heartbeat of a daemon whose runtime config names the fork it came
    from. Every post-fork config names one, so this case is routine. *)
module Side = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Before_fork | After_fork [@@deriving sexp, compare, equal]

      let to_latest = Fn.id
    end
  end]
end

module Query = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fork_state_hash : State_hash.Stable.V1.t
        ; fork_blockchain_length : Mina_numbers.Length.Stable.V1.t
        ; fork_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        ; protocol_version : Protocol_version.Stable.V2.t
              (** The sender's own protocol version. *)
        ; side : Side.Stable.V1.t
        ; config_json : Mina_stdlib.Bounded_types.String.Stable.V1.t
              (** The runtime config naming the fork, verbatim. *)
        }
      [@@deriving sexp, compare, equal]

      let to_latest = Fn.id
    end
  end]
end

module Accepted = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Recorded  (** The fork is now on record; the hand-over starts. *)
        | Already_recorded  (** This fork was on record already. *)
        | Era_start
            (** The fork that started this archive's era: nothing to hand
                over, nothing recorded. *)
      [@@deriving sexp, compare, equal]

      let to_latest = Fn.id
    end
  end]
end

module Refusal = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Era_mismatch of
            { announced : Protocol_version.Stable.V2.t
            ; archive : Protocol_version.Stable.V2.t
            }  (** The announcement belongs to another era than this archive. *)
        | Different_fork of
            { announced : State_hash.Stable.V1.t
            ; recorded : State_hash.Stable.V1.t
            }
            (** A fork at another block is on record: two daemons disagree
                about where the chain forked. *)
        | Invalid_config of Mina_stdlib.Bounded_types.String.Stable.V1.t
            (** [config_json] is not a runtime config naming this fork. *)
        | Not_recorded of Mina_stdlib.Bounded_types.String.Stable.V1.t
            (** The write failed; the text is for the log. *)
      [@@deriving sexp, compare, equal]

      let to_latest = Fn.id
    end
  end]

  let to_string = function
    | Era_mismatch { announced; archive } ->
        sprintf "the announcement is of protocol version %s, this archive of %s"
          (Protocol_version.to_string announced)
          (Protocol_version.to_string archive)
    | Different_fork { announced; recorded } ->
        sprintf "this archive already records a fork at %s, not at %s"
          (State_hash.to_base58_check recorded)
          (State_hash.to_base58_check announced)
    | Invalid_config reason ->
        sprintf "unusable hard fork configuration: %s" reason
    | Not_recorded reason ->
        sprintf "could not record the hard fork: %s" reason
end

module Reply = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Accepted of Accepted.Stable.V1.t
        | Refused of Refusal.Stable.V1.t
      [@@deriving sexp, compare, equal]

      let to_latest = Fn.id
    end
  end]
end

(** The query for the fork named by a runtime config's [fork] stanza. *)
let query_of_config ~side ~protocol_version ~config_json =
  let open Result.Let_syntax in
  let%bind json =
    Result.try_with (fun () -> Yojson.Safe.from_string config_json)
    |> Result.map_error ~f:(fun e ->
           sprintf "configuration is not valid JSON: %s" (Exn.to_string e) )
  in
  let%bind runtime_config = Runtime_config.of_yojson json in
  let%bind { state_hash; blockchain_length; global_slot_since_genesis } =
    Result.of_option
      (Runtime_config.fork runtime_config)
      ~error:"configuration has no fork stanza"
  in
  let%map fork_state_hash =
    State_hash.of_base58_check state_hash
    |> Result.map_error ~f:Error.to_string_hum
  in
  { Query.fork_state_hash
  ; fork_blockchain_length = Mina_numbers.Length.of_int blockchain_length
  ; fork_global_slot =
      Mina_numbers.Global_slot_since_genesis.of_int global_slot_since_genesis
  ; protocol_version
  ; side
  ; config_json
  }

(** The era is the transaction and network version; patch releases share an
    era, as they share a chain. *)
let era_compare a b =
  [%compare: int * int]
    (Protocol_version.transaction a, Protocol_version.network a)
    (Protocol_version.transaction b, Protocol_version.network b)

(** What to do with an announcement, before looking at the database.

    [`Record]: the fork ends this archive's era -- record it and hand over.
    [`Era_start]: the fork started this archive's era; answer and do nothing.
    [`Refuse]: of another era. *)
let decide ~(archive : Protocol_version.t) (query : Query.t) =
  let era = era_compare query.protocol_version archive in
  let mismatch =
    `Refuse
      (Refusal.Era_mismatch { announced = query.protocol_version; archive })
  in
  match query.side with
  | Before_fork ->
      if era = 0 then `Record else mismatch
  | After_fork ->
      if era = 0 then `Era_start
      else if era > 0 then
        (* A post-fork daemon talking to a pre-fork archive: the archive missed
           the fork it is meant to hand over at, e.g. it was restored from a
           backup taken before. *)
        `Record
      else mismatch

let%test_module "announcement decisions" =
  ( module struct
    let v ~transaction ~network ~patch =
      Protocol_version.create ~transaction ~network ~patch

    let archive = v ~transaction:4 ~network:0 ~patch:0

    let query ~side protocol_version : Query.t =
      { fork_state_hash = State_hash.dummy
      ; fork_blockchain_length = Mina_numbers.Length.zero
      ; fork_global_slot = Mina_numbers.Global_slot_since_genesis.zero
      ; protocol_version
      ; side
      ; config_json = "{}"
      }

    let decision ~side version =
      match decide ~archive (query ~side version) with
      | `Record ->
          "record"
      | `Era_start ->
          "era start"
      | `Refuse (Refusal.Era_mismatch _) ->
          "era mismatch"
      | `Refuse _ ->
          "other refusal"

    let%test_unit "the fork ending this era is recorded" =
      [%test_eq: string] (decision ~side:Before_fork archive) "record"

    let%test_unit "a patch release is the same era" =
      [%test_eq: string]
        (decision ~side:Before_fork (v ~transaction:4 ~network:0 ~patch:1))
        "record"

    let%test_unit "a fork announced from another era is refused" =
      [%test_eq: string]
        (decision ~side:Before_fork (v ~transaction:3 ~network:0 ~patch:0))
        "era mismatch" ;
      [%test_eq: string]
        (decision ~side:Before_fork (v ~transaction:5 ~network:0 ~patch:0))
        "era mismatch"

    let%test_unit "the heartbeat of this era's own fork changes nothing" =
      [%test_eq: string] (decision ~side:After_fork archive) "era start"

    let%test_unit "a pre-fork archive that missed the fork records it" =
      [%test_eq: string]
        (decision ~side:After_fork (v ~transaction:5 ~network:0 ~patch:0))
        "record"

    let%test_unit "a heartbeat from an older era is refused" =
      [%test_eq: string]
        (decision ~side:After_fork (v ~transaction:3 ~network:0 ~patch:0))
        "era mismatch"
  end )
