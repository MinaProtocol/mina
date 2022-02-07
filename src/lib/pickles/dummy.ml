open Core_kernel
open Pickles_types

let wrap_domains = Common.wrap_domains

let evals =
  let open Dlog_plonk_types in
  let e () =
    Evals.map (Evaluation_lengths.create ~of_int:Fn.id) ~f:(fun n ->
        Array.create n (Ro.tock ()))
  in
  let ex () =
    { All_evals.With_public_input.evals = e (); public_input = Ro.tock () }
  in
  { All_evals.ft_eval1 = Ro.tock (); evals = (ex (), ex ()) }

let evals_combined =
  Dlog_plonk_types.All_evals.map evals ~f1:Fn.id
    ~f2:(Array.reduce_exn ~f:Backend.Tock.Field.( + ))

module Ipa = struct
  module Wrap = struct
    let challenges =
      let open Composition_types in
      Vector.init Backend.Tock.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          { Bulletproof_challenge.prechallenge })

    let challenges_computed =
      Vector.map challenges ~f:(fun { prechallenge } : Backend.Tock.Field.t ->
          Common.Ipa.Wrap.compute_challenge prechallenge)

    let sg =
      lazy
        (Common.time "dummy wrap sg" (fun () -> Common.Ipa.Wrap.compute_sg challenges))
  end

  module Step = struct
    let challenges =
      let open Composition_types in
      Vector.init Backend.Tick.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          { Bulletproof_challenge.prechallenge })

    let challenges_computed =
      Vector.map challenges ~f:(fun { prechallenge } : Backend.Tick.Field.t ->
          Common.Ipa.Step.compute_challenge prechallenge)

    let sg =
      lazy
        (Common.time "dummy wrap sg" (fun () -> Common.Ipa.Step.compute_sg challenges))
  end
end
