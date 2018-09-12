open Core_kernel

module type Backend_intf = sig
  module N : Nat_intf.S

  module G1 : sig
    type t
    [@@deriving bin_io]

    val zero : t

    val is_well_formed : t -> bool

    val ( * ) : N.t -> t -> t

    val (+) : t -> t -> t
  end

  module G2 : sig
    type t
    [@@deriving bin_io]

    val (+) : t -> t -> t

    val is_well_formed : t -> bool
  end

  module Fq_target : sig
    include Fields.Intf

    val unitary_inverse : t -> t
  end

  module Pairing
    : Pairing.S
      with module G1 := G1
       and module G2 := G2
       and module Fq_target := Fq_target
end

module Make
    (Backend : Backend_intf)
= struct
  open Backend

  module Verification_key = struct
    type t =
      { h : G2.t
      ; g_alpha : G1.t
      ; h_beta : G2.t
      ; g_gamma : G1.t
      ; h_gamma : G2.t
      ; query : G1.t array
      }
    [@@deriving bin_io]

    module Processed = struct
      type t =
        { g_alpha : G1.t
        ; h_beta : G2.t
        ; g_alpha_h_beta : Fq_target.t
        ; g_gamma_pc : Pairing.G1_precomputation.t
        ; h_gamma_pc : Pairing.G2_precomputation.t
        ; h_pc : Pairing.G2_precomputation.t
        ; query : G1.t array
        }

      let create { h ; g_alpha; h_beta; g_gamma; h_gamma; query } =
        { g_alpha
        ; h_beta
        ; g_alpha_h_beta = Pairing.reduced_pairing g_alpha h_beta
        ; g_gamma_pc = Pairing.G1_precomputation.create g_gamma
        ; h_gamma_pc = Pairing.G2_precomputation.create h_gamma
        ; h_pc = Pairing.G2_precomputation.create h
        ; query
        }
    end 
  end

  module Proof = struct
    type t =
      { a : G1.t
      ; b : G2.t
      ; c : G1.t
      }
    [@@deriving bin_io]

    let is_well_formed { a; b; c } =
      G1.is_well_formed a
      && G2.is_well_formed b
      && G1.is_well_formed c
  end

  let verify (vk : Verification_key.Processed.t) input ({Proof.a; b ; c} as proof) =
    let check b lab = if b then Ok () else Or_error.error_string lab in
    let open Or_error.Let_syntax in
    let%bind () =
      check
        (Int.equal (List.length input) (Array.length vk.query - 1))
        "Input length was not as expected"
    in
    let%bind () =
      check (Proof.is_well_formed proof)
        "proof was not well-formed (the points were off their curves)"
    in
    let input_acc =
      List.foldi input ~init:vk.query.(0) ~f:(fun i acc x ->
        let q = vk.query.(1+i) in
        G1.(acc + x * q))
    in
    let test1 =
      let l = Pairing.unreduced_pairing G1.(a + vk.g_alpha) G2.(b + vk.h_beta) in
      let r1 = vk.g_alpha_h_beta in
      let r2 =
        Pairing.miller_loop
          (Pairing.G1_precomputation.create input_acc)
          vk.h_gamma_pc
      in
      let r3 =
        Pairing.miller_loop
          (Pairing.G1_precomputation.create c)
          vk.h_pc
      in
      let test =
        Fq_target.(
          Pairing.final_exponentiation (unitary_inverse l * r2 * r3)
            * r1)
      in
      Fq_target.(test = one)
    in
    let%bind () =
      check test1
        "First pairing check failed"
    in
    let test2 =
      let l =
        Pairing.miller_loop (Pairing.G1_precomputation.create a) vk.h_gamma_pc
      in
      let r =
        Pairing.miller_loop vk.g_gamma_pc (Pairing.G2_precomputation.create b)
      in
      let test2 =
        Pairing.final_exponentiation Fq_target.(l * unitary_inverse r)
      in
      Fq_target.(test2 = one)
    in
    check test2
      "Second pairing check failed"
end
