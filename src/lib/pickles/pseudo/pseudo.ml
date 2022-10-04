module Array = Core_kernel.Array
module Nat = Pickles_types.Nat
module Vector = Pickles_types.Vector

module Make (Impl : Snarky_backendless.Snark_intf.Run) = struct
  type ('a, 'n) t = 'n One_hot_vector.T(Impl).t * ('a, 'n) Vector.t

  module Field = Impl.Field

  (* TODO: Use version in common. *)
  (* TODO?: There's no such version in module Pickles.Common *)
  (* TODO: this function only applies to module Impl. This is probably where it
     should be defined and not in this functor. *)
  let seal (x : Field.t) : Field.t =
    let open Impl in
    match Field.to_constant_and_terms x with
    | None, [ (x, i) ] when Field.Constant.(equal x one) ->
        Snarky_backendless.Cvar.Var i
    | Some c, [] ->
        Field.constant c
    | _ ->
        let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
        Field.Assert.equal x y ; y

  let mask (type n) (bits : n One_hot_vector.T(Impl).t) xs =
    let open Impl in
    with_label __LOC__ (fun () ->
        Vector.map
          (Vector.zip (bits :> (Boolean.var, n) Vector.t) xs)
          ~f:(fun (b, x) -> Field.((b :> t) * x))
        |> Vector.fold ~init:Field.zero ~f:Field.( + ) )

  let choose : type a n. (a, n) t -> f:(a -> Impl.Field.t) -> Impl.Field.t =
   fun (bits, xs) ~f -> mask bits (Vector.map xs ~f)

  module Degree_bound = struct
    type nonrec 'n t = (int, 'n) t

    let shifted_pow ~crs_max_degree t x =
      let pow = Field.(Pickles_types.Pcs_batch.pow ~one ~mul) in
      choose t ~f:(fun deg ->
          let d = deg mod crs_max_degree in
          pow x (crs_max_degree - d) )
  end

  module Domain = struct
    let num_shifts = Nat.to_int Pickles_types.Plonk_types.Permuts.n

    let shifts (type n) ((which, log2s) : (int, n) t)
        ~(shifts : log2_size:int -> Field.Constant.t array) :
        Field.t Pickles_types.Plonk_types.Shifts.t =
      let all_shifts = Vector.map log2s ~f:(fun d -> shifts ~log2_size:d) in
      match all_shifts with
      | [] ->
          failwith "Pseudo.Domain.shifts: no domains were given"
      | shifts :: other_shiftss ->
          (* Runtime check that the shifts across all domains are consistent.
             The optimisation below will not work if this is not true; if the
             domain size or the shifts are modified such that this becomes
             false, [disabled_not_the_same] can be set to true to enable
             dynamic selection within the circuit.
          *)
          let all_the_same =
            Vector.for_all other_shiftss
              ~f:(Array.for_all2_exn ~f:Field.Constant.equal shifts)
          in
          (* Set to true if we do not want to allow dynamic selection of the
             shifts at runtime.
             This is possible because of the optimisation outlined in the
             doc-comment above, but this option and the original code is left
             here in case we transition to a larger domain size that uses
             different shifts than those for smaller domains.
          *)
          let disabled_not_the_same = true in
          if all_the_same then Array.map ~f:Field.constant shifts
          else if disabled_not_the_same then
            failwith "Pseudo.Domain.shifts: found variable shifts"
          else
            let open Pickles_types.Plonk_types.Shifts in
            let get_ith_shift i =
              mask which
                (Vector.map all_shifts ~f:(fun a -> Field.constant a.(i)))
            in
            Array.init num_shifts ~f:get_ith_shift

    let generator (type n) ((which, log2s) : (int, n) t) ~domain_generator =
      mask which (Vector.map log2s ~f:(fun d -> domain_generator ~log2_size:d))

    type nonrec 'n t = (Plonk_checks.Domain.t, 'n) t

    let to_domain ~shifts:s ~domain_generator (type n) ((dom, ds) as t : n t) :
        Field.t Plonk_checks.plonk_domain =
      let log2_sizes = Vector.map ds ~f:Plonk_checks.Domain.log2_size in
      let max_log2 =
        Vector.fold ds ~init:0 ~f:(fun acc d ->
            Int.max acc (Plonk_checks.Domain.log2_size d) )
      in
      let v = (dom, log2_sizes) in
      let shifts = shifts v ~shifts:s in
      let generator = generator v ~domain_generator in

      object
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
          seal
            ( choose t ~f:(fun d -> pow2_pows.(Plonk_checks.Domain.log2_size d))
            - one )
      end
  end
end
