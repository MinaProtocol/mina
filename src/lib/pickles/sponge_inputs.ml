open Core_kernel

module type Field = sig
  include Sponge.Intf.Field

  val square : t -> t
end

module Make
    (Impl : Snarky_backendless.Snark_intf.Run) (B : sig
        open Impl

        val params : field Sponge.Params.t

        val to_the_alpha : field -> field

        module Operations : sig
          val apply_affine_map :
            field array array * field array -> field array -> field array
        end
    end) =
struct
  include Make_sponge.Rounds

  (* TODO: This is wronge. A round should be
   ark -> sbox -> mds 

   instead of 

   sbox -> mds -> ark 

   which is what's implemented.
  *)
  let round_table start =
    let ({round_constants; mds} : _ Sponge.Params.t) = B.params in
    (* sbox -> mds -> ark *)
    let apply_round i s =
      let s' = Array.map s ~f:B.to_the_alpha in
      B.Operations.apply_affine_map (mds, round_constants.(i)) s'
    in
    let res =
      Array.init (rounds_full + 1) ~f:(fun _ ->
          Array.create ~len:3 Impl.Field.Constant.zero )
    in
    res.(0) <- start ;
    for i = 1 to rounds_full do
      res.(i) <- apply_round i res.(i - 1)
    done ;
    res

  open Impl
  open Field
  module Field = Field

  let block_cipher (params : _ Sponge.Params.t) init =
    Impl.with_label __LOC__ (fun () ->
        let init =
          Array.map2_exn
            ~f:(fun c x -> Util.seal (module Impl) (c + x))
            init params.round_constants.(0)
        in
        let t =
          exists
            (Typ.array
               ~length:Int.(rounds_full + 1)
               (Typ.array ~length:3 Field.typ))
            ~compute:
              As_prover.(fun () -> round_table (Array.map init ~f:read_var))
        in
        t.(0) <- init ;
        (let open Zexe_backend_common.Plonk_constraint_system.Plonk_constraint in
        with_label __LOC__ (fun () ->
            Impl.assert_
              [ { basic= T (Poseidon {state= t})
                ; annotation= Some "plonk-poseidon" } ] )) ;
        t.(Int.(Array.length t - 1)) )

  (* TODO: experiment with sealing version of this *)
  let add_assign ~state i x =
    state.(i) <- Util.seal (module Impl) (state.(i) + x)

  let copy = Array.copy
end
