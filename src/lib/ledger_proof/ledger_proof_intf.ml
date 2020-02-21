open Core_kernel
open Coda_base

module type S = sig
  (* bin_io omitted intentionally *)
  type t [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving bin_io, compare, sexp, version, to_yojson]

        val to_latest : t -> t

        val of_latest : t -> (t, _) Result.t
      end

      module Latest = V1
    end
    with type V1.t = t

  val create :
       statement:Transaction_snark.Statement.t
    -> sok_digest:Sok_message.Digest.t
    -> proof:Proof.t
    -> t

  val statement_target : Transaction_snark.Statement.t -> Frozen_ledger_hash.t

  val statement : t -> Transaction_snark.Statement.t

  val sok_digest : t -> Sok_message.Digest.t

  val underlying_proof : t -> Proof.t
end
