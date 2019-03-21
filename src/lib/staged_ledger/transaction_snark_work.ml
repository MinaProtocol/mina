open Core_kernel
open Async_kernel
open Protocols
open Coda_pow
open Signature_lib
open Module_version

module Make (Ledger_proof : sig
  type t [@@deriving sexp, bin_io]
end) (Ledger_proof_statement : sig
  type t [@@deriving sexp, bin_io, hash, compare, yojson]

  val gen : t Quickcheck.Generator.t
end) :
  Coda_pow.Transaction_snark_work_intf
  with type proof := Ledger_proof.t
   and type statement := Ledger_proof_statement.t
   and type public_key := Public_key.Compressed.t = struct
  let proofs_length = 2

  module Statement = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          let version = 1

          (* TODO : version Ledger_proof_statement *)
          type t = Ledger_proof_statement.t list
          [@@deriving bin_io, sexp, hash, compare, yojson]
        end

        include T
        include Registration.Make_latest_version (T)
        include Hashable.Make_binable (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "transaction_snark_work_statement"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    (* bin_io omitted *)
    type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]

    include Hashable.Make (Stable.Latest)

    let gen =
      Quickcheck.Generator.list_with_length proofs_length
        Ledger_proof_statement.gen
  end

  module T = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          let version = 1

          type t =
            { fee: Fee.Unsigned.t
            ; proofs: Ledger_proof.t list
            ; prover: Public_key.Compressed.Stable.V1.t }
          [@@deriving sexp, bin_io]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "transaction_snark_work"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    (* bin_io omitted *)
    type t = Stable.Latest.t =
      { fee: Fee.Unsigned.t
      ; proofs: Ledger_proof.t list
      ; prover: Public_key.Compressed.t }
    [@@deriving sexp]
  end

  include T

  type unchecked = t

  module Checked = struct
    include T

    let create_unsafe = Fn.id
  end

  let forget = Fn.id
end
