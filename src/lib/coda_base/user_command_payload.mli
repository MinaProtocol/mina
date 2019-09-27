open Core_kernel
open Signature_lib
open Tuple_lib
open Fold_lib
open Snark_params.Tick

module Body : sig
  type t =
    | Payment of Payment_payload.Stable.V1.t
    | Stake_delegation of Stake_delegation.Stable.V1.t
  [@@deriving eq, sexp, hash, yojson]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, eq, sexp, hash, yojson]
    end

    module Latest = V1
  end
end

module Common : sig
  module Poly : sig
    type ('fee, 'nonce, 'memo) t = {fee: 'fee; nonce: 'nonce; memo: 'memo}
    [@@deriving eq, sexp, hash, yojson]

    module Stable :
      sig
        module V1 : sig
          type ('fee, 'nonce, 'memo) t
          [@@deriving bin_io, eq, sexp, hash, yojson, version]
        end

        module Latest = V1
      end
      with type ('fee, 'nonce, 'memo) V1.t = ('fee, 'nonce, 'memo) t
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Currency.Fee.Stable.V1.t
        , Coda_numbers.Account_nonce.Stable.V1.t
        , User_command_memo.t )
        Poly.Stable.V1.t
      [@@deriving bin_io, eq, sexp, hash]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving eq, sexp, hash]

  val gen : t Quickcheck.Generator.t

  type var =
    ( Currency.Fee.var
    , Coda_numbers.Account_nonce.Checked.t
    , User_command_memo.Checked.t )
    Poly.t

  val typ : (var, t) Typ.t

  val to_input : t -> (Field.t, bool) Random_oracle.Input.t

  val fold : t -> bool Triple.t Fold.t

  module Checked : sig
    val to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

    val to_input :
      var -> ((Field.Var.t, Boolean.var) Random_oracle.Input.t, _) Checked.t

    val constant : t -> var
  end
end

module Poly : sig
  type ('common, 'body) t = {common: 'common; body: 'body}
  [@@deriving eq, sexp, hash, yojson, compare]

  module Stable :
    sig
      module V1 : sig
        type ('common, 'body) t
        [@@deriving bin_io, eq, sexp, hash, yojson, compare, version]
      end

      module Latest = V1
    end
    with type ('common, 'body) V1.t = ('common, 'body) t
end

module Stable : sig
  module V1 : sig
    type t = (Common.Stable.V1.t, Body.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving eq, sexp, hash]

val create :
     fee:Currency.Fee.t
  -> nonce:Coda_numbers.Account_nonce.t
  -> memo:User_command_memo.t
  -> body:Body.t
  -> t

val length_in_triples : int

val dummy : t

val fold : t -> bool Triple.t Fold.t

val fee : t -> Currency.Fee.t

val nonce : t -> Coda_numbers.Account_nonce.t

val memo : t -> User_command_memo.t

val body : t -> Body.t

val is_payment : t -> bool

val accounts_accessed : t -> Public_key.Compressed.t list

val gen : t Quickcheck.Generator.t
