open Core
open Pickles_types
open Zexe_backend

let wrap_domains = Common.wrap_domains

let pairing_acc = Pairing_acc.dummy

let evals =
  let e =
    Dlog_marlin_types.Evals.map (Commitment_lengths.of_domains wrap_domains)
      ~f:(fun len -> Array.create ~len Fq.one)
  in
  let ex = (e, Fq.zero) in
  (ex, ex, ex)
