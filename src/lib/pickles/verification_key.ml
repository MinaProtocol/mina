open Core_kernel
open Pickles_types
open Import
open Kimchi_pasta.Pasta

module Data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { constraints : int }

      let to_latest = Fn.id
    end
  end]
end

module Repr = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { commitments :
            Backend.Tock.Curve.Affine.Stable.V1.t
            Plonk_verification_key_evals.Stable.V2.t
        ; step_domains : Domains.Stable.V1.t array
        ; data : Data.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]
end

[%%versioned_binable
module Stable = struct
  module V2 = struct
    type t =
      { commitments : Backend.Tock.Curve.Affine.t Plonk_verification_key_evals.t
      ; step_domains : Domains.t array
      ; index : Impls.Wrap.Verification_key.t
      ; data : Data.t
      }
    [@@deriving fields]

    let to_latest = Fn.id

    let of_repr srs { Repr.commitments = c; step_domains; data = d } =
      let t : Impls.Wrap.Verification_key.t =
        let log2_size = Int.ceil_log2 d.constraints in
        let d = Domain.Pow_2_roots_of_unity log2_size in
        let max_quot_size = Common.max_quot_size_int (Domain.size d) in
        { domain =
            { log_size_of_group = log2_size
            ; group_gen = Backend.Tock.Field.domain_generator log2_size
            }
        ; max_poly_size = 1 lsl Nat.to_int Rounds.Wrap.n
        ; max_quot_size
        ; srs
        ; evals =
            (let g (x, y) =
               { Kimchi.Protocol.unshifted =
                   [| Kimchi.Foundations.Finite (x, y) |]
               ; shifted = None
               }
             in
             { sigma_comm = Array.map ~f:g (Vector.to_array c.sigma_comm)
             ; coefficients_comm =
                 Array.map ~f:g (Vector.to_array c.coefficients_comm)
             ; generic_comm = g c.generic_comm
             ; mul_comm = g c.mul_comm
             ; psm_comm = g c.psm_comm
             ; emul_comm = g c.emul_comm
             ; complete_add_comm = g c.complete_add_comm
             ; endomul_scalar_comm = g c.endomul_scalar_comm
             ; chacha_comm = None
             })
        ; shifts = Common.tock_shifts ~log2_size
        ; lookup_index = None
        }
      in
      { commitments = c; step_domains; data = d; index = t }

    include Binable.Of_binable
              (Repr.Stable.V2)
              (struct
                type nonrec t = t

                let to_binable { commitments; step_domains; data; index = _ } =
                  { Repr.commitments; data; step_domains }

                let of_binable r = of_repr (Backend.Tock.Keypair.load_urs ()) r
              end)
  end
end]

let dummy_commitments g =
  let open Dlog_plonk_types in
  { Plonk_verification_key_evals.sigma_comm =
      Vector.init Permuts.n ~f:(fun _ -> g)
  ; coefficients_comm = Vector.init Columns.n ~f:(fun _ -> g)
  ; generic_comm = g
  ; psm_comm = g
  ; complete_add_comm = g
  ; mul_comm = g
  ; emul_comm = g
  ; endomul_scalar_comm = g
  }

let dummy =
  lazy
    (let rows = Domain.size Common.wrap_domains.h in
     let g = Backend.Tock.Curve.(to_affine_exn one) in
     { Repr.commitments = dummy_commitments g
     ; step_domains = [||]
     ; data = { constraints = rows }
     }
     |> Stable.Latest.of_repr (Kimchi.Protocol.SRS.Fq.create 1))
