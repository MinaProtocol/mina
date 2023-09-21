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

    val wrap : t -> Kimchi_types.wire -> Kimchi_types.wire -> unit
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
    type t

    val get_primary_input_size : t -> int

    val get_prev_challenges : t -> int option

    val set_prev_challenges : t -> int -> unit

    val finalize_and_get_gates :
         t
      -> Gate_vector.t
         * Scalar_field.t Kimchi_types.lookup_table array
         * Scalar_field.t Kimchi_types.runtime_table_cfg array
  end

  module Index : sig
    type t

    (** [create
          gates
          nb_public
          runtime_tables_cfg
          nb_prev_challanges
          srs] *)
    val create :
         Gate_vector.t
      -> int
      -> Scalar_field.t Kimchi_types.lookup_table array
      -> Scalar_field.t Kimchi_types.runtime_table_cfg array
      -> int
      -> Urs.t
      -> t
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
      Kimchi_types.VerifierIndex.verifier_index

    val create : Index.t -> t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Core_kernel

  type t = { index : Inputs.Index.t; cs : Inputs.Constraint_system.t }

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
                           not match the expected format" ) )
              (fun _ urs path ->
                Or_error.try_with (fun () -> Inputs.Urs.write None urs path) )
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
                          false ) )
                    store () urs
                in
                urs
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)

  let create ~prev_challenges cs =
    let gates, fixed_lookup_tables, runtime_table_cfgs =
      Inputs.Constraint_system.finalize_and_get_gates cs
    in
    let public_input_size =
      Inputs.Constraint_system.get_primary_input_size cs
    in
    let prev_challenges =
      match Inputs.Constraint_system.get_prev_challenges cs with
      | None ->
          Inputs.Constraint_system.set_prev_challenges cs prev_challenges ;
          prev_challenges
      | Some prev_challenges' ->
          assert (prev_challenges = prev_challenges') ;
          prev_challenges'
    in
    let index =
      Inputs.Index.create gates public_input_size fixed_lookup_tables
        runtime_table_cfgs prev_challenges (load_urs ())
    in
    { index; cs }

  let vk t = Inputs.Verifier_index.create t.index

  let pk t = t

  let array_to_vector a = Pickles_types.Vector.of_list (Array.to_list a)

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
        Pickles_types.Vector.init Pickles_types.Plonk_types.Permuts.n
          ~f:(fun i -> g t.evals.sigma_comm.(i))
    ; coefficients_comm =
        Pickles_types.Vector.init Pickles_types.Plonk_types.Columns.n
          ~f:(fun i -> g t.evals.coefficients_comm.(i))
    ; generic_comm = g t.evals.generic_comm
    ; psm_comm = g t.evals.psm_comm
    ; complete_add_comm = g t.evals.complete_add_comm
    ; mul_comm = g t.evals.mul_comm
    ; emul_comm = g t.evals.emul_comm
    ; endomul_scalar_comm = g t.evals.endomul_scalar_comm
    }

  let full_vk_commitments (t : Inputs.Verifier_index.t) :
      ( Inputs.Curve.Affine.t
      , Inputs.Curve.Affine.t option )
      Pickles_types.Plonk_verification_key_evals.Step.t =
    let g c : Inputs.Curve.Affine.t =
      match Inputs.Poly_comm.of_backend_without_degree_bound c with
      | `Without_degree_bound x ->
          x.(0)
      | `With_degree_bound _ ->
          assert false
    in
    let lookup f =
      let open Option.Let_syntax in
      let%bind l = t.lookup_index in
      f l >>| g
    in
    { sigma_comm =
        Pickles_types.Vector.init Pickles_types.Plonk_types.Permuts.n
          ~f:(fun i -> g t.evals.sigma_comm.(i))
    ; coefficients_comm =
        Pickles_types.Vector.init Pickles_types.Plonk_types.Columns.n
          ~f:(fun i -> g t.evals.coefficients_comm.(i))
    ; generic_comm = g t.evals.generic_comm
    ; psm_comm = g t.evals.psm_comm
    ; complete_add_comm = g t.evals.complete_add_comm
    ; mul_comm = g t.evals.mul_comm
    ; emul_comm = g t.evals.emul_comm
    ; endomul_scalar_comm = g t.evals.endomul_scalar_comm
    ; xor_comm = Option.map ~f:g t.evals.xor_comm
    ; range_check0_comm = Option.map ~f:g t.evals.range_check0_comm
    ; range_check1_comm = Option.map ~f:g t.evals.range_check1_comm
    ; foreign_field_add_comm = Option.map ~f:g t.evals.foreign_field_add_comm
    ; foreign_field_mul_comm = Option.map ~f:g t.evals.foreign_field_mul_comm
    ; rot_comm = Option.map ~f:g t.evals.rot_comm
    ; lookup_table_comm =
        Pickles_types.Vector.init
          Pickles_types.Plonk_types.Lookup_sorted_minus_1.n ~f:(fun i ->
            lookup (fun l -> Option.try_with (fun () -> l.lookup_table.(i))) )
    ; lookup_table_ids = lookup (fun l -> l.table_ids)
    ; runtime_tables_selector = lookup (fun l -> l.runtime_tables_selector)
    ; lookup_selector_lookup = lookup (fun l -> l.lookup_selectors.lookup)
    ; lookup_selector_xor = lookup (fun l -> l.lookup_selectors.xor)
    ; lookup_selector_range_check =
        lookup (fun l -> l.lookup_selectors.range_check)
    ; lookup_selector_ffmul = lookup (fun l -> l.lookup_selectors.ffmul)
    }
end
