(* TODO:
   Start writing pairing_main so I can get a sense of how the x_hat
   commitment and challenge is going to work. *)
open Core_kernel
module B = Bigint

module type Field_intf = sig
  type t

  val one : t
  val zero : t
  val inv : t -> t
  val negate : t -> t
  val ( * ) : t -> t -> t
  val ( - ) : t -> t -> t
  val ( + ) : t -> t -> t

  val to_bigint : t -> B.t
  val of_bigint : B.t -> t

  val of_bits : bool list -> t
  val to_bits : t -> bool list
end

let challenge_length = 128

module Eval_lagrange
    (Impl : Snarky.Snark_intf.Run)
    (Sponge : Sponge.Intf.Sponge
     with module Field := Impl.Field
and module State := Sponge.State
and type input := Impl.Field.t
and type digest := (length:int -> Impl.Boolean.var list))
    (Fp : sig
       include Field_intf
       val size_in_bits : int
     end )
= struct
  module Fq = Impl.Field
  let root_of_unity = failwith "TODO"

  (* Instead of evaluating lagrange interp
    = v_I(x) \sum_i a_i C_i / (x - i),

     evaluate

     \sum_i a_i C_i / (x - i) *)

  (* The next person  will scale this by v_I(x). *)

  module Fp_repr = struct
    (* This is 

       (terms.(0) + terms.(1) * base + .. terms.(n-1) * base^(n-1)) mod p

       where each term.(i) < term_bound.
    *)
    type t = 
      { base : B.t
      ; term_bound : B.t
      ; terms : Fq.t array
      }

    let fq_sum ts =
      Option.value (Array.reduce ts ~f:Fq.(+)) ~default:Fq.zero

    let ( * ) t1 t2 =
      assert (B.equal t1.base t2.base);
      let term_bound = B.(t1.term_bound * t2.term_bound) in
      assert B.(term_bound <= Fq.size);
      let top_power = (Array.length t1.terms - 1) + (Array.length t2.terms - 1) in
      let res = Array.init (top_power + 1) ~f:(fun _ -> Fq.zero) in
      for i = 0 to Array.length t1.terms do
        for j = 0 to Array.length t2.terms do
          let k = i + j in 
          res.(k) <- Fq.(res.(k) + t1.terms.(i) * t2.terms.(j))
        done
      done;
      { term_bound
      ; base= t1.base
      ; terms=res
      }

    let of_fp ~chunk_size x =
      let base = B.(shift_left one chunk_size) in
      let term_bound = B.(base - one) in
      let terms =
        List.groupi (Fp.to_bits x) ~break:(fun i _ _ -> i mod chunk_size = 0)
        |> Array.of_list_map ~f:(Fn.compose Fq.constant Fq.Constant.project)
      in
      { term_bound
      ; base
      ; terms
      }

    let of_bits ~chunk_size bits =
      let base = B.(shift_left one chunk_size) in
      let term_bound = B.(base - one) in
      let terms =
        List.groupi bits ~break:(fun i _ _ -> i mod chunk_size = 0)
        |> Array.of_list_map ~f:Fq.pack
      in
      { term_bound
      ; base
      ; terms
      }

    let ( + ) t1 t2 =
      assert (B.equal t1.base t2.base);
      let term_bound = B.(t1.term_bound + t2.term_bound) in
      assert B.(term_bound <= Fq.size);
      let n1 = Array.length t1.terms in
      let n2 = Array.length t2.terms in
      let terms =
        Array.init (Int.max n1 n2) ~f:(fun i ->
          match i < n1, i < n2 with
          | true, true -> Fq.(t1.terms.(i) + t2.terms.(i))
          | true, false -> t1.terms.(i) 
          | false, true -> t2.terms.(i) 
          | false, false -> assert false)
      in
      { term_bound; terms; base = t1.base
      }

    let read { base; term_bound=_; terms } = 
      let open Impl.As_prover in
      let res = ref Fp.zero in
      let n = Array.length terms in
      let base = Fp.of_bigint base in
      for i = n downto 0 do
        let term = read Fq.typ terms.(i) in
        let term = Fp.of_bits (Fq.Constant.unpack term) in
        res := Fp.(!res * base + term)
      done;
      !res
  end

(* Given a and x, compute 
   tweaked_lagrange a x = \sum_i a_i C_i / (x - zeta^i) 
   where 
   C_i := 1/\prod_{j in I, j != i} (zeta^i - zeta^j)

   Note that 

   v_I(x) * tweaked_lagrange a x = lagrange a x
*)

  let zeta = root_of_unity

  module Precomputation = struct
    type t =
      { zetas : Fp.t array
      ; neg_zetas : Fp.t array
      ; cs : Fp.t array
      }

    let create ~domain_size =
      let zetas =
        let res = Array.init domain_size ~f:(fun _ -> Fp.one) in
        for i = 1 to domain_size - 1 do
          res.(i) <- Fp.( * ) zeta.(i - 1) zeta
        done;
        res
      in
      let cs =
        Array.mapi zetas ~f:(fun i zeta_i ->
            Array.foldi zetas ~init:Fp.one
              ~f:(fun j acc zeta_j -> if i = j then acc else Fp.(acc * (zeta_i - zeta_j)))
            |> Fp.inv)
      in
      { zetas; cs; neg_zetas = Array.map zetas ~f:Fp.negate }

    let domain_size ~input_size = Int.ceil_pow2 input_size
  end

  open Impl

  (* c / (x - zeta^i) *)
  let div_term ~chunk_size ~(precomp : Precomputation.t) (x : Fp_repr.t) i =
    let d =
      exists (Typ.list ~length:Fp.size_in_bits Boolean.typ)
        ~compute:(fun () ->
            let x =  Fp_repr.read x in
            Fp.to_bits
              Fp.(precomp.cs.(i) * inv (x + precomp.neg_zetas.(i))) )
    in
    (* TODO: d appears in more than one constraint (2 I believe), so will want to make pack create a fresh var for it. *)
    let d = Fp_repr.of_bits ~chunk_size d in
    let bottom = Fp_repr.(x + of_fp ~chunk_size precomp.neg_zetas.(i)) in
    (d, `Check_equal (Fp_repr.of_fp ~chunk_size precomp.cs.(i), Fp_repr.(bottom * d)) )

  let batch_eq_checks ~chunk_size ~sponge eq_checks =
    let n = List.length eq_checks in
    let randomness =
      Array.init n ~f:(fun _ ->
          Fp_repr.of_bits ~chunk_size (Sponge.squeeze sponge ~length:challenge_length)
        )
    in
    let scale_sum xs =
      List.reduce_exn ~f:Fp_repr.(+)
        (List.mapi xs ~f:(fun i x -> Fp_repr.( * ) randomness.(i) x))
    in
    let actual, witnessed =
      List.map eq_checks ~f:(function (`Check_equal (x, y)) -> (x, y))
      |> List.unzip
    in
    `Check_equal (scale_sum actual, scale_sum witnessed)

  let tweaked_lagrange ~sponge (precomp : Precomputation.t) a x =
    let n = Array.length a in
    let e = Int.ceil_log2 n in
    let chunk_size = ((Fq.size_in_bits - e) / 2) in
    let domain_size = 1 lsl e in
    assert (Array.length precomp.cs = domain_size);
    let terms, eq_checks =
      List.init n ~f:(fun i ->
          let (d, eq_check) = div_term ~chunk_size ~precomp x i in
          (Fp_repr.( * ) a.(i) d, eq_check))
      |> List.unzip
    in
    let res = List.reduce_exn ~f:Fp_repr.(+) terms in
    (res, batch_eq_checks ~chunk_size ~sponge eq_checks)

(* term_bound constraints:

   Choices on term bound:
    a_i
    s_i random scalar
    guess d_i := C_i / (x - i)

   tb (a_i d_i) <= N - e.
   tb (s_i d_i) <= N - e.
   tb (s_i C_i) <= N - e.

   num_terms(a_i d_i) = num_terms(a_i) + num_terms(d_i).

   Could take
   
   term_bound = (N - e)/2
   base = 2^term_bound.
   *)
end
