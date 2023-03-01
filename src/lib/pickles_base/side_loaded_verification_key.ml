open Core_kernel
open Pickles_types

let bits ~len n = List.init len ~f:(fun i -> (n lsr i) land 1 = 1)

let max_log2_degree = 32

module Width : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  val of_int_exn : int -> t

  val to_int : t -> int

  val to_bits : t -> bool list

  val zero : t

  module Max = Nat.N2

  module Max_vector : Vector.With_version(Max).S

  module Max_at_most : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, Max.n) At_most.t
        [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]
  end

  module Length : Nat.Add.Intf_transparent
end = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = char [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let zero = Char.of_int_exn 0

  module Max = Nat.N2

  (* Think about versioning here! These vector types *will* change
     serialization if the numbers above change, and so will require a new
     version number. Thus, it's important that these are modules with new
     versioned types, and not just module aliases to the corresponding vector
     implementation.
  *)
  module Max_vector = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'a t = 'a Vector.Vector_2.Stable.V1.t
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    type 'a t = 'a Vector.Vector_2.t
    [@@deriving compare, yojson, sexp, hash, equal]

    let map = Vector.map

    let of_list_exn = Vector.Vector_2.of_list_exn

    let to_list = Vector.to_list
  end

  module Max_at_most = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'a t = 'a At_most.At_most_2.Stable.V1.t
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    type 'a t = 'a At_most.At_most_2.t
    [@@deriving compare, yojson, sexp, hash, equal]
  end

  module Length = Nat.N4

  let to_int = Char.to_int

  let to_bits = Fn.compose (bits ~len:(Nat.to_int Length.n)) to_int

  let of_int_exn : int -> t =
    let m = Nat.to_int Max.n in
    fun n ->
      assert (n <= m) ;
      Char.of_int_exn n
end

module Max_branches = struct
  include Nat.N8
  module Log2 = Nat.N3

  let%test "check max_branches" = Nat.to_int n = 1 lsl Nat.to_int Log2.n
end

(* TODO: remove since it looks very much like the Domains module in the same directory *)
module Domains = struct
  [@@@warning "-40-42"]

  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = { h : 'a }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

module Repr = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'g t =
        { max_proofs_verified : Proofs_verified.Stable.V1.t
        ; actual_wrap_domain_size : Proofs_verified.Stable.V1.t
        ; wrap_index : 'g Plonk_verification_key_evals.Stable.V2.t
        }
      [@@deriving sexp, equal, compare, yojson]
    end
  end]
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('g, 'proofs_verified, 'vk) t =
            ( 'g
            , 'proofs_verified
            , 'vk )
            Mina_wire_types.Pickles_base.Side_loaded_verification_key.Poly.V2.t =
        { max_proofs_verified : 'proofs_verified
        ; actual_wrap_domain_size : 'proofs_verified
        ; wrap_index : 'g Plonk_verification_key_evals.Stable.V2.t
        ; wrap_vk : 'vk option
        }
      [@@deriving hash]
    end
  end]
end

let index_to_field_elements (k : 'a Plonk_verification_key_evals.t) ~g =
  let Plonk_verification_key_evals.
        { sigma_comm
        ; coefficients_comm
        ; generic_comm
        ; psm_comm
        ; complete_add_comm
        ; mul_comm
        ; emul_comm
        ; endomul_scalar_comm
        } =
    k
  in
  List.map
    ( Vector.to_list sigma_comm
    @ Vector.to_list coefficients_comm
    @ [ generic_comm
      ; psm_comm
      ; complete_add_comm
      ; mul_comm
      ; emul_comm
      ; endomul_scalar_comm
      ] )
    ~f:g
  |> Array.concat

let wrap_index_to_input (type gs f) (g : gs -> f array) t =
  Random_oracle_input.Chunked.field_elements (index_to_field_elements t ~g)

let to_input (type a) ~(field_of_int : int -> a) :
    (a * a, _, _) Poly.t -> a Random_oracle_input.Chunked.t =
  let open Random_oracle_input.Chunked in
  fun Poly.
        { max_proofs_verified
        ; actual_wrap_domain_size
        ; wrap_index
        ; wrap_vk = _
        } : _ Random_oracle_input.Chunked.t ->
    List.reduce_exn ~f:append
      [ Proofs_verified.One_hot.to_input ~zero:(field_of_int 0)
          ~one:(field_of_int 1) max_proofs_verified
      ; Proofs_verified.One_hot.to_input ~zero:(field_of_int 0)
          ~one:(field_of_int 1) actual_wrap_domain_size
      ; wrap_index_to_input
          (Fn.compose Array.of_list (fun (x, y) -> [ x; y ]))
          wrap_index
      ]
