open Core_kernel
open Import

module Evals = struct
  open Vector

  module Make (N : Nat_intf) = struct
    include N

    type 'a t = ('a, n) Vector.t

    include Binable (N)

    let typ elt = Vector.typ elt n
  end

  module Beta1 = Make (Nat.N6)
  module Beta2 = Make (Nat.N2)
  module Beta3 = Make (Nat.N11)
end

module Typ = Snarky.Typ

module Accumulator = struct
  module Input = struct
    type ('challenge, 'fp, 'values) t =
      { zr: 'fp
      ; z: 'challenge (* Evaluation point *)
      ; v: 'values (* Evaluation values *) }

    let to_hlist {zr; z; v} = H_list.[zr; z; v]

    let of_hlist ([zr; z; v] : (unit, _) H_list.t) = {zr; z; v}

    let typ challenge fp values =
      Snarky.Typ.of_hlistable [fp; challenge; values] ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let assert_equal fp t1 t2 =
      let mk t : _ list = t.zr :: t.z :: Vector.to_list t.v in
      List.iter2_exn ~f:fp (mk t1) (mk t2)
  end

  type 'g t = {r_f: 'g; r_pi: 'g; zr_pi: 'g} [@@deriving fields]

  let to_hlist {r_f; r_pi; zr_pi} = H_list.[r_f; r_pi; zr_pi]

  let of_hlist ([r_f; r_pi; zr_pi] : (unit, _) H_list.t) = {r_f; r_pi; zr_pi}

  let typ g =
    Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let assert_equal g t1 t2 =
    List.iter ~f:(fun x -> g (x t1) (x t2)) [r_f; r_pi; zr_pi]
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
    ; z_hat_A: 'pc
    ; z_hat_B: 'pc
    ; gh_1: 'pc * 'pc
    ; sigma_gh_2: 'fp * ('pc * 'pc)
    ; sigma_gh_3: 'fp * ('pc * 'pc) }
  [@@deriving fields, bin_io]

  let to_hlist {w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3} =
    H_list.[w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3]

  let of_hlist
      ([w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3] :
        (unit, _) H_list.t) =
    {w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3}

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
