let evals =
  let open Pickles_types.Plonk_types in
  let e =
    Evals.map Evaluation_lengths.constants ~f:(fun n ->
        let a () = Array.create ~len:n (Ro.tock ()) in
        (a (), a ()) )
  in
  let ex =
    { All_evals.With_public_input.evals = e
    ; public_input = (Ro.tock (), Ro.tock ())
    }
  in
  { All_evals.ft_eval1 = Ro.tock (); evals = ex }

let evals_combined =
  Pickles_types.Plonk_types.All_evals.map evals
    ~f1:(fun x -> x)
    ~f2:(Array.reduce_exn ~f:Backend.Tock.Field.( + ))

module Ipa = struct
  module Wrap = struct
    let challenges =
      Pickles_types.Vector.init Backend.Tock.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          Composition_types.Bulletproof_challenge.unpack prechallenge )

    let challenges_computed =
      Pickles_types.Vector.map challenges
        ~f:(fun prechallenge : Backend.Tock.Field.t ->
          Common.Ipa.Wrap.compute_challenge
          @@ Composition_types.Bulletproof_challenge.pack prechallenge )

    let sg =
      lazy
        (Common.time "dummy wrap sg" (fun () ->
             Common.Ipa.Wrap.compute_sg challenges ) )
  end

  module Step = struct
    let challenges =
      Pickles_types.Vector.init Backend.Tick.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          Composition_types.Bulletproof_challenge.unpack prechallenge )

    let challenges_computed =
      Pickles_types.Vector.map challenges
        ~f:(fun prechallenge : Backend.Tick.Field.t ->
          Common.Ipa.Step.compute_challenge
          @@ Composition_types.Bulletproof_challenge.pack prechallenge )

    let sg =
      lazy
        (Common.time "dummy step sg" (fun () ->
             Common.Ipa.Step.compute_sg challenges ) )
  end
end
