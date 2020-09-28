open Core_kernel
open Pickles_types
module Domain = Marlin_checks.Domain

module Make (Impl : Snarky_backendless.Snark_intf.Run) = struct
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

  let mask (type n) (bits : n One_hot_vector.T(Impl).t) xs =
    Vector.map
      (Vector.zip (bits :> (Boolean.var, n) Vector.t) xs)
      ~f:(fun (b, x) -> Field.((b :> t) * x))
    |> Vector.fold ~init:Field.zero ~f:Field.( + )

  let choose : type a n. (a, n) t -> f:(a -> Field.t) -> Field.t =
   fun (bits, xs) ~f -> mask bits (Vector.map xs ~f)

  module Degree_bound = struct
    type nonrec 'n t = (int, 'n) t

    let shifted_pow ~crs_max_degree t x =
      let pow = Field.(Pcs_batch.pow ~one ~mul) in
      choose t ~f:(fun deg ->
          let d = deg mod crs_max_degree in
          pow x (crs_max_degree - d) )
  end

  module Domain = struct
    let shifts (type n) ((which, log2s) : (int, n) t) ~shifts =
      let shifts = Vector.map log2s ~f:(fun d -> shifts ~log2_size:d) in
      let open Snarky_bn382.Shifts in
      let mk f = mask which (Vector.map shifts ~f) in
      {r= mk (fun {r; _} -> r); o= mk (fun {o; _} -> o)}

    let generator (type n) ((which, log2s) : (int, n) t) ~domain_generator =
      mask which (Vector.map log2s ~f:(fun d -> domain_generator ~log2_size:d))

    type nonrec 'n t = (Domain.t, 'n) t

    let to_domain ~shifts:s ~domain_generator (type n) (t : n t) :
        Field.t Marlin_checks.plonk_domain =
      (* TODO: Special case when all the domains happen to be the same. *)
      let size = seal (choose t ~f:(fun d -> Field.of_int (Domain.size d))) in
      let log2_sizes = Vector.map (snd t) ~f:Domain.log2_size in
      let shifts = shifts (fst t, log2_sizes) ~shifts:s in
      let generator = generator (fst t, log2_sizes) ~domain_generator in
      let max_log2 =
        let _, ds = t in
        List.fold (Vector.to_list ds) ~init:0 ~f:(fun acc d ->
            Int.max acc (Domain.log2_size d) )
      in
      object
        method size = size

        method shifts = shifts

        method generator = generator

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
