open Core_kernel
open Async_kernel

module type S = sig
  include Coda.Ledger_builder_controller_intf
end

module Make (Ledger_builder_hash : sig
  type t [@@deriving eq, bin_io]
end) (Ledger_hash : sig
  type t [@@deriving bin_io]
end) (Ledger_builder_transition : sig
  type t [@@deriving eq, sexp, compare, bin_io]
end) (Ledger : sig
  type t

  val merkle_root : t -> Ledger_hash.t
end) (Ledger_builder : sig
  type t [@@deriving bin_io]

  type proof

  val ledger : t -> Ledger.t

  val create : Ledger.t -> t

  val copy : t -> t

  val hash : t -> Ledger_builder_hash.t

  val apply :
       t
    -> Ledger_builder_transition.t
    -> (Ledger_hash.t * proof) option Deferred.Or_error.t
end) (State_hash : sig
  type t [@@deriving eq]
end) (State : sig
  type t [@@deriving eq, sexp, compare, bin_io]

  val ledger_builder_hash : t -> Ledger_builder_hash.t

  val hash : t -> State_hash.t

  val previous_state_hash : t -> State_hash.t
end) (Valid_transaction : sig
  type t [@@deriving eq, sexp, compare, bin_io]
end) (Net : sig
  include Coda.Ledger_builder_io_intf
          with type ledger_builder := Ledger_builder.t
           and type ledger_builder_hash := Ledger_builder_hash.t
           and type state := State.t
end) (Snark_pool : sig
  type t
end)
(Store : Storage.With_checksum_intf) :
  Coda.Ledger_builder_controller_intf
  with type ledger_builder := Ledger_builder.t
   and type ledger_builder_hash := Ledger_builder_hash.t
   and type ledger_builder_transition := Ledger_builder_transition.t
   and type ledger := Ledger.t
   and type transaction_with_valid_signature := Valid_transaction.t
   and type net := Net.net
   and type state := State.t
   and type snark_pool := Snark_pool.t =
struct
  module Config = struct
    type t =
      { keep_count: int [@default 50]
      ; parent_log: Logger.t
      ; net_deferred: Net.net Deferred.t
      ; ledger_builder_transitions:
          (Valid_transaction.t list * State.t * Ledger_builder_transition.t)
          Linear_pipe.Reader.t
      ; genesis_ledger: Ledger.t
      ; disk_location: string
      ; snark_pool: Snark_pool.t }
    [@@deriving make]
  end

  type t = Todo

  let create (config: Config.t) : t Deferred.t = failwith "Todo"

  let strongest_ledgers (t: t) :
      (Ledger_builder.t * State.t) Linear_pipe.Reader.t =
    failwith "Todo"

  (** Returns a reference to a ledger_builder denoted by [hash], materialize a
   fresh ledger at a specific hash if necessary *)
  let local_get_ledger (t: t) (hash: Ledger_builder_hash.t) :
      (Ledger_builder.t * State.t) Deferred.Or_error.t =
    failwith "Todo"
end
