module type Inputs_intf = sig
  open Intf

  val name : string

  module Rounds : Pickles_types.Nat.Intf

  module Gate_vector : T0

  module Urs : sig
    type t

    val read : string -> t

    val write : t -> string -> unit

    val create :
      Unsigned.Size_t.t -> Unsigned.Size_t.t -> Unsigned.Size_t.t -> t
  end

  module Index : sig
    type t

    val delete : t -> unit

    val create : Gate_vector.t -> Unsigned.Size_t.t -> Urs.t -> t
  end

  module Curve : sig
    module Affine : sig
      type t
    end
  end

  module Poly_comm : sig
    module Backend : T0

    type t = Curve.Affine.t Poly_comm.t

    val of_backend : Backend.t -> t
  end

  module Scalar_field : T0

  module Verifier_index : sig
    type t

    val create : Index.t -> t

    val sigma_comm_0 : t -> Poly_comm.Backend.t

    val sigma_comm_1 : t -> Poly_comm.Backend.t

    val sigma_comm_2 : t -> Poly_comm.Backend.t

    val ql_comm : t -> Poly_comm.Backend.t

    val qr_comm : t -> Poly_comm.Backend.t

    val qo_comm : t -> Poly_comm.Backend.t

    val qm_comm : t -> Poly_comm.Backend.t

    val qc_comm : t -> Poly_comm.Backend.t

    val rcm_comm_0 : t -> Poly_comm.Backend.t

    val rcm_comm_1 : t -> Poly_comm.Backend.t

    val rcm_comm_2 : t -> Poly_comm.Backend.t

    val psm_comm : t -> Poly_comm.Backend.t

    val add_comm : t -> Poly_comm.Backend.t

    val mul1_comm : t -> Poly_comm.Backend.t

    val mul2_comm : t -> Poly_comm.Backend.t

    val emul1_comm : t -> Poly_comm.Backend.t

    val emul2_comm : t -> Poly_comm.Backend.t

    val emul3_comm : t -> Poly_comm.Backend.t

    val r : t -> Scalar_field.t

    val o : t -> Scalar_field.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Core_kernel
  open Inputs

  type t = Index.t

  include Dlog_urs.Make (struct
    include Inputs

    let public_inputs = lazy (failwith "TODO")

    let size = lazy (failwith "TODO")
  end)

  let create constraint_system =
    (* TODO: Make this flexible. *)
    let max_poly_size = 1 lsl Pickles_types.Nat.to_int Rounds.n in
    Index.create constraint_system
      (Unsigned.Size_t.of_int max_poly_size)
      (load_urs ())

  let vk t = Verifier_index.create t

  let pk = Fn.id

  open Pickles_types

  let vk_commitments t :
      ( Curve.Affine.t Dlog_marlin_types.Poly_comm.Without_degree_bound.t
      , Scalar_field.t )
      Plonk_verification_key_evals.t =
    let f (t : Poly_comm.Backend.t) =
      match Poly_comm.of_backend t with
      | `Without_degree_bound a ->
          a
      | _ ->
          assert false
    in
    let open Verifier_index in
    { sigma_comm_0= f (sigma_comm_0 t)
    ; sigma_comm_1= f (sigma_comm_1 t)
    ; sigma_comm_2= f (sigma_comm_2 t)
    ; ql_comm= f (ql_comm t)
    ; qr_comm= f (qr_comm t)
    ; qo_comm= f (qo_comm t)
    ; qm_comm= f (qm_comm t)
    ; qc_comm= f (qc_comm t)
    ; rcm_comm_0= f (rcm_comm_0 t)
    ; rcm_comm_1= f (rcm_comm_1 t)
    ; rcm_comm_2= f (rcm_comm_2 t)
    ; psm_comm= f (psm_comm t)
    ; add_comm= f (add_comm t)
    ; mul1_comm= f (mul1_comm t)
    ; mul2_comm= f (mul2_comm t)
    ; emul1_comm= f (emul1_comm t)
    ; emul2_comm= f (emul2_comm t)
    ; emul3_comm= f (emul3_comm t)
    ; r= r t
    ; o= o t }
end
