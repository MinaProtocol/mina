open Core
open Import
open Snark_params.Tick

module Stable : sig
  module V2 : sig
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V1.t
      , Account.Stable.V2.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving bin_io, sexp, to_yojson, version]
  end

  module V1 : sig
    type t =
      ( Ledger_hash.Stable.V1.t
      , Public_key.Compressed.Stable.V1.t
      , Account.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving bin_io, sexp, to_yojson, version]

    val to_latest : t -> V2.t

    val of_latest : V2.t -> (t, string) Result.t
  end

  module Latest = V2
end

type t = Stable.Latest.t [@@deriving to_yojson, sexp]

val merkle_root : t -> Ledger_hash.t

val get_exn : t -> int -> Account.t

val path_exn :
  t -> int -> [`Left of Ledger_hash.t | `Right of Ledger_hash.t] list

val find_index_exn : t -> Account_id.t -> int

val of_root : Ledger_hash.t -> t

val apply_user_command_exn : t -> User_command.t -> t

val apply_transaction_exn : t -> Transaction.t -> t

val of_any_ledger : Ledger.Any_ledger.M.t -> t

val of_ledger_subset_exn : Ledger.t -> Account_id.t list -> t

val of_ledger_index_subset_exn : Ledger.Any_ledger.witness -> int list -> t

val iteri : t -> f:(Account.Index.t -> Account.t -> unit) -> unit

val handler : t -> Handler.t Staged.t
