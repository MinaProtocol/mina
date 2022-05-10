(* q > p *)
open Core_kernel
module SC = Scalar_challenge
open Import
open Util
open Types.Step
open Pickles_types
open Common
open Import
module S = Sponge

module Make
    (Inputs : Intf.Step_main_inputs.S
                with type Impl.field = Backend.Tick.Field.t
                 and type Impl.Bigint.t = Backend.Tick.Bigint.R.t
                 and type Inner_curve.Constant.Scalar.t = Backend.Tock.Field.t) =
struct
  open Inputs
  open Impl
  module PC = Inner_curve
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Number = Snarky_backendless.Number.Run.Make (Impl)

  (* Other_field.size > Field.size *)
  module Other_field = struct
    let size_in_bits = Field.size_in_bits

    module Constant = Other_field

    type t = Impls.Step.Other_field.t

    let typ = Impls.Step.Other_field.typ
  end

  let print_g lab (x, y) =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf
              !"%s: %{sexp:Backend.Tick.Field.t}, %{sexp:Backend.Tick.Field.t}\n\
                %!"
              lab (read_var x) (read_var y))

  let print_chal lab chal =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf
              !"%s: %{sexp:Challenge.Constant.t}\n%!"
              lab (read Challenge.typ chal))

  let print_fp lab x =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf !"%s: %{sexp:Backend.Tick.Field.t}\n%!" lab (read_var x))

  let print_bool lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x))

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal
      (Inner_curve.to_field_elements g1)
      (Inner_curve.to_field_elements g2)
    |> Boolean.all

  let absorb sponge ty t =
    absorb
      ~absorb_field:(fun x -> Sponge.absorb sponge (`Field x))
      ~g1_to_field_elements:Inner_curve.to_field_elements
      ~absorb_scalar:(fun (x, (b : Boolean.var)) ->
        Sponge.absorb sponge (`Field x) ;
        Sponge.absorb sponge (`Bits [ b ]))
      ~mask_g1_opt:(fun ((b : Boolean.var), (x, y)) ->
        Field.((b :> t) * x, (b :> t) * y))
      ty t

  let scalar_to_field s =
    SC.to_field_checked (module Impl) s ~endo:Endo.Wrap_inner_curve.scalar

  let lowest_128_bits ~constrain_low_bits x =
    let assert_128_bits a =
      (* Scalar_challenge.to_field_checked has the side effect of
         checking that the input fits in 128 bits. *)
      ignore (scalar_to_field (SC.SC.create a) : Field.t)
    in
    Util.lowest_128_bits ~constrain_low_bits ~assert_128_bits (module Impl) x

  module Scalar_challenge =
    SC.Make (Impl) (Inner_curve) (Challenge) (Endo.Step_inner_curve)
  module Ops = Step_main_inputs.Ops

  module Inner_curve = struct
    include Inner_curve

    let ( + ) = Ops.add_fast
  end

  let multiscale_known
      (ts :
        ( [ `Field of Field.t | `Packed_bits of Field.t * int ]
        * Inner_curve.Constant.t )
        array) =
    let rec pow2pow x i =
      if i = 0 then x else pow2pow Inner_curve.Constant.(x + x) (i - 1)
    in
    let module F = struct
      type t = Field.t

      let typ = Field.typ

      module Constant = struct
        include Field.Constant

        let to_bigint = Impl.Bigint.of_field
      end
    end in
    with_label __LOC__ (fun () ->
        let correction, acc =
          Array.mapi ts ~f:(fun i (s, x) ->
              let rr, n =
                match s with
                | `Packed_bits (s, n) ->
                    ( Ops.scale_fast2'
                        (module F)
                        (Inner_curve.constant x) s ~num_bits:n
                    , n )
                | `Field s ->
                    ( Ops.scale_fast2'
                        (module F)
                        (Inner_curve.constant x) s ~num_bits:Field.size_in_bits
                    , Field.size_in_bits )
              in
              let n =
                Ops.bits_per_chunk * Ops.chunks_needed ~num_bits:(n - 1)
              in
              let cc = pow2pow x n in
              (cc, rr))
          |> Array.reduce_exn ~f:(fun (a1, b1) (a2, b2) ->
                 (Inner_curve.Constant.( + ) a1 a2, Inner_curve.( + ) b1 b2))
        in
        Inner_curve.(acc + constant (Constant.negate correction)))

  let squeeze_challenge sponge : Field.t =
    lowest_128_bits (Sponge.squeeze sponge) ~constrain_low_bits:true

  let squeeze_scalar sponge : Field.t SC.SC.t =
    (* No need to boolean constrain scalar challenges. *)
    SC.SC.create
      (lowest_128_bits ~constrain_low_bits:false (Sponge.squeeze sponge))

  let bullet_reduce sponge gammas =
    with_label __LOC__ (fun () ->
        let absorb t = absorb sponge t in
        let prechallenges =
          Array.mapi gammas ~f:(fun i gammas_i ->
              absorb (PC :: PC) gammas_i ;
              squeeze_scalar sponge)
        in
        let term_and_challenge (l, r) pre =
          let left_term = Scalar_challenge.endo_inv l pre in
          let right_term = Scalar_challenge.endo r pre in
          ( Inner_curve.(left_term + right_term)
          , { Bulletproof_challenge.prechallenge = pre } )
        in
        let terms, challenges =
          Array.map2_exn gammas prechallenges ~f:term_and_challenge
          |> Array.unzip
        in
        (Array.reduce_exn terms ~f:Inner_curve.( + ), challenges))

  let group_map =
    let f =
      lazy
        (let module M =
           Group_map.Bw19.Make (Field.Constant) (Field)
             (struct
               let params =
                 Group_map.Bw19.Params.create
                   (module Field.Constant)
                   { b = Inner_curve.Params.b }
             end)
         in
        let open M in
        Snarky_group_map.Checked.wrap
          (module Impl)
          ~potential_xs
          ~y_squared:(fun ~x ->
            Field.(
              (x * x * x)
              + (constant Inner_curve.Params.a * x)
              + constant Inner_curve.Params.b))
        |> unstage)
    in
    fun x -> Lazy.force f x

  let scale_fast p s =
    with_label __LOC__ (fun () ->
        Ops.scale_fast p s ~num_bits:Field.size_in_bits)

  let scale_fast2 p (s : Other_field.t Shifted_value.Type2.t) =
    with_label __LOC__ (fun () ->
        Ops.scale_fast2 p s ~num_bits:Field.size_in_bits)

  let check_bulletproof ~pcs_batch ~(sponge : Sponge.t) ~xi
      ~combined_inner_product
      ~(* Corresponds to y in figure 7 of WTS *)
       (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Openings.Bulletproof.Advice.t)
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~openings_proof:
        ({ lr; delta; z_1; z_2; sg } :
          ( Inner_curve.t
          , Other_field.t Shifted_value.Type2.t )
          Openings.Bulletproof.t) =
    with_label "check_bulletproof" (fun () ->
        absorb sponge Scalar
          ( match combined_inner_product with
          | Shifted_value.Type2.Shifted_value x ->
              x ) ;
        (* a_hat should be equal to
           sum_i < t, r^i pows(beta_i) >
           = sum_i r^i < t, pows(beta_i) > *)
        let u =
          let t = Sponge.squeeze_field sponge in
          group_map t
        in
        let open Inner_curve in
        let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
          with_label "combined_polynomial" (fun () ->
              Pcs_batch.combine_split_commitments pcs_batch
                ~scale_and_add:
                  (fun ~(acc :
                          [ `Maybe_finite of Boolean.var * Inner_curve.t
                          | `Finite of Inner_curve.t ]) ~xi p ->
                  match acc with
                  | `Maybe_finite (acc_is_finite, (acc : Inner_curve.t)) -> (
                      match p with
                      | `Maybe_finite (p_is_finite, p) ->
                          let is_finite =
                            Boolean.(p_is_finite ||| acc_is_finite)
                          in
                          let xi_acc = Scalar_challenge.endo acc xi in
                          `Maybe_finite
                            ( is_finite
                            , if_ acc_is_finite ~then_:(p + xi_acc) ~else_:p )
                      | `Finite p ->
                          let xi_acc = Scalar_challenge.endo acc xi in
                          `Finite
                            (if_ acc_is_finite ~then_:(p + xi_acc) ~else_:p) )
                  | `Finite acc ->
                      let xi_acc = Scalar_challenge.endo acc xi in
                      `Finite
                        ( match p with
                        | `Finite p ->
                            p + xi_acc
                        | `Maybe_finite (p_is_finite, p) ->
                            if_ p_is_finite ~then_:(p + xi_acc) ~else_:xi_acc ))
                ~xi
                ~init:(function
                  | `Finite x -> `Finite x | `Maybe_finite x -> `Maybe_finite x)
                (Vector.map without_degree_bound
                   ~f:(Array.map ~f:(fun x -> `Finite x)))
                (Vector.map with_degree_bound
                   ~f:
                     (let open Plonk_types.Poly_comm.With_degree_bound in
                     fun { shifted; unshifted } ->
                       let f x = `Maybe_finite x in
                       { unshifted = Array.map ~f unshifted
                       ; shifted = f shifted
                       })))
          |> function `Finite x -> x | `Maybe_finite _ -> assert false
        in
        let lr_prod, challenges = bullet_reduce sponge lr in
        let p_prime =
          let uc = scale_fast2 u combined_inner_product in
          combined_polynomial + uc
        in
        let q = p_prime + lr_prod in
        absorb sponge PC delta ;
        let c = squeeze_scalar sponge in
        print_fp "c" c.inner ;
        (* c Q + delta = z1 (G + b U) + z2 H *)
        let lhs =
          let cq = Scalar_challenge.endo q c in
          cq + delta
        in
        let rhs =
          with_label __LOC__ (fun () ->
              let b_u = scale_fast2 u advice.b in
              let z_1_g_plus_b_u = scale_fast2 (sg + b_u) z_1 in
              let z2_h =
                scale_fast2 (Inner_curve.constant (Lazy.force Generators.h)) z_2
              in
              z_1_g_plus_b_u + z2_h)
        in
        (`Success (equal_g lhs rhs), challenges))

  let assert_eq_deferred_values
      (m1 :
        ( 'a
        , Inputs.Impl.Field.t Import.Scalar_challenge.t )
        Types.Step.Proof_state.Deferred_values.Plonk.Minimal.t)
      (m2 :
        ( Inputs.Impl.Field.t
        , Inputs.Impl.Field.t Import.Scalar_challenge.t )
        Types.Step.Proof_state.Deferred_values.Plonk.Minimal.t) =
    let open Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal in
    let chal c1 c2 = Field.Assert.equal c1 c2 in
    let scalar_chal ({ SC.SC.inner = t1 } : _ Import.Scalar_challenge.t)
        ({ SC.SC.inner = t2 } : _ Import.Scalar_challenge.t) =
      Field.Assert.equal t1 t2
    in
    with_label __LOC__ (fun () -> chal m1.beta m2.beta) ;
    with_label __LOC__ (fun () -> chal m1.gamma m2.gamma) ;
    with_label __LOC__ (fun () -> scalar_chal m1.alpha m2.alpha) ;
    with_label __LOC__ (fun () -> scalar_chal m1.zeta m2.zeta)

  let lagrange_commitment ~domain i =
    let d =
      Kimchi_pasta.Pasta.Precomputed.Lagrange_precomputations
      .index_of_domain_log2 (Domain.log2_size domain)
    in
    match Precomputed.Lagrange_precomputations.pallas.(d).(i) with
    | [| g |] ->
        Inner_curve.Constant.of_affine g
    | _ ->
        assert false

  let incrementally_verify_proof (type b)
      (module Branching : Nat.Add.Intf with type n = b) ~domain
      ~verification_key:(m : _ Plonk_verification_key_evals.t) ~xi ~sponge
      ~(public_input :
         [ `Field of Field.t | `Packed_bits of Field.t * int ] array)
      ~(sg_old : (_, Branching.n) Vector.t) ~combined_inner_product ~advice
      ~(messages : _ Plonk_types.Messages.t) ~openings_proof
      ~(plonk :
         ( _
         , _
         , _ Shifted_value.Type2.t )
         Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t) =
    with_label "incrementally_verify_proof" (fun () ->
        let receive ty f =
          with_label "receive" (fun () ->
              let x = f messages in
              absorb sponge ty x ; x)
        in
        let sample () = squeeze_challenge sponge in
        let sample_scalar () = squeeze_scalar sponge in
        let open Plonk_types.Messages in
        let x_hat =
          with_label "x_hat" (fun () ->
              multiscale_known
                (Array.mapi public_input ~f:(fun i x ->
                     (x, lagrange_commitment ~domain i)))
              |> Inner_curve.negate)
        in
        let without = Type.Without_degree_bound in
        let absorb_g gs = absorb sponge without gs in
        absorb sponge PC x_hat ;
        let w_comm = messages.w_comm in
        Vector.iter ~f:absorb_g w_comm ;
        let beta = sample () in
        let gamma = sample () in
        let z_comm = receive without z_comm in
        let alpha = sample_scalar () in
        let t_comm = receive without t_comm in
        let zeta = sample_scalar () in
        (* At this point, we should use the previous "bulletproof_challenges" to
           compute to compute f(beta_1) outside the snark
           where f is the polynomial corresponding to sg_old
        *)
        let sponge_before_evaluations = Sponge.copy sponge in
        let sponge_digest_before_evaluations = Sponge.squeeze_field sponge in

        (* xi, r are sampled here using the other sponge. *)
        (* No need to expose the polynomial evaluations as deferred values as they're
           not needed here for the incremental verification. All we need is a_hat and
           "combined_inner_product".

           Then, in the other proof, we can witness the evaluations and check their correctness
           against "combined_inner_product" *)
        let sigma_comm_init, [ _ ] =
          Vector.split m.sigma_comm
            (snd (Plonk_types.Permuts_minus_1.add Nat.N1.n))
        in
        let ft_comm =
          with_label __LOC__ (fun () ->
              Common.ft_comm ~add:Ops.add_fast ~scale:scale_fast2
                ~negate:Inner_curve.negate ~endoscale:Scalar_challenge.endo
                ~verification_key:m ~plonk ~alpha ~t_comm)
        in
        let bulletproof_challenges =
          (* This sponge needs to be initialized with (some derivative of)
             1. The polynomial commitments
             2. The combined inner product
             3. The challenge points.

             It should be sufficient to fork the sponge after squeezing beta_3 and then to absorb
             the combined inner product.
          *)
          let num_commitments_without_degree_bound = Nat.N26.n in
          let without_degree_bound =
            let T = Branching.eq in
            Vector.append
              (Vector.map sg_old ~f:(fun g -> [| g |]))
              ( [| x_hat |] :: [| ft_comm |] :: z_comm :: [| m.generic_comm |]
              :: [| m.psm_comm |]
              :: Vector.append w_comm
                   (Vector.map sigma_comm_init ~f:(fun g -> [| g |]))
                   (snd Plonk_types.(Columns.add Permuts_minus_1.n)) )
              (snd (Branching.add num_commitments_without_degree_bound))
          in
          with_label "check_bulletproof" (fun () ->
              check_bulletproof
                ~pcs_batch:
                  (Common.dlog_pcs_batch
                     (Branching.add num_commitments_without_degree_bound))
                ~sponge:sponge_before_evaluations ~xi ~combined_inner_product
                ~advice ~openings_proof ~polynomials:(without_degree_bound, []))
        in
        assert_eq_deferred_values
          { alpha = plonk.alpha
          ; beta = plonk.beta
          ; gamma = plonk.gamma
          ; zeta = plonk.zeta
          }
          { alpha; beta; gamma; zeta } ;
        (sponge_digest_before_evaluations, bulletproof_challenges))

  let compute_challenges ~scalar chals =
    with_label "compute_challenges" (fun () ->
        Vector.map chals ~f:(fun { Bulletproof_challenge.prechallenge } ->
            scalar prechallenge))

  let b_poly = Field.(Wrap_verifier.b_poly ~add ~mul ~one)

  module Pseudo = Pseudo.Make (Impl)

  module Bounded = struct
    type t = { max : int; actual : Field.t }

    let of_pseudo ((_, ns) as p : _ Pseudo.t) =
      { max = Vector.reduce_exn ~f:Int.max ns
      ; actual = Pseudo.choose p ~f:Field.of_int
      }
  end

  let vanishing_polynomial mask =
    with_label "vanishing_polynomial" (fun () ->
        let mask = Vector.to_array mask in
        let max = Array.length mask in
        fun x ->
          let rec go acc i =
            if i >= max then acc
            else
              let should_square = mask.(i) in
              let acc =
                Field.if_ should_square ~then_:(Field.square acc) ~else_:acc
              in
              go acc (i + 1)
          in
          Field.sub (go x 0) Field.one)

  let shifts ~log2_size =
    Common.tick_shifts ~log2_size
    |> Plonk_types.Shifts.map ~f:Impl.Field.constant

  let domain_generator ~log2_size =
    Backend.Tick.Field.domain_generator ~log2_size |> Impl.Field.constant

  module O = One_hot_vector.Make (Impl)

  let side_loaded_input_domain =
    let open Side_loaded_verification_key in
    let input_size = input_size ~of_int:Fn.id ~add:( + ) ~mul:( * ) in
    let max_width = Width.Max.n in
    let domain_log2s =
      Vector.init (S max_width) ~f:(fun w -> Int.ceil_log2 (input_size w))
    in
    let (T max_log2_size) =
      let n = Int.ceil_log2 (input_size (Nat.to_int max_width)) in
      assert (List.last_exn (Vector.to_list domain_log2s) = n) ;
      Nat.of_int n
    in
    fun ~width ->
      let mask = O.of_index width ~length:(S max_width) in
      let shifts = lazy (Pseudo.Domain.shifts (mask, domain_log2s) ~shifts) in
      let generator =
        lazy (Pseudo.Domain.generator (mask, domain_log2s) ~domain_generator)
      in
      let vp =
        let log2_size = Pseudo.choose (mask, domain_log2s) ~f:Field.of_int in
        let mask =
          ones_vector (module Impl) max_log2_size ~first_zero:log2_size
        in
        vanishing_polynomial mask
      in
      let size =
        lazy
          (Pseudo.choose (mask, domain_log2s) ~f:(fun x ->
               Field.of_int (1 lsl x)))
      in
      object
        method shifts = Lazy.force shifts

        method generator = Lazy.force generator

        method size = Lazy.force size

        method vanishing_polynomial = vp
      end

  let side_loaded_domains (type branches) =
    let open Side_loaded_verification_key in
    fun (domains : (Field.t Domain.t Domains.t, branches) Vector.t)
        (branch : branches One_hot_vector.T(Impl).t) ->
      let domain v ~max =
        let (T max_n) = Nat.of_int max in
        let log2_size = Pseudo.choose ~f:Domain.log2_size (branch, v) in
        let mask = ones_vector (module Impl) max_n ~first_zero:log2_size in
        let log2_sizes =
          (O.of_index log2_size ~length:max_n, Vector.init max_n ~f:Fn.id)
        in
        let shifts = Pseudo.Domain.shifts log2_sizes ~shifts in
        let generator = Pseudo.Domain.generator log2_sizes ~domain_generator in
        let vanishing_polynomial = vanishing_polynomial mask in
        let size =
          Vector.map mask ~f:(fun b ->
              (* 0 -> 1
                  1 -> 2 *)
              Field.((b :> t) + one))
          |> Vector.reduce_exn ~f:Field.( * )
        in
        object
          method size = size

          method log2_size = log2_size

          method vanishing_polynomial x = vanishing_polynomial x

          method shifts = shifts

          method generator = generator
        end
      in
      { Domains.h =
          domain
            (Vector.map domains ~f:(fun { h; _ } -> h))
            ~max:(Domain.log2_size max_domains.h)
      }

  let%test_module "side loaded domains" =
    ( module struct
      let run k =
        let y =
          run_and_check (fun () ->
              let y = k () in
              fun () -> As_prover.read_var y)
          |> Or_error.ok_exn
        in
        y

      let%test_unit "side loaded input domain" =
        let open Side_loaded_verification_key in
        let input_size = input_size ~of_int:Fn.id ~add:( + ) ~mul:( * ) in
        let possibilities =
          Vector.init (S Width.Max.n) ~f:(fun w -> Int.ceil_log2 (input_size w))
        in
        let pt = Field.Constant.random () in
        List.iteri (Vector.to_list possibilities) ~f:(fun i d ->
            let d_unchecked =
              Plonk_checks.domain
                (module Field.Constant)
                (Pow_2_roots_of_unity d) ~shifts:Common.tick_shifts
                ~domain_generator:Backend.Tick.Field.domain_generator
            in
            let checked_domain () =
              side_loaded_input_domain ~width:(Field.of_int i)
            in
            [%test_eq: Field.Constant.t]
              (d_unchecked#vanishing_polynomial pt)
              (run (fun () ->
                   (checked_domain ())#vanishing_polynomial (Field.constant pt))))

      let%test_unit "side loaded domains" =
        let module O = One_hot_vector.Make (Impl) in
        let open Side_loaded_verification_key in
        let branches = Nat.N2.n in
        let domains = Vector.[ { Domains.h = 10 }; { h = 15 } ] in
        let pt = Field.Constant.random () in
        List.iteri (Vector.to_list domains) ~f:(fun i ds ->
            let check field1 field2 =
              let d_unchecked =
                Plonk_checks.domain
                  (module Field.Constant)
                  (Pow_2_roots_of_unity (field1 ds))
                  ~shifts:Common.tick_shifts
                  ~domain_generator:Backend.Tick.Field.domain_generator
              in
              let checked_domain () =
                side_loaded_domains
                  (Vector.map domains
                     ~f:
                       (Domains.map ~f:(fun x ->
                            Domain.Pow_2_roots_of_unity (Field.of_int x))))
                  (O.of_index (Field.of_int i) ~length:branches)
                |> field2
              in
              [%test_eq: Field.Constant.t] d_unchecked#size
                (run (fun () -> (checked_domain ())#size)) ;
              [%test_eq: Field.Constant.t]
                (d_unchecked#vanishing_polynomial pt)
                (run (fun () ->
                     (checked_domain ())#vanishing_polynomial
                       (Field.constant pt)))
            in
            check Domains.h Domains.h)
    end )

  module Split_evaluations = struct
    open Plonk_types

    let mask' { Bounded.max; actual } : Boolean.var array =
      let (T max) = Nat.of_int max in
      Vector.to_array (ones_vector (module Impl) ~first_zero:actual max)

    let mask (type n) ~(lengths : (int, n) Vector.t)
        (choice : n One_hot_vector.T(Impl).t) : Boolean.var array =
      let max =
        Option.value_exn
          (List.max_elt ~compare:Int.compare (Vector.to_list lengths))
      in
      let actual = Pseudo.choose (choice, lengths) ~f:Field.of_int in
      mask' { max; actual }

    let last =
      Array.reduce_exn ~f:(fun (b_acc, x_acc) (b, x) ->
          (Boolean.(b_acc ||| b), Field.if_ b ~then_:x ~else_:x_acc))

    let rec pow x bits_lsb =
      with_label "pow" (fun () ->
          let rec go acc bs =
            match bs with
            | [] ->
                acc
            | b :: bs ->
                let acc = Field.square acc in
                let acc = Field.if_ b ~then_:Field.(x * acc) ~else_:acc in
                go acc bs
          in
          go Field.one (List.rev bits_lsb))

    let mod_max_degree =
      let k = Nat.to_int Backend.Tick.Rounds.n in
      fun d ->
        let d = Number.of_bits (Field.unpack ~length:max_log2_degree d) in
        Number.mod_pow_2 d (`Two_to_the k)

    let combine_split_evaluations' b_plus_26 =
      Pcs_batch.combine_split_evaluations ~last
        ~mul:(fun (keep, x) (y : Field.t) -> (keep, Field.(y * x)))
        ~mul_and_add:(fun ~acc ~xi (keep, fx) ->
          Field.if_ keep ~then_:Field.(fx + (xi * acc)) ~else_:acc)
        ~init:(fun (_, fx) -> fx)
        (Common.dlog_pcs_batch b_plus_26)
        ~shifted_pow:
          (Pseudo.Degree_bound.shifted_pow ~crs_max_degree:Max_degree.step)

    let combine_split_evaluations_side_loaded b_plus_26 =
      Pcs_batch.combine_split_evaluations ~last
        ~mul:(fun (keep, x) (y : Field.t) -> (keep, Field.(y * x)))
        ~mul_and_add:(fun ~acc ~xi (keep, fx) ->
          Field.if_ keep ~then_:Field.(fx + (xi * acc)) ~else_:acc)
        ~init:(fun (_, fx) -> fx)
        (Common.dlog_pcs_batch b_plus_26)
        ~shifted_pow:(fun deg x -> pow x deg)

    let mask_evals (type n) ~(lengths : (int, n) Vector.t Evals.t)
        (choice : n One_hot_vector.T(Impl).t) (e : Field.t array Evals.t) :
        (Boolean.var * Field.t) array Evals.t =
      Evals.map2 lengths e ~f:(fun lengths e ->
          Array.zip_exn (mask ~lengths choice) e)
  end

  let combined_evaluation (type b b_plus_26) b_plus_26 ~xi ~evaluation_point
      ((without_degree_bound : (_, b_plus_26) Vector.t), with_degree_bound)
      ~max_quot_size =
    let open Field in
    Pcs_batch.combine_split_evaluations ~mul
      ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
      ~shifted_pow:
        (Pseudo.Degree_bound.shifted_pow ~crs_max_degree:Max_degree.step)
      ~init:Fn.id ~evaluation_point ~xi
      (Common.dlog_pcs_batch b_plus_26)
      without_degree_bound with_degree_bound

  let absorb_field sponge x = Sponge.absorb sponge (`Field x)

  (* pt^{2^n} *)
  let pow2_pow (pt : Field.t) (n : int) : Field.t =
    with_label "pow2_pow" (fun () ->
        let rec go acc i =
          if i = 0 then acc else go (Field.square acc) (i - 1)
        in
        go pt n)

  let actual_evaluation (e : Field.t array) ~(pt_to_n : Field.t) : Field.t =
    with_label "actual_evaluation" (fun () ->
        match List.rev (Array.to_list e) with
        | e :: es ->
            List.fold ~init:e es ~f:(fun acc fx -> Field.(fx + (pt_to_n * acc)))
        | [] ->
            failwith "empty list")

  open Plonk_types

  module Opt_sponge = struct
    include Opt_sponge.Make (Impl) (Step_main_inputs.Sponge.Permutation)

    let squeeze_challenge sponge : Field.t =
      lowest_128_bits (squeeze sponge) ~constrain_low_bits:true
  end

  let shift1 =
    Shifted_value.Type1.Shift.(
      map ~f:Field.constant (create (module Field.Constant)))

  let shift2 =
    Shifted_value.Type2.Shift.(
      map ~f:Field.constant (create (module Field.Constant)))

  let%test_unit "endo scalar" =
    SC.test (module Impl) ~endo:Endo.Wrap_inner_curve.scalar

  module Plonk = Types.Wrap.Proof_state.Deferred_values.Plonk

  module Plonk_checks = struct
    include Plonk_checks
    include Plonk_checks.Make (Shifted_value.Type1) (Plonk_checks.Scalars.Tick)
  end

  (* This finalizes the "deferred values" coming from a previous proof over the same field.
     It
     1. Checks that [xi] and [r] where sampled correctly. I.e., by absorbing all the
     evaluation openings and then squeezing.
     2. Checks that the "combined inner product" value used in the elliptic curve part of
     the opening proof was computed correctly, in terms of the evaluation openings and the
     evaluation points.
     3. Check that the "b" value was computed correctly.
     4. Perform the arithmetic checks from marlin. *)
  (* TODO: This needs to handle the fact of variable length evaluations.
     Meaning it needs opt sponge. *)
  let finalize_other_proof (type b branches)
      (module Branching : Nat.Add.Intf with type n = b) ~max_width
      ~(step_domains :
         [ `Known of (Domains.t, branches) Vector.t
         | `Side_loaded of
           ( Field.t Side_loaded_verification_key.Domain.t
             Side_loaded_verification_key.Domains.t
           , branches )
           Vector.t ]) ~step_widths
      ~(* TODO: Add "actual branching" so that proofs don't
          carry around dummy "old bulletproof challenges" *)
      sponge ~(old_bulletproof_challenges : (_, b) Vector.t)
      ({ xi
       ; combined_inner_product
       ; bulletproof_challenges
       ; which_branch
       ; b
       ; plonk
       } :
        ( Field.t
        , _
        , Field.t Shifted_value.Type1.t
        , _
        , _
        , _ )
        Types.Wrap.Proof_state.Deferred_values.In_circuit.t)
      { Plonk_types.All_evals.ft_eval1
      ; evals =
          ( { evals = evals1; public_input = x_hat1 }
          , { evals = evals2; public_input = x_hat2 } )
      } =
    let open Vector in
    let step_domains, input_domain =
      with_label "step_domains" (fun () ->
          match step_domains with
          | `Known domains ->
              ( `Known domains
              , Pseudo.Domain.to_domain ~shifts ~domain_generator
                  (which_branch, Vector.map domains ~f:Domains.x) )
          | `Side_loaded ds ->
              ( `Side_loaded (side_loaded_domains ds which_branch)
              , (* This has to be the max_width of this proof system rather than actual width *)
                side_loaded_input_domain
                  ~width:
                    (Side_loaded_verification_key.Width.Checked.to_field
                       (Option.value_exn max_width)) ))
    in
    let actual_width = Pseudo.choose (which_branch, step_widths) ~f:Fn.id in
    let T = Branching.eq in
    (* You use the NEW bulletproof challenges to check b. Not the old ones. *)
    let absorb_evals x_hat e =
      with_label "absorb_evals" (fun () ->
          let xs, ys = Evals.to_vectors e in
          List.iter
            Vector.([| x_hat |] :: (to_list xs @ to_list ys))
            ~f:(Array.iter ~f:(fun x -> Sponge.absorb sponge (`Field x))))
    in
    (* A lot of hashing. *)
    absorb_evals x_hat1 evals1 ;
    absorb_evals x_hat2 evals2 ;
    Sponge.absorb sponge (`Field ft_eval1) ;
    let squeeze () = squeeze_challenge sponge in
    let xi_actual = squeeze () in
    let r_actual = squeeze () in
    let xi_correct =
      Field.equal xi_actual (match xi with { SC.SC.inner = xi } -> xi)
    in
    let scalar =
      SC.to_field_checked (module Impl) ~endo:Endo.Wrap_inner_curve.scalar
    in
    let plonk =
      Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.map_challenges
        ~f:Fn.id ~scalar plonk
    in
    let domain =
      match step_domains with
      | `Known ds ->
          let hs = map ds ~f:(fun { Domains.h; _ } -> h) in
          Pseudo.Domain.to_domain (which_branch, hs) ~shifts ~domain_generator
      | `Side_loaded { h } ->
          (h :> _ Plonk_checks.plonk_domain)
    in
    let zetaw = Field.mul domain#generator plonk.zeta in
    let xi = scalar xi in
    let r = scalar (SC.SC.create r_actual) in
    let plonk_minimal = Plonk.to_minimal plonk in
    let combined_evals =
      let n = Int.ceil_log2 Max_degree.step in
      let zeta_n : Field.t = pow2_pow plonk.zeta n in
      let zetaw_n : Field.t = pow2_pow zetaw n in
      ( Plonk_types.Evals.map ~f:(actual_evaluation ~pt_to_n:zeta_n) evals1
      , Plonk_types.Evals.map ~f:(actual_evaluation ~pt_to_n:zetaw_n) evals2 )
    in
    let env =
      with_label "scalars_env" (fun () ->
          Plonk_checks.scalars_env
            (module Field)
            ~srs_length_log2:Common.Max_degree.step_log2
            ~endo:(Impl.Field.constant Endo.Step_inner_curve.base)
            ~mds:sponge_params.mds
            ~field_of_hex:(fun s ->
              Kimchi_pasta.Pasta.Bigint256.of_hex_string s
              |> Kimchi_pasta.Pasta.Fp.of_bigint |> Field.constant)
            ~domain plonk_minimal combined_evals)
    in
    let open Field in
    let combined_inner_product_correct =
      let ft_eval0 : Field.t =
        with_label "ft_eval0" (fun () ->
            Plonk_checks.ft_eval0
              (module Field)
              ~env ~domain plonk_minimal combined_evals x_hat1)
      in
      print_fp "ft_eval0" ft_eval0 ;
      print_fp "ft_eval1" ft_eval1 ;
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      let actual_combined_inner_product =
        let sg_olds =
          with_label "sg_olds" (fun () ->
              Vector.map old_bulletproof_challenges ~f:(fun chals ->
                  unstage (b_poly (Vector.to_array chals))))
        in
        let combine ~ft pt x_hat e =
          let pi = Branching.add Nat.N26.n in
          let a, b = Evals.to_vectors (e : Field.t array Evals.t) in
          let sg_evals =
            Vector.map2
              (ones_vector (module Impl) ~first_zero:actual_width Branching.n)
              sg_olds
              ~f:(fun keep f -> [| (keep, f pt) |])
          in
          let v =
            Vector.append sg_evals
              (Vector.map
                 ([| x_hat |] :: [| ft |] :: a)
                 ~f:(Array.map ~f:(fun x -> (Boolean.true_, x))))
              (snd pi)
          in
          match step_domains with
          | `Known _ ->
              Split_evaluations.combine_split_evaluations' pi ~xi
                ~evaluation_point:pt v b
          | `Side_loaded _ ->
              Split_evaluations.combine_split_evaluations_side_loaded pi ~xi
                ~evaluation_point:pt v b
        in
        with_label "combine" (fun () ->
            combine ~ft:ft_eval0 plonk.zeta x_hat1 evals1
            + (r * combine ~ft:ft_eval1 zetaw x_hat2 evals2))
      in
      let expected =
        Shifted_value.Type1.to_field
          (module Field)
          ~shift:shift1 combined_inner_product
      in
      print_fp "step_main cip expected" expected ;
      print_fp "step_main cip actual" actual_combined_inner_product ;
      equal expected actual_combined_inner_product
    in
    let bulletproof_challenges =
      compute_challenges ~scalar bulletproof_challenges
    in
    let b_correct =
      with_label "b_correct" (fun () ->
          let b_poly =
            unstage (b_poly (Vector.to_array bulletproof_challenges))
          in
          let b_actual = b_poly plonk.zeta + (r * b_poly zetaw) in
          let b_used =
            Shifted_value.Type1.to_field (module Field) ~shift:shift1 b
          in
          equal b_used b_actual)
    in
    let plonk_checks_passed =
      with_label "plonk_checks_passed" (fun () ->
          Plonk_checks.checked
            (module Impl)
            ~env ~shift:shift1 plonk combined_evals)
    in
    print_bool "xi_correct" xi_correct ;
    print_bool "combined_inner_product_correct" combined_inner_product_correct ;
    print_bool "plonk_checks_passed" plonk_checks_passed ;
    print_bool "b_correct" b_correct ;
    ( Boolean.all
        [ xi_correct
        ; b_correct
        ; combined_inner_product_correct
        ; plonk_checks_passed
        ]
    , bulletproof_challenges )

  let hash_me_only (type s) ~index
      (state_to_field_elements : s -> Field.t array) =
    let open Types.Step.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter
        (Types.index_to_field_elements
           ~g:(fun (z : Inputs.Inner_curve.t) ->
             List.to_array (Inner_curve.to_field_elements z))
           index)
        ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
      sponge
    in
    stage (fun (t : _ Types.Step.Proof_state.Me_only.t) ->
        let sponge = Sponge.copy after_index in
        Array.iter
          ~f:(fun x -> Sponge.absorb sponge (`Field x))
          (to_field_elements_without_index t ~app_state:state_to_field_elements
             ~g:Inner_curve.to_field_elements) ;
        Sponge.squeeze_field sponge)

  let hash_me_only_opt (type s) ~index
      (state_to_field_elements : s -> Field.t array) =
    let open Types.Step.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter
        (Types.index_to_field_elements
           ~g:(fun (z : Inputs.Inner_curve.t) ->
             List.to_array (Inner_curve.to_field_elements z))
           index)
        ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
      sponge
    in
    stage (fun t ~widths ~max_width ~which_branch ->
        let mask =
          ones_vector
            (module Impl)
            max_width
            ~first_zero:(Pseudo.choose ~f:Fn.id (which_branch, widths))
        in
        let sponge = Sponge.copy after_index in
        let t =
          { t with
            old_bulletproof_challenges =
              Vector.map2 mask t.old_bulletproof_challenges ~f:(fun b v ->
                  Vector.map v ~f:(fun x -> `Opt (b, x)))
          ; sg = Vector.map2 mask t.sg ~f:(fun b g -> (b, g))
          }
        in
        let not_opt x = `Not_opt x in
        let hash_inputs =
          to_field_elements_without_index t
            ~app_state:
              (Fn.compose (Array.map ~f:not_opt) state_to_field_elements)
            ~g:(fun (b, g) ->
              List.map
                ~f:(fun x -> `Opt (b, x))
                (Inner_curve.to_field_elements g))
        in
        match
          Array.fold hash_inputs ~init:(`Not_opt sponge) ~f:(fun acc t ->
              match (acc, t) with
              | `Not_opt sponge, `Not_opt t ->
                  Sponge.absorb sponge (`Field t) ;
                  acc
              | `Not_opt sponge, `Opt t ->
                  let sponge = Opt_sponge.of_sponge sponge in
                  Opt_sponge.absorb sponge t ; `Opt sponge
              | `Opt sponge, `Opt t ->
                  Opt_sponge.absorb sponge t ; acc
              | `Opt _, `Not_opt _ ->
                  assert false)
        with
        | `Not_opt sponge ->
            (* This means there were no optional inputs. *)
            Sponge.squeeze_field sponge
        | `Opt sponge ->
            Opt_sponge.squeeze sponge)

  let accumulation_verifier
      (accumulator_verification_key : _ Types_map.For_step.t) prev_accumulators
      proof new_accumulator : Boolean.var =
    Boolean.false_

  let verify ~branching ~is_base_case ~sg_old
      ~(opening : _ Pickles_types.Plonk_types.Openings.Bulletproof.t) ~messages
      ~wrap_domain ~wrap_verification_key statement
      (unfinalized :
        ( _
        , _
        , _ Shifted_value.Type2.t
        , _
        , _
        , _ )
        Types.Step.Proof_state.Per_proof.In_circuit.t) =
    let public_input :
        [ `Field of Field.t | `Packed_bits of Field.t * int ] array =
      with_label "pack_statement" (fun () ->
          Spec.pack
            (module Impl)
            Types.Wrap.Statement.In_circuit.spec
            (Types.Wrap.Statement.In_circuit.to_data statement))
      |> Array.map ~f:(function
           | `Field (Shifted_value.Type1.Shifted_value x) ->
               `Field x
           | `Packed_bits (x, n) ->
               `Packed_bits (x, n))
    in
    let sponge = Sponge.create sponge_params in
    let { Types.Step.Proof_state.Deferred_values.xi; combined_inner_product; b }
        =
      unfinalized.deferred_values
    in
    let ( sponge_digest_before_evaluations_actual
        , (`Success bulletproof_success, bulletproof_challenges_actual) ) =
      incrementally_verify_proof branching ~domain:wrap_domain ~xi
        ~verification_key:wrap_verification_key ~sponge ~public_input ~sg_old
        ~combined_inner_product ~advice:{ b } ~messages ~openings_proof:opening
        ~plonk:unfinalized.deferred_values.plonk
    in
    with_label __LOC__ (fun () ->
        with_label __LOC__ (fun () ->
            Field.Assert.equal unfinalized.sponge_digest_before_evaluations
              sponge_digest_before_evaluations_actual) ;
        Array.iteri
          (Vector.to_array unfinalized.deferred_values.bulletproof_challenges)
          ~f:(fun i c1 ->
            let c2 = bulletproof_challenges_actual.(i) in
            let { Import.Scalar_challenge.inner = c1 } =
              c1.Bulletproof_challenge.prechallenge
            in
            let c2 =
              Field.if_ is_base_case ~then_:c1
                ~else_:(match c2.prechallenge with { inner = c2 } -> c2)
            in
            with_label (sprintf "%s:%d" __LOC__ i) (fun () ->
                Field.Assert.equal c1 c2))) ;
    bulletproof_success
end

include Make (Step_main_inputs)
