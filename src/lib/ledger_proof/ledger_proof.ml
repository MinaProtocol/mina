[%%import
"../../config.mlh"]

open Core_kernel
open Coda_base
open Module_version

module type S = Ledger_proof_intf.S

let to_signed_amount signed_fee =
  let magnitude =
    Currency.Fee.Signed.magnitude signed_fee |> Currency.Amount.of_fee
  and sgn = Currency.Fee.Signed.sgn signed_fee in
  Currency.Amount.Signed.create ~magnitude ~sgn

module Prod : Ledger_proof_intf.S with type t = Transaction_snark.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Transaction_snark.Stable.V1.t
        [@@deriving bin_io, compare, sexp, version, to_yojson]
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

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  let statement (t : t) = Transaction_snark.statement t

  let sok_digest = Transaction_snark.sok_digest

  let statement_target (t : Transaction_snark.Statement.t) = t.target

  let underlying_proof = Transaction_snark.proof

  let create
      ~statement:{ Transaction_snark.Statement.source
                 ; target
                 ; supply_increase
                 ; fee_excess
                 ; pending_coinbase_stack_state
                 ; proof_type } ~sok_digest ~proof =
    Transaction_snark.create ~source ~target ~pending_coinbase_stack_state
      ~supply_increase
      ~fee_excess:(to_signed_amount fee_excess)
      ~sok_digest ~proof ~proof_type
end

module Debug :
  Ledger_proof_intf.S
  with type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t =
struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          Transaction_snark.Statement.Stable.V1.t
          * Sok_message.Digest.Stable.V1.t
        [@@deriving bin_io, compare, hash, sexp, version, yojson]
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

  let statement ((t, _) : t) : Transaction_snark.Statement.t = t

  let underlying_proof (_ : t) = Proof.dummy

  let statement_target (t : Transaction_snark.Statement.t) = t.target

  let sok_digest (_, d) = d

  let create ~statement ~sok_digest ~proof:_ = (statement, sok_digest)
end

[%%if
proof_level = "full"]

include Prod

[%%else]

(* TODO #1698: proof_level=check *)

include Debug

[%%endif]

type _ type_witness =
  | Debug : Debug.t type_witness
  | Prod : Prod.t type_witness

type witnessed_list_with_messages =
  | Witnessed_list_with_messages :
      ('t * Sok_message.t) list * 't type_witness
      -> witnessed_list_with_messages

module For_tests = struct
  let mk_dummy_proof statement =
    create ~statement ~sok_digest:Sok_message.Digest.default ~proof:Proof.dummy
end
