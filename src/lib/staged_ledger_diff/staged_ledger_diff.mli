open Core_kernel
open Mina_base

module At_most_two : sig
  type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
  [@@deriving compare, sexp, yojson]

  module Stable : sig
    module V1 : sig
      type 'a t [@@deriving compare, sexp, yojson, bin_io, version]
    end
  end
  with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module At_most_one : sig
  type 'a t = Zero | One of 'a option [@@deriving compare, sexp, yojson]

  module Stable : sig
    module V1 : sig
      type 'a t [@@deriving compare, sexp, yojson, bin_io, version]
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
      [@@deriving compare, sexp, yojson]
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
      [@@deriving compare, sexp, yojson]
    end
  end]

  val map : ('a, 'b) t -> f1:('a -> 'c) -> f2:('b -> 'd) -> ('c, 'd) t
end

module Pre_diff_with_at_most_two_coinbase : sig
  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_two.t
  [@@deriving compare, sexp, yojson]

  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, sexp, yojson, bin_io, version]
    end
  end
  with type V2.t = t
end

module Pre_diff_with_at_most_one_coinbase : sig
  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_one.t
  [@@deriving compare, sexp, yojson]

  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, sexp, yojson, bin_io, version]
    end
  end
  with type V2.t = t
end

module Diff : sig
  type t =
    Pre_diff_with_at_most_two_coinbase.t
    * Pre_diff_with_at_most_one_coinbase.t option
  [@@deriving compare, sexp, yojson]

  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, sexp, bin_io, yojson, version]
    end
  end
  with type V2.t = t
end

type t = { diff : Diff.t } [@@deriving compare, sexp, compare, yojson, fields]

module Stable : sig
  module V2 : sig
    type t = { diff : Diff.Stable.V2.t }
    [@@deriving compare, sexp, compare, yojson, bin_io, version]

    val to_latest : t -> t
  end

  module Latest = V2
end
with type V2.t = t

module With_valid_signatures_and_proofs : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t
  [@@deriving compare, sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t
  [@@deriving compare, sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving compare, sexp, to_yojson]

  type t = { diff : diff } [@@deriving compare, sexp, to_yojson]

  val empty_diff : t

  val commands : t -> User_command.Valid.t With_status.t list
end

module With_valid_signatures : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t
  [@@deriving compare, sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t
  [@@deriving compare, sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving compare, sexp, to_yojson]

  type t = { diff : diff } [@@deriving compare, sexp, to_yojson]

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
       (   User_command.t list
        -> (User_command.Valid.t list, 'e) Result.t Async.Deferred.Or_error.t )
  -> (With_valid_signatures.t, 'e) Result.t Async.Deferred.Or_error.t

val forget : With_valid_signatures_and_proofs.t -> t

val commands : t -> User_command.t With_status.t list

val completed_works : t -> Transaction_snark_work.t list

val coinbase :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> supercharge_coinbase:bool
  -> t
  -> Currency.Amount.t option

val net_return :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> supercharge_coinbase:bool
  -> t
  -> Currency.Amount.t option

val empty_diff : t
