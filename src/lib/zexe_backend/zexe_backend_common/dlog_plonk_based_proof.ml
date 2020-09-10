open Core_kernel
open Pickles_types

module type Stable_v1 = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version, bin_io, sexp, compare, yojson, hash, eq]
    end

    module Latest = V1
  end

  type t = Stable.V1.t [@@deriving sexp, compare, yojson]
end

module type Inputs_intf = sig
  open Intf

  module Scalar_field : sig
    include Stable_v1

    include Type_with_delete with type t := t

    val one : t

    module Vector : sig
      include Vector with type elt = t

      module Double : Double with type elt := t
    end
  end

  module Curve : sig
    module Affine : sig
      include Stable_v1

      module Backend : sig
        include Type_with_delete

        module Vector : Vector with type elt = t

        module Pair : Intf.Pair with type elt := t
      end

      val of_backend : Backend.t -> t

      val to_backend : t -> Backend.t
    end
  end

  module Poly_comm : sig
    type t = Curve.Affine.t Plonk_poly_comm.t

    module Backend : Type_with_delete

    val of_backend : Backend.t -> t

    val to_backend : t -> Backend.t
  end

  module Opening_proof_backend : sig
    type t

    val lr : t -> Curve.Affine.Backend.Pair.Vector.t

    val z1 : t -> Scalar_field.t

    val z2 : t -> Scalar_field.t

    val delta : t -> Curve.Affine.Backend.t

    val sg : t -> Curve.Affine.Backend.t
  end

  module Evaluations_backend : sig
    type t

    val make :
         Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> t

    val l_eval : t -> Scalar_field.Vector.t

    val r_eval : t -> Scalar_field.Vector.t

    val o_eval : t -> Scalar_field.Vector.t

    val z_eval : t -> Scalar_field.Vector.t

    val t_eval : t -> Scalar_field.Vector.t

    val f_eval : t -> Scalar_field.Vector.t

    val sigma1_eval : t -> Scalar_field.Vector.t

    val sigma2_eval : t -> Scalar_field.Vector.t
  
    module Double : Double with type elt := t
end

  module Index : sig
    type t
  end

  module Verifier_index : sig
    type t
  end

  module Backend : sig
    include Type_with_delete

    module Vector : Vector with type elt := t

    val make :
         Scalar_field.Vector.t

      -> Poly_comm.Backend.t
      -> Poly_comm.Backend.t
      -> Poly_comm.Backend.t
      -> Poly_comm.Backend.t
      -> Poly_comm.Backend.t

      -> Curve.Affine.Backend.Pair.Vector.t
      -> Scalar_field.t
      -> Scalar_field.t
      -> Curve.Affine.Backend.t
      -> Curve.Affine.Backend.t

      -> Evaluations_backend.t
      -> Evaluations_backend.t

      -> Scalar_field.Vector.t
      -> Curve.Affine.Backend.Vector.t
      -> t

    val create :
         Index.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Scalar_field.Vector.t
      -> Curve.Affine.Backend.Vector.t
      -> t

    val batch_verify : Verifier_index.t -> Vector.t -> bool

    val proof : t -> Opening_proof_backend.t

    val evals_nocopy : t -> Evaluations_backend.Double.t

    val l_comm : t -> Poly_comm.Backend.t

    val r_comm : t -> Poly_comm.Backend.t

    val o_comm : t -> Poly_comm.Backend.t

    val z_comm : t -> Poly_comm.Backend.t

    val t_comm : t -> Poly_comm.Backend.t
  end
end

module type S = sig end

module Challenge_polynomial = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('g, 'fq) t = {challenges: 'fq array; commitment: 'g}
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
      {challenges: 'fq array; commitment: 'g}
  end

  type message = Challenge_polynomial.t list

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        ( G.Affine.Stable.V1.t
        , Fq.Stable.V1.t
        , Fq.Stable.V1.t Dlog_plonk_types.Pc_array.Stable.V1.t )
        Dlog_plonk_types.Proof.Stable.V1.t
      [@@deriving compare, sexp, yojson, hash, eq]

      let to_latest = Fn.id
    end
  end]

  include Stable.Latest

  let g t f = G.Affine.of_backend (f t)

  let fq t f =
    let t = f t in
    Caml.Gc.finalise Fq.delete t ;
    t

  let fqv t f =
    let t = f t in
    Caml.Gc.finalise Fq.Vector.delete t ;
    Array.init (Fq.Vector.length t) (fun i -> Fq.Vector.get t i)

  let fq_array_to_vec arr =
    let vec = Fq.Vector.create () in
    Array.iter arr ~f:(fun fe -> Fq.Vector.emplace_back vec fe) ;
    Caml.Gc.finalise Fq.Vector.delete vec ;
    vec

  let g_array_to_vec arr =
    let module V = G.Affine.Backend.Vector in
    let vec = V.create () in
    Array.iter arr ~f:(fun fe -> V.emplace_back vec fe) ;
    Caml.Gc.finalise V.delete vec ;
    vec

  (* TODO: Leaky? *)
  let evalvec arr =
    let vec = Fq.Vector.create () in
    Array.iter arr ~f:(fun fe -> Fq.Vector.emplace_back vec fe) ;
    vec

  let gpair (type a) (t : a) (f : a -> G.Affine.Backend.Pair.t) :
      G.Affine.t * G.Affine.t =
    (* TODO: Leak? *)
    let t = f t in
    let g = G.Affine.of_backend in
    G.Affine.Backend.Pair.(g (f0 t), g (f1 t))

  let opening_proof_of_backend (t : Opening_proof_backend.t) =
    let fq = fq t in
    let g = g t in
    let open Opening_proof_backend in
    let lr =
      let v = lr t in
      Array.init (G.Affine.Backend.Pair.Vector.length v) (fun i ->
          gpair v (fun v -> G.Affine.Backend.Pair.Vector.get v i) )
    in
    { Dlog_plonk_types.Openings.Bulletproof.lr
    ; z_1= fq z1
    ; z_2= fq z2
    ; delta= g delta
    ; sg= g sg }

  (* TODO: Lots of leakage here. *)
  let of_backend (t : Backend.t) : t =
    let open Backend in
    let proof =
      (* TODO: Leaky?*)
      let t = proof t in
      opening_proof_of_backend t
    in
    let evals =
      let t = evals_nocopy t in
      Evaluations_backend.Double.(f0 t, f1 t)
      |> Tuple_lib.Double.map ~f:(fun e ->
             let open Evaluations_backend in
             let fqv = fqv e in
             { Dlog_plonk_types.Evals.l_eval= fqv l_eval
             ; r_eval= fqv r_eval
             ; o_eval= fqv o_eval
             ; z_eval= fqv z_eval
             ; t_eval= fqv t_eval
             ; f_eval= fqv f_eval
             ; sigma1_eval= fqv sigma1_eval
             ; sigma2_eval= fqv sigma2_eval } )
    in
    let pc f = Poly_comm.of_backend (f t) in
    let wo x =
      match pc x with `Without_degree_bound gs -> gs | _ -> assert false
    in
    let w x =
      match pc x with `With_degree_bound t -> t | _ -> assert false
    in
    { messages=
        { l_comm= wo l_comm
        ; r_comm= wo r_comm
        ; o_comm= wo o_comm
        ; z_comm= wo z_comm
        ; t_comm= w t_comm }
    ; openings= {proof; evals} }

  (* TODO: Leaky? *)
  let eval_to_backend
      { Dlog_plonk_types.Evals.l_eval
      ; r_eval
      ; o_eval
      ; z_eval
      ; t_eval
      ; f_eval
      ; sigma1_eval
      ; sigma2_eval } =
    Evaluations_backend.make (evalvec l_eval) (evalvec r_eval)
      (evalvec o_eval) (evalvec z_eval) (evalvec t_eval) (evalvec f_eval) (evalvec sigma1_eval)
      (evalvec sigma2_eval)

  let field_vector_of_list xs =
    let v = Fq.Vector.create () in
    List.iter ~f:(Fq.Vector.emplace_back v) xs ;
    v

  let vec_to_array (type t elt)
      (module V : Intf.Vector with type t = t and type elt = elt) (v : t) =
    Array.init (V.length v) ~f:(V.get v)

  let to_backend' (chal_polys : Challenge_polynomial.t list) primary_input
      ({ messages=
           { l_comm= l_comm
           ; r_comm= r_comm
           ; o_comm= o_comm
           ; z_comm= z_comm
           ; t_comm= t_comm }
       ; openings=
           {proof= {lr; z_1; z_2; delta; sg}; evals= evals0, evals1} } :
        t) : Backend.t =
    let g = G.Affine.to_backend in
    let pcw t = Poly_comm.to_backend (`With_degree_bound t) in
    let pcwo t = Poly_comm.to_backend (`Without_degree_bound t) in
    let lr =
      let v = G.Affine.Backend.Pair.Vector.create () in
      Array.iter lr ~f:(fun (l, r) ->
          (* Very leaky *)
          G.Affine.Backend.Pair.Vector.emplace_back v
            (G.Affine.Backend.Pair.make (g l) (g r)) ) ;
      v
    in
    let challenges =
      List.map chal_polys
        ~f:(fun {Challenge_polynomial.challenges; commitment= _} -> challenges)
      |> Array.concat |> fq_array_to_vec
    in
    let commitments =
      Array.of_list_map chal_polys
        ~f:(fun {Challenge_polynomial.commitment; challenges= _} ->
          G.Affine.to_backend commitment )
      |> g_array_to_vec
    in
    Backend.make primary_input (pcwo l_comm) (pcwo r_comm) (pcwo o_comm)
      (pcwo z_comm) (pcw t_comm) lr z_1 z_2 (g delta) (g sg)
      (* Leaky! *)
      (eval_to_backend evals0)
      (eval_to_backend evals1) challenges commitments

  let to_backend chal_polys primary_input t =
    to_backend' chal_polys (field_vector_of_list primary_input) t

  let create ?message pk ~primary ~auxiliary =
    let chal_polys =
      match (message : message option) with Some s -> s | None -> []
    in
    let challenges =
      List.map chal_polys ~f:(fun {Challenge_polynomial.challenges; _} ->
          challenges )
      |> Array.concat |> fq_array_to_vec
    in
    let commitments =
      Array.of_list_map chal_polys
        ~f:(fun {Challenge_polynomial.commitment; _} ->
          G.Affine.to_backend commitment )
      |> g_array_to_vec
    in
    let res = Backend.create pk primary auxiliary challenges commitments in
    let t = of_backend res in
    Backend.delete res ; t

  let batch_verify' (conv : 'a -> Fq.Vector.t)
      (ts : (t * 'a * message option) list) (vk : Verifier_index.t) =
    let v = Backend.Vector.create () in
    List.iter ts ~f:(fun (t, xs, m) ->
        let p = to_backend' (Option.value ~default:[] m) (conv xs) t in
        Backend.Vector.emplace_back v p ;
        Backend.delete p ) ;
    let res = Backend.batch_verify vk v in
    Backend.Vector.delete v ; res

  let batch_verify =
    batch_verify' (fun xs -> field_vector_of_list (Fq.one :: xs))

  let verify ?message t vk (xs : Fq.Vector.t) : bool =
    batch_verify'
      (fun xs ->
        let v = Fq.Vector.create () in
        Fq.Vector.emplace_back v Fq.one ;
        for i = 0 to Fq.Vector.length xs - 1 do
          Fq.Vector.emplace_back v (Fq.Vector.get xs i)
        done ;
        v )
      [(t, xs, message)] vk
end
