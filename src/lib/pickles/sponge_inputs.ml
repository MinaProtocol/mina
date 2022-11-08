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
  let rounds_full = Make_sponge.Rounds.rounds_full

  let round_table start =
    let ({ round_constants; mds } : _ Sponge.Params.t) = B.params in
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
    for i = 0 to rounds_full - 1 do
      res.(i + 1) <- apply_round i res.(i)
    done ;
    res

  let block_cipher (params : _ Sponge.Params.t) init =
    let open Impl in
    Impl.with_label __LOC__ (fun () ->
        let t =
          exists
            (Typ.array
               ~length:Int.(rounds_full + 1)
               (Typ.array ~length:3 Field.typ) )
            ~compute:
              As_prover.(fun () -> round_table (Array.map init ~f:read_var))
        in
        t.(0) <- init ;
        (let open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint in
        Impl.with_label __LOC__ (fun () ->
            Impl.assert_
              { basic = T (Poseidon { state = t })
              ; annotation = Some "plonk-poseidon"
              } )) ;
        t.(Int.(Array.length t - 1)) )

  let add_assign ~state i x =
    state.(i) <- Util.seal (module Impl) Impl.Field.(state.(i) + x)

  let copy = Array.copy

  module Field = Impl.Field
end
