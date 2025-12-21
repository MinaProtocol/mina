open Core_kernel
open Mina_base

module At_most_two : sig
  type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
  [@@deriving equal, compare, sexp, yojson]

  module Stable : sig
    module V1 : sig
      type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
      [@@deriving equal, compare, sexp, yojson, bin_io, version]
    end
  end
  with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module At_most_one : sig
  type 'a t = Zero | One of 'a option
  [@@deriving equal, compare, sexp, yojson]

  module Stable : sig
    module V1 : sig
      type 'a t = Zero | One of 'a option
      [@@deriving equal, compare, sexp, yojson, bin_io, version]
    end
  end
  with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module Pre_diff_two : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type ('a, 'b) t =
        { completed_works : 'a list
        ; commands : 'b list
        ; coinbase : Coinbase.Fee_transfer.Stable.V1.t At_most_two.Stable.V1.t
        ; internal_command_statuses : Transaction_status.Stable.V2.t list
        }
      [@@deriving equal, compare, sexp, yojson]
    end
  end]

  val map : ('a, 'b) t -> f1:('a -> 'c) -> f2:('b -> 'd) -> ('c, 'd) t
end

module Pre_diff_one : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type ('a, 'b) t =
        { completed_works : 'a list
        ; commands : 'b list
        ; coinbase : Coinbase.Fee_transfer.Stable.V1.t At_most_one.Stable.V1.t
        ; internal_command_statuses : Transaction_status.Stable.V2.t list
        }
      [@@deriving equal, compare, sexp, yojson]
    end
  end]

  val map : ('a, 'b) t -> f1:('a -> 'c) -> f2:('b -> 'd) -> ('c, 'd) t
end

module Pre_diff_with_at_most_two_coinbase : sig
  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_two.t

  module Stable : sig
    module V2 : sig
      type t =
        ( Transaction_snark_work.Stable.V2.t
        , User_command.Stable.V2.t With_status.Stable.V2.t )
        Pre_diff_two.Stable.V2.t
      [@@deriving equal, sexp, yojson]

      val to_latest : t -> t
    end

    module Latest = V2
  end

  module Serializable_type : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t =
          ( Transaction_snark_work.Serializable_type.Stable.V2.t
          , User_command.Serializable_type.Stable.V2.t With_status.Stable.V2.t
          )
          Pre_diff_two.Stable.V2.t
      end
    end]
  end
end

module Pre_diff_with_at_most_one_coinbase : sig
  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_one.t

  module Stable : sig
    module V2 : sig
      type t =
        ( Transaction_snark_work.Stable.V2.t
        , User_command.Stable.V2.t With_status.Stable.V2.t )
        Pre_diff_one.Stable.V2.t
      [@@deriving equal, sexp, yojson]

      val to_latest : t -> t
    end

    module Latest = V2
  end

  module Serializable_type : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t =
          ( Transaction_snark_work.Serializable_type.Stable.V2.t
          , User_command.Serializable_type.Stable.V2.t With_status.Stable.V2.t
          )
          Pre_diff_one.Stable.V2.t
      end
    end]
  end
end

module Diff : sig
  type t =
    Pre_diff_with_at_most_two_coinbase.t
    * Pre_diff_with_at_most_one_coinbase.t option

  module Stable : sig
    module V2 : sig
      type t =
        Pre_diff_with_at_most_two_coinbase.Stable.V2.t
        * Pre_diff_with_at_most_one_coinbase.Stable.V2.t option

      val coinbase :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> supercharge_coinbase:bool
        -> t
        -> Currency.Amount.t option

      val to_latest : t -> t
    end

    module Latest = V2
  end

  module Serializable_type : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t =
          Pre_diff_with_at_most_two_coinbase.Serializable_type.Stable.V2.t
          * Pre_diff_with_at_most_one_coinbase.Serializable_type.Stable.V2.t
            option
      end
    end]

    val coinbase :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> supercharge_coinbase:bool
      -> t
      -> Currency.Amount.t option
  end

  val coinbase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> supercharge_coinbase:bool
    -> t
    -> Currency.Amount.t option
end

type t = { diff : Diff.t } [@@deriving fields]

module Stable : sig
  module V2 : sig
    type t = { diff : Diff.Stable.V2.t }
    [@@deriving bin_io, equal, sexp, version, yojson]

    val to_latest : t -> t

    val empty_diff : t

    val completed_works : t -> Transaction_snark_work.Stable.Latest.t list
  end

  module Latest = V2
end

module Serializable_type : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t = { diff : Diff.Serializable_type.Stable.V2.t }
    end
  end]

  val empty_diff : t
end

val write_all_proofs_to_disk :
     signature_kind:Mina_signature_kind.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> Stable.Latest.t
  -> t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val to_serializable_type : t -> Serializable_type.t

module With_valid_signatures_and_proofs : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option

  type t = { diff : diff }

  val empty_diff : t

  val commands : t -> User_command.Valid.t With_status.t list
end

module With_valid_signatures : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option

  type t = { diff : diff }

  val coinbase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> supercharge_coinbase:bool
    -> t
    -> Currency.Amount.t option
end

val forget_proof_checks :
  With_valid_signatures_and_proofs.t -> With_valid_signatures.t

val validate_commands :
     t
  -> check:
       (   User_command.t With_status.t list
        -> (User_command.Valid.t list, 'e) Result.t Async.Deferred.Or_error.t )
  -> (With_valid_signatures.t, 'e) Result.t Async.Deferred.Or_error.t

val forget : With_valid_signatures_and_proofs.t -> t

val commands : t -> User_command.t With_status.t list

val completed_works : t -> Transaction_snark_work.t list

val net_return :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> supercharge_coinbase:bool
  -> t
  -> Currency.Amount.t option

val empty_diff : t

val is_empty : t -> bool
