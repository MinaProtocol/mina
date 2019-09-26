open Core_kernel
open Coda_base
open Signature_lib

module At_most_two : sig
  type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
  [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type 'a t [@@deriving sexp, to_yojson, bin_io, version]
      end
    end
    with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module At_most_one : sig
  type 'a t = Zero | One of 'a option [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type 'a t [@@deriving sexp, to_yojson, bin_io, version]
      end
    end
    with type 'a V1.t = 'a t

  val increase : 'a t -> 'a list -> 'a t Or_error.t
end

module Pre_diff_two : sig
  type ('a, 'b) t =
    { completed_works: 'a list
    ; user_commands: 'b list
    ; coinbase: Fee_transfer.Single.t At_most_two.t }
  [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type ('a, 'b) t [@@deriving sexp, to_yojson, bin_io, version]
      end
    end
    with type ('a, 'b) V1.t = ('a, 'b) t
end

module Pre_diff_one : sig
  type ('a, 'b) t =
    { completed_works: 'a list
    ; user_commands: 'b list
    ; coinbase: Fee_transfer.Single.t At_most_one.t }
  [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type ('a, 'b) t [@@deriving sexp, to_yojson, bin_io, version]
      end
    end
    with type ('a, 'b) V1.t = ('a, 'b) t
end

module Pre_diff_with_at_most_two_coinbase : sig
  type t = (Transaction_snark_work.t, User_command.t) Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, to_yojson, bin_io, version]
      end
    end
    with type V1.t = t
end

module Pre_diff_with_at_most_one_coinbase : sig
  type t = (Transaction_snark_work.t, User_command.t) Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, to_yojson, bin_io, version]
      end
    end
    with type V1.t = t
end

module Diff : sig
  type t =
    Pre_diff_with_at_most_two_coinbase.Stable.V1.t
    * Pre_diff_with_at_most_one_coinbase.Stable.V1.t option
  [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, to_yojson, version]
      end
    end
    with type V1.t = t
end

type t = {diff: Diff.t; creator: Public_key.Compressed.t}
[@@deriving sexp, to_yojson, fields]

module Stable :
  sig
    module V1 : sig
      type t = {diff: Diff.t; creator: Public_key.Compressed.t}
      [@@deriving sexp, to_yojson, bin_io, version]
    end

    module Latest = V1
  end
  with type V1.t = t

module With_valid_signatures_and_proofs : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.With_valid_signature.t )
    Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.With_valid_signature.t )
    Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, to_yojson]

  type t = {diff: diff; creator: Public_key.Compressed.t}
  [@@deriving sexp, to_yojson]

  val user_commands : t -> User_command.With_valid_signature.t list
end

module With_valid_signatures : sig
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.t
    , User_command.With_valid_signature.t )
    Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.t
    , User_command.With_valid_signature.t )
    Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, to_yojson]

  type t = {diff: diff; creator: Public_key.Compressed.t}
  [@@deriving sexp, to_yojson]
end

val forget_proof_checks :
  With_valid_signatures_and_proofs.t -> With_valid_signatures.t

val validate_user_commands :
     t
  -> check:(User_command.t -> User_command.With_valid_signature.t option)
  -> (With_valid_signatures.t, User_command.t) result

val forget : With_valid_signatures_and_proofs.t -> t

val user_commands : t -> User_command.t list

val completed_works : t -> Transaction_snark_work.t list

val coinbase : t -> Currency.Amount.t
