open Core
open Pickles_types
open Import
open Zexe_backend.Tweedle

module Data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = {constraints: int}

      let to_latest = Fn.id
    end
  end]
end

module Repr = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { commitments:
            Dee.Affine.Stable.V1.t array
            Plonk_verification_key_evals.Stable.V1.t
        ; step_domains: Domains.Stable.V1.t array
        ; data: Data.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]
end

type t =
  { commitments: Dee.Affine.t array Plonk_verification_key_evals.t
  ; step_domains: Domains.t array
  ; index: Impls.Wrap.Verification_key.t
  ; data: Data.t }
[@@deriving fields]

let of_repr urs {Repr.commitments= c; step_domains; data= d} =
  let u = Unsigned.Size_t.of_int in
  let g = Zexe_backend.Tweedle.Fp_poly_comm.without_degree_bound_to_backend in
  let t =
    let d = Domain.Pow_2_roots_of_unity (Int.ceil_log2 d.constraints) in
    let r, o = Common.tock_shifts d in
    let max_quot_size = (5 * (Domain.size d + 2)) - 5 in
    Snarky_bn382.Tweedle.Dee.Plonk.Field_verifier_index.make
      ~max_poly_size:(u (1 lsl Nat.to_int Rounds.Wrap.n))
      ~max_quot_size:(u max_quot_size) ~urs ~sigma_comm0:(g c.sigma_comm_0)
      ~sigma_comm1:(g c.sigma_comm_1) ~sigma_comm2:(g c.sigma_comm_2)
      ~ql_comm:(g c.ql_comm) ~qr_comm:(g c.qr_comm) ~qo_comm:(g c.qo_comm)
      ~qm_comm:(g c.qm_comm) ~qc_comm:(g c.qc_comm) ~rcm_comm0:(g c.rcm_comm_0)
      ~rcm_comm1:(g c.rcm_comm_1) ~rcm_comm2:(g c.rcm_comm_2)
      ~psm_comm:(g c.psm_comm) ~add_comm:(g c.add_comm)
      ~mul1_comm:(g c.mul1_comm) ~mul2_comm:(g c.mul2_comm)
      ~emul1_comm:(g c.emul1_comm) ~emul2_comm:(g c.emul2_comm)
      ~emul3_comm:(g c.emul3_comm) ~r ~o
  in
  {commitments= c; step_domains; data= d; index= t}

include Binable.Of_binable
          (Repr.Stable.Latest)
          (struct
            type nonrec t = t

            let to_binable {commitments; step_domains; data; index= _} =
              {Repr.commitments; data; step_domains}

            let of_binable r =
              of_repr (Zexe_backend.Tweedle.Dee_based.Keypair.load_urs ()) r
          end)

let dummy_commitments g =
  { Plonk_verification_key_evals.sigma_comm_0= g
  ; sigma_comm_1= g
  ; sigma_comm_2= g
  ; ql_comm= g
  ; qr_comm= g
  ; qo_comm= g
  ; qm_comm= g
  ; qc_comm= g
  ; rcm_comm_0= g
  ; rcm_comm_1= g
  ; rcm_comm_2= g
  ; psm_comm= g
  ; add_comm= g
  ; mul1_comm= g
  ; mul2_comm= g
  ; emul1_comm= g
  ; emul2_comm= g
  ; emul3_comm= g }

let dummy =
  lazy
    (let rows = Domain.size Common.wrap_domains.h in
     let g =
       let len =
         let max_degree = Common.Max_degree.wrap in
         Int.round_up rows ~to_multiple_of:max_degree / max_degree
       in
       Array.create ~len Dee.(to_affine_exn one)
     in
     { Repr.commitments= dummy_commitments g
     ; step_domains= [||]
     ; data= {constraints= rows} }
     |> of_repr (Snarky_bn382.Tweedle.Dee.Field_urs.create Unsigned.Size_t.one))
