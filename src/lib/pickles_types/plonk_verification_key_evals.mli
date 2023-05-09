(* Undocumented *)

module Stable : sig
  module V2 : sig
    type 'comms t =
      { sigma_comms : 'comms Plonk_types.Permuts_vec.Stable.V1.t
      ; coefficients_comms : 'comms Plonk_types.Columns_vec.Stable.V1.t
      ; generic_comms : 'comms
      ; psm_comms : 'comms
      ; complete_add_comms : 'comms
      ; mul_comms : 'comms
      ; emul_comms : 'comms
      ; endomul_scalar_comms : 'comms
      }

    include Sigs.Full.S1 with type 'a t := 'a t
  end

  module Latest = V2
end

type 'comms t = 'comms Stable.Latest.t =
  { sigma_comms : 'comms Plonk_types.Permuts_vec.t
  ; coefficients_comms : 'comms Plonk_types.Columns_vec.t
  ; generic_comms : 'comms
  ; psm_comms : 'comms
  ; complete_add_comms : 'comms
  ; mul_comms : 'comms
  ; emul_comms : 'comms
  ; endomul_scalar_comms : 'comms
  }
[@@deriving sexp, equal, compare, hash, yojson, hlist]

val typ :
     ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

(** [map t ~f] applies [f] to all elements of type ['a] within record [t] and
    returns the result. In particular, [f] is applied to the elements of
    {!sigma_comms} and {!coefficients_comms}. *)
val map : 'a t -> f:('a -> 'b) -> 'b t

val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

val dummy : 'a -> 'a t

module Chunked : sig
  type nonrec 'a t = 'a array t

  val typ :
       length:int
    -> ('a, 'b, 'c) Snarky_backendless.Typ.t
    -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

  val dummy : 'a -> 'a t
end

(** [chunk comms] convert a ['comm t] structure [comms] with single commitment
    fields to a chunk-ready one.  *)
val chunk : 'comm t -> 'comm Chunked.t
