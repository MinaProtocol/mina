open Core_kernel
open Pickles_types
module Domain = Marlin_checks.Domain

module Make (Impl : Snarky.Snark_intf.Run) = struct
  open Impl

  type ('a, 'n) t = 'n One_hot_vector.T(Impl).t * ('a, 'n) Vector.t

  (* TODO: Put this in a common module. *)
  let seal x =
    match Field.to_constant x with
    | Some x ->
        Field.constant x
    | None ->
        let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
        Field.Assert.equal x y ; y

  let choose : type a n. (a, n) t -> f:(a -> Field.t) -> Field.t =
   fun (bits, xs) ~f ->
    let bits = (bits :> (Boolean.var, n) Vector.t) in
    Vector.map (Vector.zip bits xs) ~f:(fun (b, x) -> Field.((b :> t) * f x))
    |> Vector.fold ~init:Field.zero ~f:Field.( + )

  module Degree_bound = struct
    type nonrec 'n t = (int, 'n) t

    let shifted_pow ~crs_max_degree t x =
      let pow = Field.(Pcs_batch.pow ~one ~mul) in
      choose t ~f:(fun deg ->
          let d = deg mod crs_max_degree in
          pow x (crs_max_degree - d) )
  end

  module Domain = struct
    type nonrec 'n t = (Domain.t, 'n) t

    let to_domain (type n) (t : n t) : Field.t Marlin_checks.domain =
      (* TODO: Special case when all the domains happen to be the same. *)
      let size = seal (choose t ~f:(fun d -> Field.of_int (Domain.size d))) in
      let max_log2 =
        let _, ds = t in
        List.fold (Vector.to_list ds) ~init:0 ~f:(fun acc d ->
            Int.max acc (Domain.log2_size d) )
      in
      object
        method size = size

        method vanishing_polynomial x =
          let pow2_pows =
            let res = Array.create ~len:(max_log2 + 1) x in
            for i = 1 to max_log2 do
              res.(i) <- Field.square res.(i - 1)
            done ;
            res
          in
          let open Field in
          seal (choose t ~f:(fun d -> pow2_pows.(Domain.log2_size d)) - one)
      end
  end
end
