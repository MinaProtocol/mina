module Poly_comm0 = Poly_comm
open Unsigned.Size_t

module type Stable_v1 = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version, bin_io, sexp, compare, yojson, hash, equal]
    end

    module Latest = V1
  end

  type t = Stable.V1.t [@@deriving sexp, compare, yojson]
end

module type Inputs_intf = sig
  open Intf

  val name : string

  module Rounds : Pickles_types.Nat.Intf

  module Gate_vector : sig
    open Unsigned

    type t

    val wrap : t -> Kimchi.Protocol.wire -> Kimchi.Protocol.wire -> unit
  end

  module Urs : sig
    type t

    val read : int option -> string -> t option

    val write : bool option -> t -> string -> unit

    val create : int -> t
  end

  module Scalar_field : sig
    include Stable_v1

    val one : t
  end

  module Constraint_system : sig
    type t = (Gate_vector.t, Scalar_field.t) Plonk_constraint_system.t

    val finalize_and_get_gates : t -> Gate_vector.t
  end

  module Index : sig
    type t

    val create : Gate_vector.t -> int -> Urs.t -> t
  end

  module Curve : sig
    module Base_field : sig
      type t
    end

    module Affine : sig
      type t = Base_field.t * Base_field.t
    end
  end

  module Poly_comm : sig
    module Backend : sig
      type t
    end

    type t = Curve.Base_field.t Poly_comm0.t

    val of_backend_without_degree_bound : Backend.t -> t
  end

  module Verifier_index : sig
    type t =
      ( Scalar_field.t
      , Urs.t
      , Poly_comm.Backend.t )
      Kimchi.Protocol.VerifierIndex.verifier_index

    val create : Index.t -> t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Core_kernel

  type t =
    { index : Inputs.Index.t
    ; cs :
        (Inputs.Gate_vector.t, Inputs.Scalar_field.t) Plonk_constraint_system.t
    }

  let name =
    sprintf "%s_%d_v4" Inputs.name (Pickles_types.Nat.to_int Inputs.Rounds.n)

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let degree = 1 lsl Pickles_types.Nat.to_int Inputs.Rounds.n in
    let set_urs_info specs = Set_once.set_exn urs_info Lexing.dummy_pos specs in
    let load () =
      match !urs with
      | Some urs ->
          urs
      | None ->
          let specs =
            match Set_once.get urs_info with
            | None ->
                failwith "Dlog_based.urs: Info not set"
            | Some t ->
                t
          in
          let store =
            Key_cache.Sync.Disk_storable.simple
              (fun () -> name)
              (fun () ~path ->
                Or_error.try_with_join (fun () ->
                    match Inputs.Urs.read None path with
                    | Some urs ->
                        Ok urs
                    | None ->
                        Or_error.errorf
                          "Could not read the URS from disk; its format did \
                           not match the expected format"))
              (fun _ urs path ->
                Or_error.try_with (fun () -> Inputs.Urs.write None urs path))
          in
          let u =
            match Key_cache.Sync.read specs store () with
            | Ok (u, _) ->
                u
            | Error _e ->
                let urs = Inputs.Urs.create degree in
                let (_ : (unit, Error.t) Result.t) =
                  Key_cache.Sync.write
                    (List.filter specs ~f:(function
                      | On_disk _ ->
                          true
                      | S3 _ ->
                          false))
                    store () urs
                in
                urs
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)

  let create cs =
    let gates = Inputs.Constraint_system.finalize_and_get_gates cs in
    let public_input_size = Set_once.get_exn cs.public_input_size [%here] in
    let index = Inputs.Index.create gates public_input_size (load_urs ()) in
    { index; cs }

  let vk t = Inputs.Verifier_index.create t.index

  let pk t = t

  let array_to_vector a = Pickles_types.Vector.of_list (Array.to_list a)

  (*
  let pickles_verification_evals_of_backend
      (t :
        Inputs.Poly_comm.Backend.t
        Kimchi.Protocol.VerifierIndex.verification_evals) :
      Inputs.Curve.Affine.t
      Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
      Pickles_types.Plonk_verification_key_evals.t =
    let array_to_vector7 a =
      Pickles_types.Vector.of_array_and_length_exn a Pickles_types.Nat.N7.n
    in
    let array_to_vector15 a =
      Pickles_types.Vector.of_array_and_length_exn a Pickles_types.Nat.N15.n
    in
    let inin : Inputs.Poly_comm.Backend.t array = t.sigma_comm in
    let sigma_comm :
        Inputs.Curve.Affine.t
        Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
        Pickles_types.Dlog_plonk_types.Permuts_vec.Stable.V1.t =
      Array.map inin ~f:Inputs.Poly_comm.of_backend_without_degree_bound
      |> array_to_vector7
    in
    { sigma_comm
    ; coefficients_comm =
        Array.map t.coefficients_comm
          ~f:Inputs.Poly_comm.of_backend_without_degree_bound
        |> array_to_vector15
    ; generic_comm =
        Inputs.Poly_comm.of_backend_without_degree_bound t.generic_comm
    ; psm_comm = Inputs.Poly_comm.of_backend_without_degree_bound t.psm_comm
    ; complete_add_comm =
        Inputs.Poly_comm.of_backend_without_degree_bound t.complete_add_comm
    ; mul_comm = Inputs.Poly_comm.of_backend_without_degree_bound t.mul_comm
    ; emul_comm = Inputs.Poly_comm.of_backend_without_degree_bound t.emul_comm
    }

    *)

  (** does this convert a backend.verifier_index to a pickles_types.verifier_index? *)
  let vk_commitments (t : Inputs.Verifier_index.t) :
      Inputs.Curve.Affine.t Pickles_types.Plonk_verification_key_evals.t =
    let g c : Inputs.Curve.Affine.t =
      match Inputs.Poly_comm.of_backend_without_degree_bound c with
      | `Without_degree_bound x ->
          x.(0)
      | `With_degree_bound _ ->
          assert false
    in
    { sigma_comm =
        Pickles_types.Vector.init Pickles_types.Dlog_plonk_types.Permuts.n
          ~f:(fun i -> g t.evals.sigma_comm.(i))
    ; coefficients_comm =
        Pickles_types.Vector.init Pickles_types.Dlog_plonk_types.Columns.n
          ~f:(fun i -> g t.evals.coefficients_comm.(i))
    ; generic_comm = g t.evals.generic_comm
    ; psm_comm = g t.evals.psm_comm
    ; complete_add_comm = g t.evals.complete_add_comm
    ; mul_comm = g t.evals.mul_comm
    ; emul_comm = g t.evals.emul_comm
    ; endomul_scalar_comm = g t.evals.endomul_scalar_comm
    }

  (*
    let f (t : Inputs.Poly_comm.Backend.t) =
      match Inputs.Poly_comm.of_backend_without_degree_bound t with
      | `Without_degree_bound a ->
          a
      | _ ->
          assert false
    in
    let evals = pickles_verification_evals_of_backend t.evals in
    Pickles_types.Plonk_verification_key_evals.map ~f evals
    *)

  (*
    let f (t : Inputs.Poly_comm.Backend.t) =
      match Inputs.Poly_comm.of_backend_without_degree_bound t with
      | `Without_degree_bound a ->
          a
      | _ ->
          assert false
    in
    let pickles_types_evals :
        Inputs.Curve.Affine.t
        Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
        Pickles_types.Plonk_verification_key_evals.t =
      Pickles_types.Plonk_verification_key_evals.
        { sigma_comm = failwith "Hey" (* t.evals.sigma_comm *)
        ; coefficients_comm = failwith "Hey" (* t.evals.coefficients_comm *)
        ; generic_comm = failwith "Hey" (*t.evals.generic_comm*)
        ; psm_comm = failwith "Hey" (*t.evals.psm_comm*)
        ; complete_add_comm = failwith "Hey" (*t.evals.complete_add_comm*)
        ; mul_comm = failwith "Hey" (*t.evals.mul_comm*)
        ; emul_comm = failwith "Hey" (*t.evals.emul_comm*)
        }
    in
    (*
      { sigma_comm : 'comm Dlog_plonk_types.Permuts_vec.Stable.V1.t
      ; coefficients_comm : 'comm Dlog_plonk_types.Columns_vec.Stable.V1.t
      ; generic_comm : 'comm
      ; psm_comm : 'comm
      ; complete_add_comm : 'comm
      ; mul_comm : 'comm
      ; emul_comm : 'comm
      }
      *)
    Pickles_types.Plonk_verification_key_evals.map ~f pickles_types_evals
    *)
end
