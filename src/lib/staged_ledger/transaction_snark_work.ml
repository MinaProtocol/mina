open Core_kernel
open Async_kernel
open Protocols
open Coda_pow

module Make
    (Compressed_public_key : Compressed_public_key_intf) (Ledger_proof : sig
        type t [@@deriving sexp, bin_io]
    end) (Ledger_proof_statement : sig
      type t [@@deriving sexp, bin_io, hash, compare]

      val gen : t Quickcheck.Generator.t
    end) :
  Coda_pow.Transaction_snark_work_intf
  with type proof := Ledger_proof.t
   and type statement := Ledger_proof_statement.t
   and type public_key := Compressed_public_key.t = struct
  let proofs_length = 2

  module Statement = struct
    module T = struct
      type t = Ledger_proof_statement.t list
      [@@deriving bin_io, sexp, hash, compare]
    end

    include T
    include Hashable.Make_binable (T)

    let gen =
      Quickcheck.Generator.list_with_length proofs_length
        Ledger_proof_statement.gen
  end

  module T = struct
    type t =
      { fee: Fee.Unsigned.t
      ; proofs: Ledger_proof.t list
      ; prover: Compressed_public_key.t }
    [@@deriving sexp, bin_io]
  end

  include T

  type unchecked = t

  module Checked = struct
    include T

    let create_unsafe = Fn.id
  end

  let forget = Fn.id
end
