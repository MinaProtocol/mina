open Core_kernel
open Async_kernel
open Pickles_types

let tuple15_to_vec
    (w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14) =
  Vector.[ w0; w1; w2; w3; w4; w5; w6; w7; w8; w9; w10; w11; w12; w13; w14 ]

let tuple15_of_vec
    Vector.[ w0; w1; w2; w3; w4; w5; w6; w7; w8; w9; w10; w11; w12; w13; w14 ] =
  (w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14)

let tuple6_to_vec (w0, w1, w2, w3, w4, w5) = Vector.[ w0; w1; w2; w3; w4; w5 ]

let tuple6_of_vec Vector.[ w0; w1; w2; w3; w4; w5 ] = (w0, w1, w2, w3, w4, w5)

module type Stable_v1 = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version, bin_io, sexp, compare, yojson, hash, equal]
    end

    module Latest = V1
  end

  type t = Stable.V1.t [@@deriving sexp, compare, yojson, hash, equal]
end

module type Inputs_intf = sig
  open Intf

  val id : string

  module Scalar_field : sig
    include Stable_v1

    val one : t

    module Vector : Snarky_intf.Vector.S with type elt = t
  end

  module Base_field : sig
    type t
  end

  module Curve : sig
    module Affine : sig
      include Stable_v1 with type Stable.V1.t = Base_field.t * Base_field.t

      module Backend : sig
        type t = Base_field.t Kimchi_types.or_infinity
      end

      val of_backend :
        Backend.t -> (Base_field.t * Base_field.t) Pickles_types.Or_infinity.t

      val to_backend :
        (Base_field.t * Base_field.t) Pickles_types.Or_infinity.t -> Backend.t
    end
  end

  module Poly_comm : sig
    type t = Base_field.t Poly_comm.t

    module Backend : sig
      type t = Curve.Affine.Backend.t Kimchi_types.poly_comm
    end

    val of_backend_with_degree_bound : Backend.t -> t

    val of_backend_without_degree_bound : Backend.t -> t

    val to_backend : t -> Backend.t
  end

  module Opening_proof_backend : sig
    type t = (Curve.Affine.Backend.t, Scalar_field.t) Kimchi_types.opening_proof
  end

  module Evaluations_backend : sig
    type t = Scalar_field.t Kimchi_types.proof_evaluations
  end

  module Index : sig
    type t
  end

  module Verifier_index : sig
    type t
  end

  module Backend : sig
    type t = (Curve.Affine.Backend.t, Scalar_field.t) Kimchi_types.prover_proof

    val create :
         Index.t
      -> primary:Scalar_field.Vector.t
      -> auxiliary:Scalar_field.Vector.t
      -> prev_chals:Scalar_field.t array
      -> prev_comms:Curve.Affine.Backend.t array
      -> t

    val create_async :
         Index.t
      -> primary:Scalar_field.Vector.t
      -> auxiliary:Scalar_field.Vector.t
      -> prev_chals:Scalar_field.t array
      -> prev_comms:Curve.Affine.Backend.t array
      -> t Promise.t

    val create_and_verify_async :
         Index.t
      -> primary:Scalar_field.Vector.t
      -> auxiliary:Scalar_field.Vector.t
      -> prev_chals:Scalar_field.t array
      -> prev_comms:Curve.Affine.Backend.t array
      -> t Promise.t

    val verify : Verifier_index.t -> t -> bool

    val batch_verify : Verifier_index.t array -> t array -> bool Promise.t
  end
end

module Challenge_polynomial = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('g, 'fq) t = { challenges : 'fq array; commitment : 'g }
      [@@deriving version, bin_io, sexp, compare, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Backend = Backend
  module Fq = Scalar_field
  module G = Curve

  module Challenge_polynomial = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( G.Affine.Stable.V1.t
          , Fq.Stable.V1.t )
          Challenge_polynomial.Stable.V1.t
        [@@deriving sexp, compare, yojson]

        let to_latest = Fn.id
      end
    end]

    type ('g, 'fq) t_ = ('g, 'fq) Challenge_polynomial.t =
      { challenges : 'fq array; commitment : 'g }
  end

  type message = Challenge_polynomial.t list

  let hash_fold_array f s x = hash_fold_list f s (Array.to_list x)

  [%%versioned
  module Stable = struct
    module V2 = struct
      module T = struct
        type t =
          ( G.Affine.Stable.V1.t
          , Fq.Stable.V1.t
          , Fq.Stable.V1.t array )
          Pickles_types.Plonk_types.Proof.Stable.V2.t
        [@@deriving compare, sexp, yojson, hash, equal]

        let id = "plong_dlog_proof_" ^ Inputs.id

        type 'a creator =
             messages:G.Affine.t Pickles_types.Plonk_types.Messages.Stable.V2.t
          -> openings:
               ( G.Affine.t
               , Fq.t
               , Fq.t array )
               Pickles_types.Plonk_types.Openings.Stable.V2.t
          -> 'a

        let map_creator c ~f ~messages ~openings = f (c ~messages ~openings)

        let create ~messages ~openings =
          let open Pickles_types.Plonk_types.Proof.Stable.Latest in
          { messages; openings }
      end

      include T

      include (
        Allocation_functor.Make.Full
          (T) :
            Allocation_functor.Intf.Output.Full_intf
              with type t := t
               and type 'a creator := 'a creator )

      let to_latest = Fn.id
    end
  end]

  module T = struct
    type t = (G.Affine.t, Fq.t, Fq.t array) Pickles_types.Plonk_types.Proof.t
    [@@deriving compare, sexp, yojson, hash, equal]

    let id = "plong_dlog_proof_" ^ Inputs.id

    type 'a creator =
         messages:G.Affine.t Pickles_types.Plonk_types.Messages.t
      -> openings:
           (G.Affine.t, Fq.t, Fq.t array) Pickles_types.Plonk_types.Openings.t
      -> 'a

    let map_creator c ~f ~messages ~openings = f (c ~messages ~openings)

    let create ~messages ~openings =
      let open Pickles_types.Plonk_types.Proof in
      { messages; openings }
  end

  include T

  include (
    struct
      include Allocation_functor.Make.Basic (T)
      include Allocation_functor.Make.Partial.Sexp (T)
      include Allocation_functor.Make.Partial.Yojson (T)
    end :
      sig
        include
          Allocation_functor.Intf.Output.Basic_intf
            with type t := t
             and type 'a creator := 'a creator

        include
          Allocation_functor.Intf.Output.Sexp_intf
            with type t := t
             and type 'a creator := 'a creator

        include
          Allocation_functor.Intf.Output.Yojson_intf
            with type t := t
             and type 'a creator := 'a creator
      end )

  let g t f = G.Affine.of_backend (f t)

  let fq_array_to_vec arr =
    let vec = Fq.Vector.create () in
    Array.iter arr ~f:(fun fe -> Fq.Vector.emplace_back vec fe) ;
    vec

  (** Note that this function will panic if any of the points are points at
      infinity *)
  let opening_proof_of_backend_exn (t : Opening_proof_backend.t) =
    let g (x : G.Affine.Backend.t) : G.Affine.t =
      G.Affine.of_backend x |> Pickles_types.Or_infinity.finite_exn
    in
    let gpair ((g1, g2) : G.Affine.Backend.t * G.Affine.Backend.t) :
        G.Affine.t * G.Affine.t =
      (g g1, g g2)
    in
    { Pickles_types.Plonk_types.Openings.Bulletproof.lr =
        Array.map ~f:gpair t.lr
    ; z_1 = t.z1
    ; z_2 = t.z2
    ; delta = g t.delta
    ; challenge_polynomial_commitment = g t.sg
    }

  let eval_of_backend
      ({ w
       ; coefficients
       ; z
       ; s
       ; generic_selector
       ; poseidon_selector
       ; complete_add_selector
       ; mul_selector
       ; emul_selector
       ; endomul_scalar_selector
       ; range_check0_selector
       ; range_check1_selector
       ; foreign_field_add_selector
       ; foreign_field_mul_selector
       ; xor_selector
       ; rot_selector
       ; lookup_aggregation
       ; lookup_table
       ; lookup_sorted
       ; runtime_lookup_table
       ; runtime_lookup_table_selector
       ; xor_lookup_selector
       ; lookup_gate_lookup_selector
       ; range_check_lookup_selector
       ; foreign_field_mul_lookup_selector
       } :
        Evaluations_backend.t ) : _ Pickles_types.Plonk_types.Evals.t =
    { w = tuple15_to_vec w
    ; coefficients = tuple15_to_vec coefficients
    ; z
    ; s = tuple6_to_vec s
    ; generic_selector
    ; poseidon_selector
    ; complete_add_selector
    ; mul_selector
    ; emul_selector
    ; endomul_scalar_selector
    ; range_check0_selector
    ; range_check1_selector
    ; foreign_field_add_selector
    ; foreign_field_mul_selector
    ; xor_selector
    ; rot_selector
    ; lookup_aggregation
    ; lookup_table
    ; lookup_sorted =
        Vector.init Nat.N5.n ~f:(fun i ->
            Option.try_with_join (fun () -> lookup_sorted.(i)) )
    ; runtime_lookup_table
    ; runtime_lookup_table_selector
    ; xor_lookup_selector
    ; lookup_gate_lookup_selector
    ; range_check_lookup_selector
    ; foreign_field_mul_lookup_selector
    }

  let of_backend (t : Backend.t) : t =
    let proof = opening_proof_of_backend_exn t.proof in
    let evals =
      let evals_to_tuple
          ({ zeta; zeta_omega } : _ Kimchi_types.point_evaluations) =
        (zeta, zeta_omega)
      in
      Plonk_types.Evals.map ~f:evals_to_tuple (eval_of_backend t.evals)
    in
    let wo x : Inputs.Curve.Affine.t array =
      match Poly_comm.of_backend_without_degree_bound x with
      | `Without_degree_bound gs ->
          gs
      | _ ->
          assert false
    in
    let w_comm =
      tuple15_to_vec t.commitments.w_comm |> Pickles_types.Vector.map ~f:wo
    in
    create
      ~messages:
        { w_comm
        ; z_comm = wo t.commitments.z_comm
        ; t_comm = wo t.commitments.t_comm
        ; lookup =
            Option.map t.commitments.lookup
              ~f:(fun l : _ Pickles_types.Plonk_types.Messages.Lookup.t ->
                { sorted =
                    Vector.init
                      Pickles_types.Plonk_types.Lookup_sorted_minus_1.n
                      ~f:(fun i -> (* TODO: Fixme *) wo l.sorted.(i))
                ; sorted_5th_column =
                    (* TODO: This is ugly and error-prone *)
                    Option.try_with (fun () ->
                        wo
                          l.sorted.(Nat.to_int
                                      Pickles_types.Plonk_types
                                      .Lookup_sorted_minus_1
                                      .n) )
                ; aggreg = wo l.aggreg
                ; runtime = Option.map ~f:wo l.runtime
                } )
        }
      ~openings:{ proof; evals; ft_eval1 = t.ft_eval1 }

  let eval_to_backend
      { Pickles_types.Plonk_types.Evals.w
      ; coefficients
      ; z
      ; s
      ; generic_selector
      ; poseidon_selector
      ; complete_add_selector
      ; mul_selector
      ; emul_selector
      ; endomul_scalar_selector
      ; range_check0_selector
      ; range_check1_selector
      ; foreign_field_add_selector
      ; foreign_field_mul_selector
      ; xor_selector
      ; rot_selector
      ; lookup_aggregation
      ; lookup_table
      ; lookup_sorted
      ; runtime_lookup_table
      ; runtime_lookup_table_selector
      ; xor_lookup_selector
      ; lookup_gate_lookup_selector
      ; range_check_lookup_selector
      ; foreign_field_mul_lookup_selector
      } : Evaluations_backend.t =
    { w = tuple15_of_vec w
    ; coefficients = tuple15_of_vec coefficients
    ; z
    ; s = tuple6_of_vec s
    ; generic_selector
    ; poseidon_selector
    ; complete_add_selector
    ; mul_selector
    ; emul_selector
    ; endomul_scalar_selector
    ; range_check0_selector
    ; range_check1_selector
    ; foreign_field_add_selector
    ; foreign_field_mul_selector
    ; xor_selector
    ; rot_selector
    ; lookup_aggregation
    ; lookup_table
    ; lookup_sorted = Vector.to_array lookup_sorted
    ; runtime_lookup_table
    ; runtime_lookup_table_selector
    ; xor_lookup_selector
    ; lookup_gate_lookup_selector
    ; range_check_lookup_selector
    ; foreign_field_mul_lookup_selector
    }

  let vec_to_array (type t elt)
      (module V : Snarky_intf.Vector.S with type t = t and type elt = elt)
      (v : t) =
    Array.init (V.length v) ~f:(V.get v)

  let to_backend' (chal_polys : Challenge_polynomial.t list) primary_input
      ({ messages = { w_comm; z_comm; t_comm; lookup }
       ; openings =
           { proof = { lr; z_1; z_2; delta; challenge_polynomial_commitment }
           ; evals
           ; ft_eval1
           }
       } :
        t ) : Backend.t =
    let g x = G.Affine.to_backend (Pickles_types.Or_infinity.Finite x) in
    let pcwo t = Poly_comm.to_backend (`Without_degree_bound t) in
    let lr = Array.map lr ~f:(fun (x, y) -> (g x, g y)) in
    let evals_of_tuple (zeta, zeta_omega) : _ Kimchi_types.point_evaluations =
      { zeta; zeta_omega }
    in
    { commitments =
        { w_comm = tuple15_of_vec (Pickles_types.Vector.map ~f:pcwo w_comm)
        ; z_comm = pcwo z_comm
        ; t_comm = pcwo t_comm
        ; lookup =
            Option.map lookup ~f:(fun t : _ Kimchi_types.lookup_commitments ->
                { sorted =
                    Array.map ~f:pcwo
                      (Array.append (Vector.to_array t.sorted)
                         (Option.to_array t.sorted_5th_column) )
                ; aggreg = pcwo t.aggreg
                ; runtime = Option.map ~f:pcwo t.runtime
                } )
        }
    ; proof =
        { lr
        ; delta = g delta
        ; z1 = z_1
        ; z2 = z_2
        ; sg = g challenge_polynomial_commitment
        }
    ; evals = eval_to_backend (Plonk_types.Evals.map ~f:evals_of_tuple evals)
    ; ft_eval1
    ; public = primary_input
    ; prev_challenges =
        Array.of_list_map chal_polys
          ~f:(fun { Challenge_polynomial.commitment = x, y; challenges } ->
            { Kimchi_types.chals = challenges
            ; comm =
                { Kimchi_types.shifted = None
                ; unshifted = [| Kimchi_types.Finite (x, y) |]
                }
            } )
    }

  let to_backend chal_polys primary_input t =
    to_backend' chal_polys (List.to_array primary_input) t

  let create ?message pk ~primary ~auxiliary =
    let chal_polys =
      match (message : message option) with Some s -> s | None -> []
    in
    let challenges =
      List.map chal_polys ~f:(fun { Challenge_polynomial.challenges; _ } ->
          challenges )
      |> Array.concat
    in
    let commitments =
      Array.of_list_map chal_polys
        ~f:(fun { Challenge_polynomial.commitment; _ } ->
          G.Affine.to_backend (Finite commitment) )
    in
    let res =
      Backend.create pk ~primary ~auxiliary ~prev_chals:challenges
        ~prev_comms:commitments
    in
    of_backend res

  let create_async ?message pk ~primary ~auxiliary =
    let chal_polys =
      match (message : message option) with Some s -> s | None -> []
    in
    let challenges =
      List.map chal_polys ~f:(fun { Challenge_polynomial.challenges; _ } ->
          challenges )
      |> Array.concat
    in
    let commitments =
      Array.of_list_map chal_polys
        ~f:(fun { Challenge_polynomial.commitment; _ } ->
          G.Affine.to_backend (Finite commitment) )
    in
    let%map.Promise res =
      Backend.create_async pk ~primary ~auxiliary ~prev_chals:challenges
        ~prev_comms:commitments
    in
    of_backend res

  let create_and_verify_async ?message pk ~primary ~auxiliary =
    let chal_polys =
      match (message : message option) with Some s -> s | None -> []
    in
    let challenges =
      List.map chal_polys ~f:(fun { Challenge_polynomial.challenges; _ } ->
          challenges )
      |> Array.concat
    in
    let commitments =
      Array.of_list_map chal_polys
        ~f:(fun { Challenge_polynomial.commitment; _ } ->
          G.Affine.to_backend (Finite commitment) )
    in
    let%map.Promise res =
      Backend.create_and_verify_async pk ~primary ~auxiliary
        ~prev_chals:challenges ~prev_comms:commitments
    in
    of_backend res

  let batch_verify' (conv : 'a -> Fq.t array)
      (ts : (Verifier_index.t * t * 'a * message option) list) =
    let logger = Internal_tracing_context_logger.get () in
    [%log internal] "Batch_verify_backend_convert_inputs" ;
    let vks_and_v =
      Array.of_list_map ts ~f:(fun (vk, t, xs, m) ->
          let p = to_backend' (Option.value ~default:[] m) (conv xs) t in
          (vk, p) )
    in
    [%log internal] "Batch_verify_backend_convert_inputs_done" ;
    [%log internal] "Batch_verify_backend" ;
    let%map.Promise result =
      Backend.batch_verify
        (Array.map ~f:fst vks_and_v)
        (Array.map ~f:snd vks_and_v)
    in
    [%log internal] "Batch_verify_backend_done" ;
    result

  let batch_verify = batch_verify' (fun xs -> List.to_array xs)

  let verify ?message t vk xs : bool =
    Backend.verify vk
      (to_backend'
         (Option.value ~default:[] message)
         (vec_to_array (module Scalar_field.Vector) xs)
         t )
end
