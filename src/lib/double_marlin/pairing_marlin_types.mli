open Vector

module Evals : sig
  module Beta1 : Intf.Evals.S with type n = z s s s s s s

  module Beta2 : Intf.Evals.S with type n = z s s

  module Beta3 : Intf.Evals.S with type n = z s s s s s s s s s s s
end

module Accumulator : sig
  type 'g t = {r_f: 'g; r_pi: 'g; zr_pi: 'g} [@@deriving fields]

  include Intf.Snarkable.S1 with type 'a t := 'a t

  val assert_equal : ('g -> 'g -> unit) -> 'g t -> 'g t -> unit

  module Input : sig
    type ('challenge, 'fp, 'values) t = {zr: 'fp; z: 'challenge; v: 'values}

    include Intf.Snarkable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t

    val assert_equal :
         ('fp -> 'fp -> unit)
      -> (('fp, 'fp, ('fp, _) Vector.t) t as 't)
      -> 't
      -> unit
  end
end

module Opening : sig
  type ('proof, 'values) t = {proof: 'proof; values: 'values}
  [@@deriving fields, bin_io]

  include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
end

module Openings : sig
  type ('proof, 'fp) t =
    { beta_1: ('proof, 'fp Evals.Beta1.t) Opening.t
    ; beta_2: ('proof, 'fp Evals.Beta2.t) Opening.t
    ; beta_3: ('proof, 'fp Evals.Beta3.t) Opening.t }
  [@@deriving fields, bin_io]

  include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
end

module Messages : sig
  type ('pc, 'fp) t =
    { w_hat: 'pc
    ; s: 'pc
    ; z_hat_A: 'pc
    ; z_hat_B: 'pc
    ; gh_1: 'pc * 'pc
    ; sigma_gh_2: 'fp * ('pc * 'pc)
    ; sigma_gh_3: 'fp * ('pc * 'pc) }
  [@@deriving fields, bin_io]

  include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
end

module Proof : sig
  type ('proof, 'pc, 'fp) t =
    {messages: ('pc, 'fp) Messages.t; openings: ('proof, 'fp) Openings.t}
  [@@deriving fields, bin_io]

  include Intf.Snarkable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
end
