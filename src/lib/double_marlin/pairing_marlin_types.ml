open Core_kernel
open Import
module Typ = Snarky.Typ

module Evals = struct
  open Vector

  module Make (N : Nat_intf) = struct
    include N

    type 'a t = ('a, n) Vector.t

    include Binable (N)

    let typ elt = Vector.typ elt n
  end

  module Beta1 = Make (Nat.N7)
  module Beta2 = Make (Nat.N2)
  module Beta3 = Make (Nat.N11)

  type 'a t = 'a Beta1.t * 'a Beta2.t * 'a Beta3.t

  let typ elt = Typ.tuple3 (Beta1.typ elt) (Beta2.typ elt) (Beta3.typ elt)
end

(*
module Accumulator = struct
  module Input = struct
    (* TODO: Needs to be exposed in the public input and the
       arithmetic checked. *)
    type ('challenge, 'fp ) t =
      { zr: 'fp
      ; z: 'challenge (* Evaluation point. This is beta_i so no need to re-expose it as a separate deferred value *)
      ; v: 'fp (* Evaluation. This is xi_sum so no need to re-expose it as a separate deferred value *) 
			; vr : 'fp
			}
    [@@deriving fields]

    let to_hlist {zr; z; v; vr} = H_list.[zr; z; v; vr]

    let of_hlist ([zr; z; v; vr] : (unit, _) H_list.t) = {zr; z; v; vr} 

    let typ challenge fp =
      Snarky.Typ.of_hlistable [fp; challenge; fp; fp] ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let assert_equal challenge fp t1 t2 =
      challenge t1.z t2.z ;
      List.iter [ zr; v; vr ] ~f:(fun f ->
        fp (f t1) (f t2))
  end

  type 'g t =
    { r_f: 'g
    ; r_v : 'g
    ; r_pi: 'g
    ; zr_pi: 'g} [@@deriving fields]

  let to_hlist {r_f; r_pi; zr_pi} = H_list.[r_f; r_pi; zr_pi]

  let of_hlist ([r_f; r_pi; zr_pi] : (unit, _) H_list.t) =
    {r_f; r_pi; zr_pi}

  let typ g =
    Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let assert_equal g t1 t2 =
    List.iter ~f:(fun x -> g (x t1) (x t2)) [r_f; r_pi; zr_pi]
end *)

module Accumulator = struct
  type 'g t = {r_f_plus_r_v: 'g; r_pi: 'g; zr_pi: 'g} [@@deriving fields]

  let to_hlist {r_f_plus_r_v; r_pi; zr_pi} = H_list.[r_f_plus_r_v; r_pi; zr_pi]

  let of_hlist ([r_f_plus_r_v; r_pi; zr_pi] : (unit, _) H_list.t) =
    {r_f_plus_r_v; r_pi; zr_pi}

  let typ g =
    Snarky.Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let assert_equal g t1 t2 =
    List.iter ~f:(fun x -> g (x t1) (x t2)) [r_f_plus_r_v; r_pi; zr_pi]
end

module Opening = struct
  type ('proof, 'values) t = {proof: 'proof; values: 'values}
  [@@deriving fields, bin_io]

  let to_hlist {proof; values} = H_list.[proof; values]

  let of_hlist ([proof; values] : (unit, _) H_list.t) = {proof; values}

  let typ proof values =
    Snarky.Typ.of_hlistable [proof; values] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Openings = struct
  open Evals

  type ('proof, 'fp) t =
    { beta_1: ('proof, 'fp Beta1.t) Opening.t
    ; beta_2: ('proof, 'fp Beta2.t) Opening.t
    ; beta_3: ('proof, 'fp Beta3.t) Opening.t }
  [@@deriving fields, bin_io]

  let to_hlist {beta_1; beta_2; beta_3} = H_list.[beta_1; beta_2; beta_3]

  let of_hlist ([beta_1; beta_2; beta_3] : (unit, _) H_list.t) =
    {beta_1; beta_2; beta_3}

  let typ proof fp =
    let op vals = Opening.typ proof (vals fp) in
    let open Snarky.Typ in
    of_hlistable
      [op Beta1.typ; op Beta2.typ; op Beta3.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Messages = struct
  type ('pc, 'fp) t =
    { w_hat: 'pc
    ; s: 'pc
    ; z_hat_a: 'pc
    ; z_hat_b: 'pc
    ; gh_1: 'pc * 'pc
    ; sigma_gh_2: 'fp * ('pc * 'pc)
    ; sigma_gh_3: 'fp * ('pc * 'pc) }
  [@@deriving fields, bin_io]

  let to_hlist {w_hat; s; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3} =
    H_list.[w_hat; s; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3]

  let of_hlist
      ([w_hat; s; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3] :
        (unit, _) H_list.t) =
    {w_hat; s; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3}

  let typ pc fp =
    let open Snarky.Typ in
    of_hlistable
      [pc; pc; pc; pc; pc * pc; fp * (pc * pc); fp * (pc * pc)]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Proof = struct
  type ('pc, 'fp, 'openings) t =
    {messages: ('pc, 'fp) Messages.t; openings: 'openings}
  [@@(* ('proof, 'fp) Openings.t} *)
    deriving fields, bin_io]

  let to_hlist {messages; openings} = H_list.[messages; openings]

  let of_hlist ([messages; openings] : (unit, _) H_list.t) =
    {messages; openings}

  let typ pc fp openings =
    Snarky.Typ.of_hlistable
      [Messages.typ pc fp; openings]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
