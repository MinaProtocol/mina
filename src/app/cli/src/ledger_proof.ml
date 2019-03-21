open Core_kernel
open Async_kernel
open Coda_base
open Module_version

let to_signed_amount signed_fee =
  let magnitude =
    Currency.Fee.Signed.magnitude signed_fee |> Currency.Amount.of_fee
  and sgn = Currency.Fee.Signed.sgn signed_fee in
  Currency.Amount.Signed.create ~magnitude ~sgn

module Prod :
  Protocols.Coda_pow.Ledger_proof_intf
  with type t = Transaction_snark.t
   and type statement = Transaction_snark.Statement.t
   and type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Frozen_ledger_hash.t
   and type proof := Proof.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = Transaction_snark.Stable.V1.t
        [@@deriving bin_io, sexp, yojson]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "ledger_proof_prod"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t [@@deriving sexp, yojson]

  type statement = Transaction_snark.Statement.t

  let sok_digest = Transaction_snark.sok_digest

  let statement = Transaction_snark.statement

  let statement_target (t : Transaction_snark.Statement.t) = t.target

  let underlying_proof = Transaction_snark.proof

  let create
      ~statement:{ Transaction_snark.Statement.source
                 ; target
                 ; supply_increase
                 ; fee_excess
                 ; proof_type } ~sok_digest ~proof =
    Transaction_snark.create ~source ~target ~supply_increase
      ~fee_excess:(to_signed_amount fee_excess)
      ~sok_digest ~proof ~proof_type
end

module Debug :
  Protocols.Coda_pow.Ledger_proof_intf
  with type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t
   and type statement = Transaction_snark.Statement.t
   and type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Frozen_ledger_hash.t
   and type proof := Proof.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t =
          Transaction_snark.Statement.Stable.V1.t
          * Sok_message.Digest.Stable.V1.t
        [@@deriving sexp, bin_io, yojson]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "ledger_proof_debug"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t [@@deriving sexp, yojson]

  type statement = Transaction_snark.Statement.t

  let underlying_proof (_ : t) = Proof.dummy

  let statement ((t, _) : t) : Transaction_snark.Statement.t = t

  let statement_target (t : Transaction_snark.Statement.t) = t.target

  let sok_digest (_, d) = d

  let create ~statement ~sok_digest ~proof = (statement, sok_digest)
end
