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

      module Triple : Triple with type elt := t
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
    type t = Curve.Affine.t Poly_comm.t

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
         w:Scalar_field.Vector.t
      -> za:Scalar_field.Vector.t
      -> zb:Scalar_field.Vector.t
      -> h1:Scalar_field.Vector.t
      -> g1:Scalar_field.Vector.t
      -> h2:Scalar_field.Vector.t
      -> g2:Scalar_field.Vector.t
      -> h3:Scalar_field.Vector.t
      -> g3:Scalar_field.Vector.t
      -> row_0:Scalar_field.Vector.t
      -> row_1:Scalar_field.Vector.t
      -> row_2:Scalar_field.Vector.t
      -> col_0:Scalar_field.Vector.t
      -> col_1:Scalar_field.Vector.t
      -> col_2:Scalar_field.Vector.t
      -> val_0:Scalar_field.Vector.t
      -> val_1:Scalar_field.Vector.t
      -> val_2:Scalar_field.Vector.t
      -> rc_0:Scalar_field.Vector.t
      -> rc_1:Scalar_field.Vector.t
      -> rc_2:Scalar_field.Vector.t
      -> t

    val w : t -> Scalar_field.Vector.t

    val za : t -> Scalar_field.Vector.t

    val zb : t -> Scalar_field.Vector.t

    val h1 : t -> Scalar_field.Vector.t

    val g1 : t -> Scalar_field.Vector.t

    val h2 : t -> Scalar_field.Vector.t

    val g2 : t -> Scalar_field.Vector.t

    val h3 : t -> Scalar_field.Vector.t

    val g3 : t -> Scalar_field.Vector.t

    val row_nocopy : t -> Scalar_field.Vector.Triple.t

    val col_nocopy : t -> Scalar_field.Vector.Triple.t

    val val_nocopy : t -> Scalar_field.Vector.Triple.t

    val rc_nocopy : t -> Scalar_field.Vector.Triple.t

    module Triple : Triple with type elt := t
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
         primary_input:Scalar_field.Vector.t
      -> w_comm:Poly_comm.Backend.t
      -> za_comm:Poly_comm.Backend.t
      -> zb_comm:Poly_comm.Backend.t
      -> h1_comm:Poly_comm.Backend.t
      -> g1_comm:Poly_comm.Backend.t
      -> h2_comm:Poly_comm.Backend.t
      -> g2_comm:Poly_comm.Backend.t
      -> h3_comm:Poly_comm.Backend.t
      -> g3_comm:Poly_comm.Backend.t
      -> sigma2:Scalar_field.t
      -> sigma3:Scalar_field.t
      -> lr:Curve.Affine.Backend.Pair.Vector.t
      -> z1:Scalar_field.t
      -> z2:Scalar_field.t
      -> delta:Curve.Affine.Backend.t
      -> sg:Curve.Affine.Backend.t
      -> evals0:Evaluations_backend.t
      -> evals1:Evaluations_backend.t
      -> evals2:Evaluations_backend.t
      -> prev_challenges:Scalar_field.Vector.t
      -> prev_sgs:Curve.Affine.Backend.Vector.t
      -> t

    val create :
         index:Index.t
      -> primary_input:Scalar_field.Vector.t
      -> auxiliary_input:Scalar_field.Vector.t
      -> prev_challenges:Scalar_field.Vector.t
      -> prev_sgs:Curve.Affine.Backend.Vector.t
      -> t

    val batch_verify : Verifier_index.t -> Vector.t -> bool

    val proof : t -> Opening_proof_backend.t

    val evals_nocopy : t -> Evaluations_backend.Triple.t

    val w_comm : t -> Poly_comm.Backend.t

    val za_comm : t -> Poly_comm.Backend.t

    val zb_comm : t -> Poly_comm.Backend.t

    val h1_comm : t -> Poly_comm.Backend.t

    val h2_comm : t -> Poly_comm.Backend.t

    val h3_comm : t -> Poly_comm.Backend.t

    val g1_comm_nocopy : t -> Poly_comm.Backend.t

    val g2_comm_nocopy : t -> Poly_comm.Backend.t

    val g3_comm_nocopy : t -> Poly_comm.Backend.t

    val sigma2 : t -> Scalar_field.t

    val sigma3 : t -> Scalar_field.t
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
        , Fq.Stable.V1.t Dlog_marlin_types.Pc_array.Stable.V1.t )
        Dlog_marlin_types.Proof.Stable.V1.t
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
    { Dlog_marlin_types.Openings.Bulletproof.lr
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
      Evaluations_backend.Triple.(f0 t, f1 t, f2 t)
      |> Tuple_lib.Triple.map ~f:(fun e ->
             let open Evaluations_backend in
             let abc trip =
               let t = trip e in
               let fqv = fqv t in
               let open Fq.Vector.Triple in
               {Abc.a= fqv f0; b= fqv f1; c= fqv f2}
             in
             let fqv = fqv e in
             { Dlog_marlin_types.Evals.w_hat= fqv w
             ; z_hat_a= fqv za
             ; z_hat_b= fqv zb
             ; h_1= fqv h1
             ; h_2= fqv h2
             ; h_3= fqv h3
             ; row= abc row_nocopy
             ; col= abc col_nocopy
             ; value= abc val_nocopy
             ; rc= abc rc_nocopy
             ; g_1= fqv g1
             ; g_2= fqv g2
             ; g_3= fqv g3 } )
    in
    let fq = fq t in
    let pc f = Poly_comm.of_backend (f t) in
    let wo x =
      match pc x with `Without_degree_bound gs -> gs | _ -> assert false
    in
    let w x =
      match pc x with `With_degree_bound t -> t | _ -> assert false
    in
    { messages=
        { w_hat= wo w_comm
        ; z_hat_a= wo za_comm
        ; z_hat_b= wo zb_comm
        ; gh_1= (w g1_comm_nocopy, wo h1_comm)
        ; sigma_gh_2= (fq sigma2, (w g2_comm_nocopy, wo h2_comm))
        ; sigma_gh_3= (fq sigma3, (w g3_comm_nocopy, wo h3_comm)) }
    ; openings= {proof; evals} }

  (* TODO: Leaky? *)
  let eval_to_backend
      { Dlog_marlin_types.Evals.w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; row= {a= row_a; b= row_b; c= row_c}
      ; col= {a= col_a; b= col_b; c= col_c}
      ; value= {a= value_a; b= value_b; c= value_c}
      ; rc= {a= rc_a; b= rc_b; c= rc_c}
      ; g_1
      ; g_2
      ; g_3 } =
    Evaluations_backend.make (evalvec w_hat) (evalvec z_hat_a)
      (evalvec z_hat_b) (evalvec h_1) (evalvec g_1) (evalvec h_2) (evalvec g_2)
      (evalvec h_3) (evalvec g_3) (evalvec row_a) (evalvec row_b)
      (evalvec row_c) (evalvec col_a) (evalvec col_b) (evalvec col_c)
      (evalvec value_a) (evalvec value_b) (evalvec value_c) (evalvec rc_a)
      (evalvec rc_b) (evalvec rc_c)

  let field_vector_of_list xs =
    let v = Fq.Vector.create () in
    List.iter ~f:(Fq.Vector.emplace_back v) xs ;
    v

  let vec_to_array (type t elt)
      (module V : Intf.Vector with type t = t and type elt = elt) (v : t) =
    Array.init (V.length v) ~f:(V.get v)

  let to_backend' (chal_polys : Challenge_polynomial.t list) primary_input
      ({ messages=
           { w_hat= w_comm
           ; z_hat_a= za_comm
           ; z_hat_b= zb_comm
           ; gh_1= g1_comm, h1_comm
           ; sigma_gh_2= sigma2, (g2_comm, h2_comm)
           ; sigma_gh_3= sigma3, (g3_comm, h3_comm) }
       ; openings=
           {proof= {lr; z_1; z_2; delta; sg}; evals= evals0, evals1, evals2} } :
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
    Backend.make primary_input (pcwo w_comm) (pcwo za_comm) (pcwo zb_comm)
      (pcwo h1_comm) (pcw g1_comm) (pcwo h2_comm) (pcw g2_comm) (pcwo h3_comm)
      (pcw g3_comm) sigma2 sigma3 lr z_1 z_2 (g delta) (g sg)
      (* Leaky! *)
      (eval_to_backend evals0)
      (eval_to_backend evals1) (eval_to_backend evals2) challenges commitments

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
