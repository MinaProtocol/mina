open Core
open Snarky
open Sponge

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf
  (* TODO: need to derive sponge parameters from Snarky Intf Field *)
  let params = Sponge.Params.(map tweedle_p ~f:Field.Constant.of_string)

  let permute (start : Field.t array) rounds : Field.t array =
    let length = Array.length start in
    let state = exists 
        (Snarky.Typ.array ~length:rounds (Snarky.Typ.array length Field.typ)) 
        ~compute:As_prover.(fun () ->
            (
              let state = Array.create rounds (Array.create length zero) in
              Array.iteri
                state
                ~f:(fun i _ ->
                    (
                      let prev = if i = 0 then Array.map ~f: (fun x -> read_var x) start else state.(Int.(i-1)) in
                      Array.map_inplace ~f:(fun x -> (square (square x)) * x) prev;
                      state.(i) <- Array.map
                          ~f:(fun p -> Array.fold2_exn p prev ~init:Field.Constant.zero ~f:(fun c a b -> a * b + c))
                          params.mds;
                      for j = 0 to Int.(length - 1) do
                        state.(i).(j) <- state.(i).(j) + params.round_constants.(i).(j)
                      done
                    )
                  );
              state
            ))
    in
    Intf.assert_
      [{
        basic= Zexe_backend.R1CS_constraint_system.Plonk_constraint.T (Poseidon { start; state }) ;
        annotation= None
      }];
    state.(rounds - 1)

end
