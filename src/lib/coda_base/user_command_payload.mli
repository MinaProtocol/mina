[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick
open Signature_lib

[%%else]

open Snark_params_nonconsensus
open Signature_lib_nonconsensus
module Currency = Currency_nonconsensus.Currency
module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

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
    type ('fee, 'nonce, 'global_slot, 'memo) t =
      {fee: 'fee; nonce: 'nonce; valid_until: 'global_slot; memo: 'memo}
    [@@deriving eq, sexp, hash, yojson]

    module Stable :
      sig
        module V1 : sig
          type ('fee, 'nonce, 'global_slot, 'memo) t
          [@@deriving bin_io, eq, sexp, hash, yojson, version]
        end

        module Latest = V1
      end
      with type ('fee, 'nonce, 'global_slot, 'memo) V1.t =
                  ('fee, 'nonce, 'global_slot, 'memo) t
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Currency.Fee.Stable.V1.t
        , Coda_numbers.Account_nonce.Stable.V1.t
        , Coda_numbers.Global_slot.Stable.V1.t
        , User_command_memo.t )
        Poly.Stable.V1.t
      [@@deriving bin_io, eq, sexp, hash]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving compare, eq, sexp, hash]

  val to_input : t -> (Field.t, bool) Random_oracle.Input.t

  val gen : t Quickcheck.Generator.t

  [%%ifdef consensus_mechanism]

  type var =
    ( Currency.Fee.var
    , Coda_numbers.Account_nonce.Checked.t
    , Coda_numbers.Global_slot.Checked.t
    , User_command_memo.Checked.t )
    Poly.t

  val typ : (var, t) Typ.t

  module Checked : sig
    val to_input :
      var -> ((Field.Var.t, Boolean.var) Random_oracle.Input.t, _) Checked.t

    val constant : t -> var
  end

  [%%endif]
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

type t = Stable.Latest.t [@@deriving compare, eq, sexp, hash]

val create :
     fee:Currency.Fee.t
  -> nonce:Coda_numbers.Account_nonce.t
  -> valid_until:Coda_numbers.Global_slot.t
  -> memo:User_command_memo.t
  -> body:Body.t
  -> t

val dummy : t

val fee : t -> Currency.Fee.t

val nonce : t -> Coda_numbers.Account_nonce.t

val valid_until : t -> Coda_numbers.Global_slot.t

val memo : t -> User_command_memo.t

val body : t -> Body.t

val receiver : t -> Public_key.Compressed.t

val amount : t -> Currency.Amount.t option

val is_payment : t -> bool

val accounts_accessed : t -> Public_key.Compressed.t list

val gen : t Quickcheck.Generator.t
