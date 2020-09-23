open Core
open Pickles_types
open Backend
open Composition_types
open Common

let wrap_domains = Common.wrap_domains

let evals =
  let e =
    Dlog_plonk_types.Evals.map
      (Commitment_lengths.of_domains ~max_degree:Max_degree.wrap wrap_domains)
      ~f:(fun len -> Array.create ~len Backend.Tock.Field.one)
  in
  let ex = (e, Backend.Tock.Field.zero) in
  (ex, ex)

let evals_combined =
  Tuple_lib.Double.map evals ~f:(fun (e, _x) ->
      Dlog_plonk_types.Evals.map e
        ~f:(Array.reduce_exn ~f:Backend.Tock.Field.( + )) )

module Ipa = struct
  module Wrap = struct
    let challenges =
      Vector.init Tock.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          { Bulletproof_challenge.is_square=
              Tock.Field.is_square (Endo.Dee.to_field prechallenge)
          ; prechallenge } )

    let challenges_computed =
      Vector.map challenges ~f:(fun {is_square; prechallenge} ->
          (Ipa.Wrap.compute_challenge ~is_square prechallenge : Tock.Field.t)
      )

    let sg =
      lazy
        (Common.time "dummy wrap sg" (fun () -> Ipa.Wrap.compute_sg challenges))
  end

  module Step = struct
    let challenges =
      Vector.init Tick.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          { Bulletproof_challenge.is_square=
              Tick.Field.is_square (Endo.Dum.to_field prechallenge)
          ; prechallenge } )

    let challenges_computed =
      Vector.map challenges ~f:(fun {is_square; prechallenge} ->
          (Ipa.Step.compute_challenge ~is_square prechallenge : Tick.Field.t)
      )

    let sg =
      lazy
        (Common.time "dummy wrap sg" (fun () -> Ipa.Step.compute_sg challenges))
  end
end
