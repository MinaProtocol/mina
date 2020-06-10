open Pickles_types
open Zexe_backend

type dlog_opening =
  (G.Affine.t, Fq.t) Types.Pairing_based.Openings.Bulletproof.t

type t = dlog_opening * (G.Affine.t, Fq.t) Dlog_marlin_types.Messages.t

open Pairing_main_inputs

type var =
  (G.t, Impls.Pairing_based.Fq.t) Types.Pairing_based.Openings.Bulletproof.t
  * (G.t, Impls.Pairing_based.Fq.t) Dlog_marlin_types.Messages.t

open Impls.Pairing_based

let typ : (var, t) Typ.t =
  Typ.tuple2
    (Types.Pairing_based.Openings.Bulletproof.typ
       ~length:(Nat.to_int Dlog_based.Rounds.n)
       Fq.typ G.typ)
    (Pickles_types.Dlog_marlin_types.Messages.typ
       ~commitment_lengths:(Commitment_lengths.of_domains Common.wrap_domains)
       Fq.typ G.typ)
