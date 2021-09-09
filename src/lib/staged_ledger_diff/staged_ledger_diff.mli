open Core_kernel
open Mina_base

module At_most_two : sig
  type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
  [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type 'a t [@@deriving sexp, yojson, bin_io, version]
      end
    end
    with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module At_most_one : sig
  type 'a t = Zero | One of 'a option [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type 'a t [@@deriving sexp, yojson, bin_io, version]
      end
    end
    with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module Pre_diff_two : sig
  type ('a, 'b) t =
    { completed_works: 'a list
    ; commands: 'b list
    ; coinbase: Coinbase.Fee_transfer.t At_most_two.t
    ; internal_command_balances:
        Transaction_status.Internal_command_balance_data.t list }
  [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type ('a, 'b) t [@@deriving sexp, yojson, bin_io, version]
      end
    end
    with type ('a, 'b) V1.t = ('a, 'b) t
end

module Pre_diff_one : sig
  type ('a, 'b) t =
    { completed_works: 'a list
    ; commands: 'b list
    ; coinbase: Coinbase.Fee_transfer.t At_most_one.t
    ; internal_command_balances:
        Transaction_status.Internal_command_balance_data.t list }
  [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type ('a, 'b) t [@@deriving sexp, yojson, bin_io, version]
      end
    end
    with type ('a, 'b) V1.t = ('a, 'b) t
end

module Pre_diff_with_at_most_two_coinbase : sig
  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_two.t
  [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, yojson, bin_io, version]
      end
    end
    with type V1.t = t
end

module Pre_diff_with_at_most_one_coinbase : sig
  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_one.t
  [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, yojson, bin_io, version]
      end
    end
    with type V1.t = t
end

module Diff : sig
  type t =
    Pre_diff_with_at_most_two_coinbase.t
    * Pre_diff_with_at_most_one_coinbase.t option
  [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, yojson, version]
      end
    end
    with type V1.t = t
end

type t = {diff: Diff.t} [@@deriving sexp, yojson, fields]

module Stable :
  sig
    module V1 : sig
      type t = {diff: Diff.t} [@@deriving sexp, yojson, bin_io, version]
    end

    module Latest = V1
  end
  with type V1.t = t

module With_valid_signatures_and_proofs : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, to_yojson]

  type t = {diff: diff} [@@deriving sexp, to_yojson]

  val commands : t -> User_command.Valid.t With_status.t list
end

module With_valid_signatures : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, to_yojson]

  type t = {diff: diff} [@@deriving sexp, to_yojson]

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
  -> check:(   User_command.t list
            -> (User_command.Valid.t list, 'e) Result.t
               Async.Deferred.Or_error.t)
  -> (With_valid_signatures.t, 'e) Result.t Async.Deferred.Or_error.t

val forget : With_valid_signatures_and_proofs.t -> t

val commands : t -> User_command.t With_status.t list

val completed_works : t -> Transaction_snark_work.t list

val coinbase :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> supercharge_coinbase:bool
  -> t
  -> Currency.Amount.t option
