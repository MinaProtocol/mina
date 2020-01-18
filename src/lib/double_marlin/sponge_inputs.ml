open Core_kernel

module type Field = sig
  include Sponge.Intf.Field

  val square : t -> t
end

module Make (Impl : Snarky.Snark_intf.Run) = struct
  open Impl
  open Field
  module Field = Field

  let rounds_full = 8

  let rounds_partial = 30

  let to_the_alpha x = x |> square |> square |> square |> square |> ( * ) x

  module Operations = struct
    (* TODO: experiment with sealing version of this *)
    let add_assign ~state i x = state.(i) <- state.(i) + x

    let apply_affine_map (matrix, constants) v =
      let seal x =
        let x' = exists typ ~compute:As_prover.(fun () -> read_var x) in
        Assert.equal x x' ; x'
      in
      let dotv row =
        Array.reduce_exn (Array.map2_exn row v ~f:( * )) ~f:( + )
      in
      Array.mapi matrix ~f:(fun i row -> seal (constants.(i) + dotv row))

    let copy = Array.copy
  end
end
