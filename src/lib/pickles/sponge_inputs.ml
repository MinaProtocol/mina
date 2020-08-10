open Core_kernel

module type Field = sig
  include Sponge.Intf.Field

  val square : t -> t
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) = struct
  open Impl
  open Field
  module Field = Field
  include Make_sponge.Rounds

  let to_the_alpha x = x |> square |> square |> square |> square |> ( * ) x

  module Operations = struct
    let seal x =
      match Field.to_constant x with
      | Some x ->
          Field.constant x
      | None ->
          let x' = exists typ ~compute:As_prover.(fun () -> read_var x) in
          Assert.equal x x' ; x'

    (* TODO: experiment with sealing version of this *)
    let add_assign ~state i x = state.(i) <- state.(i) + x

    (* TODO: Clean this up to use the near mds matrix properly *)
    let apply_affine_map (_matrix, constants) v =
      let near_mds_matrix_v =
        [|v.(0) + v.(2); v.(0) + v.(1); v.(1) + v.(2)|]
      in
      Array.mapi near_mds_matrix_v ~f:(fun i x -> seal (constants.(i) + x))

    let copy = Array.copy
  end
end
