open Core_kernel

let weight = ref 0

module Bn382 = struct
  open Snarky_bn382

  module Bigint = struct
    module R = struct
      open Bigint

      let length_in_bytes = 48

      type nonrec t = t

      let to_bigstring t =
        let limbs = to_data t in
        Bigstring.init length_in_bytes ~f:(fun i -> Ctypes.(!@(limbs +@ i)))

      let of_bigstring s =
        let ptr = Ctypes.bigarray_start Ctypes.array1 s in
        let t = of_data ptr in
        Caml.Gc.finalise delete t ; t

      include Binable.Of_binable
                (Bigstring.Stable.V1)
                (struct
                  type nonrec t = t

                  let to_binable = to_bigstring

                  let of_binable = of_bigstring
                end)

      let to_field = Fp.of_bigint
      let of_field = Fp.to_bigint
      let test_bit = test_bit

      let of_data bs ~bitcount =
        assert (bitcount <= length_in_bytes * 8) ;
        of_bigstring bs

      let of_decimal_string = of_decimal_string
      let of_numeral s ~base =
        of_numeral s (String.length s) base

      let compare x y =
        match Unsigned.UInt8.to_int (compare x y) with
        | 255 -> -1
        | x -> x
    end
  end

  module Field = struct
    open Fp

    module Mat = Constraint_matrix

    include Binable.Of_binable(Bigint.R)(struct
        type nonrec t = t
      let to_binable = to_bigint
      let of_binable = of_bigint end)

    type t = Fp.t sexp_opaque [@@deriving sexp]

    let gc2 op x1 x2 =
      let r = op x1 x2 in
      Caml.Gc.finalise delete r;
      r

    let gc1 op x1 =
      let r = op x1 in
      Caml.Gc.finalise delete r;
      r

    let of_int = Fn.compose of_int Unsigned.UInt64.of_int
    let one = of_int 1

    let zero = of_int 0

    let add = gc2 add
    let sub = gc2 sub
    let mul = gc2 mul
    let inv = gc1 inv
    let square = gc1 square
    let sqrt = gc1 sqrt
    let is_square = is_square

    let () = 
      let five_is_square  = is_square (of_int 5) in
      assert (not five_is_square)

    let equal = equal
    let size_in_bits = 382
    let print = print
    let random = gc1 random
    let negate = gc1 negate

    module Mutable = struct
      let add t ~other = mut_add t other
      let mul t ~other = mut_mul t other
      let sub t ~other = mut_sub t other
      let copy ~over t = Fp.copy over t
    end

    let op f = fun t other -> f t ~other

    let ( += ) = op Mutable.add
    let ( *= ) = op Mutable.mul
    let ( -= ) = op Mutable.sub

    module Vector = struct
      type elt = t
      include Vector
    end
  end

  module G1 = struct
    module Affine = struct
      type t = Field.t * Field.t [@@deriving bin_io]

      let of_backend t =
        let x = G1.Affine.x t in
        Caml.Gc.finalise Fp.delete x;
        let y = G1.Affine.y t in
        Caml.Gc.finalise Fp.delete y;
        (x, y)
    end
  end

  module R1CS_constraint_system
  = struct
    type 'a abc =
      { a : 'a
      ; b : 'a
      ; c : 'a
      }

    module Weight = struct
      type t = int abc

      let ( + ) t1 (a,b,c) =
        { a=t1.a+a
        ; b=t1.b+b
        ; c=t1.c+c}

      let norm {a;b;c} = Int.(max a (max b c))
    end

    type t =
      { m : Fp.Constraint_matrix.t abc ; mutable weight : Weight.t 
      ; mutable public_input_size : int
      ; mutable auxiliary_input_size : int
      }

    let create () =
      { public_input_size=0
      ; auxiliary_input_size=0
      ; weight = {a=0; b=0; c=0}
      ; m= {
          a= Field.Mat.create ();
          b= Field.Mat.create ();
          c= Field.Mat.create ();
        }
      }

    (* TODO *)
    let to_json _  = `List []

    let get_auxiliary_input_size t = t.auxiliary_input_size
    let get_primary_input_size t = t.public_input_size

    let set_auxiliary_input_size t x = t.auxiliary_input_size <- x
    let set_primary_input_size t x = t.public_input_size <- x

    (* TODO *)
    let digest _ = Md5.digest_string ""

    let finalize = ignore

    let merge_terms xs0 ys0 ~init ~f =
      let rec go acc xs ys =
        match xs, ys with
        | [], [] -> acc
        | [], (y, iy) :: ys ->
          go (f acc iy (`Right y)) [] ys
        | (x, ix) :: xs, [] ->
          go (f acc ix (`Left x)) xs []
        | (x, ix) :: xs', (y, iy) :: ys' ->
          if ix < iy
          then go (f acc ix (`Left x)) xs' ys
          else if ix = iy
          then go (f acc ix (`Both (x, y)))  xs' ys'
          else go (f acc iy (`Right y)) xs ys'
      in
      go init xs0 ys0

    let sub_terms xs ys =
      merge_terms~init:[] ~f:(fun acc i t ->
          let c =
            match t with
            | `Left x -> x
            | `Right y -> Field.negate y
            | `Both (x, y) -> Field.sub x y
          in
          (c, i) :: acc)
        xs ys
      |> List.rev

    let decr_constant_term = function
      | (c, 0) :: terms -> (Field.(sub c one), 0) :: terms
      | ((_, _) :: _) as terms -> (Field.(sub zero one), 0) :: terms
      | [] -> []

    let canonicalize x =
      let c, terms = 
        Field.(Snarky.Cvar.to_constant_and_terms ~add ~mul ~zero:(of_int 0) ~one:(of_int 1)) x
      in
      let terms =
        List.sort terms ~compare:(fun (_, i) (_, j) -> Int.compare i j)
      in
      let has_constant_term = Option.is_some c in
      let terms =
        match c with
        | None -> terms
        | Some c -> (c, 0) :: terms
      in
      match terms with
      | [] -> None
      | (c0, i0) :: terms ->
        let (acc, i, ts, n) = 
          Sequence.of_list terms
          |> Sequence.fold ~init:(c0, i0, [], 0) ~f:(fun (acc, i, ts, n) (c, j) ->
              if Int.equal i j
              then (Field.add acc c, i, ts, n)
              else (c, j, (acc, i) :: ts, n + 1) )
        in
        Some (List.rev ((acc, i) :: ts), n + 1, has_constant_term)

    let choose_best base opts terms =
      let ( +. ) = Weight.( + ) in
      let best f xs =
        List.max_elt xs
          ~compare:(fun (_, wt1) (_, wt2) ->
              Int.compare
                (Weight.norm ( base +. f wt1))
                (Weight.norm ( base +. f wt2)) )
        |> Option.value_exn
      in
      let swap_ab (a, b, c) = (b, a, c) in
      let best_unswapped, d_unswapped = best Fn.id opts in
      let best_swapped, d_swapped = best swap_ab opts in
      let w_unswapped, w_swapped = base +. d_unswapped, base +. d_swapped in
      if Weight.(norm w_swapped < norm w_unswapped)
      then (swap_ab (terms best_swapped), w_swapped)
      else (terms best_unswapped, w_unswapped)

    let i = ref 0 

    let add_r1cs t (a, b, c) =
      let append m v = 
        let indices = Snarky_bn382.Usize_vector.create () in
        let coeffs = Field.Vector.create () in
        List.iter v ~f:(fun (x, i) ->
            Snarky_bn382.Usize_vector.emplace_back indices (Unsigned.Size_t.of_int i);
            Field.Vector.emplace_back coeffs x );
        Field.Mat.append_row m indices coeffs ;
      in
      append t.m.a a ;
      append t.m.b b ;
      append t.m.c c ;
      weight := Int.max !weight  (Weight.norm t.weight) 

    let add_constraint ?label:_ t (constr : Field.t Snarky.Cvar.t Snarky.Constraint.basic) =
      let var = canonicalize in
      let var_exn t = Option.value_exn (var t) in
      let choose_best opts terms =
        let constr, new_weight = choose_best t.weight opts terms in
        t.weight <- new_weight;
        add_r1cs t constr
      in
      match constr with
      | Boolean x ->
        let (x, x_weight, x_has_constant_term) = var_exn x in
        let x_minus_1_weight =
          x_weight + (if x_has_constant_term then 0 else 1)
        in
        choose_best
          (* x * x = x
             x * (x - 1) = 0 *)
          [ (`x_x_x,       (x_weight,x_weight,x_weight))
          ; (`x_xMinus1_0, (x_weight, x_minus_1_weight, 0))
          ]
          (function
          | `x_x_x -> (x, x, x)
          | `x_xMinus1_0 -> (x, decr_constant_term x, []))
      | Equal (x, y) ->
        (* x * 1 = y
           y * 1 = x
           (x - y) * 1 = 0
        *)
        let (x_terms, x_weight, _) = var_exn x in
        let (y_terms, y_weight, _) = var_exn y in
        let x_minus_y_weight =
          merge_terms ~init:0 ~f:(fun acc _ _ -> acc + 1)
            x_terms y_terms
        in
        let options =
          [ `x_1_y, (x_weight, 1, y_weight)
          ; `y_1_x, (y_weight, 1, x_weight)
          ; `x_minus_y_1_zero, (x_minus_y_weight, 1, 0)
          ]
        in
        let one = [ (Field.one, 0) ] in
        choose_best options
          (function
            | `x_1_y -> (x_terms, one, y_terms)
            | `y_1_x -> (y_terms, one, x_terms)
            | `x_minus_y_1_zero ->
              (sub_terms x_terms y_terms, one, []))
      | Square (x, z) ->
        let x, x_weight, _ = var_exn x in
        let z, z_weight, _ = var_exn z in
        choose_best
          [ ((), (x_weight, x_weight, z_weight)) ]
          (fun () -> (x, x, z))
      | R1CS (a, b, c) ->
        let a, a_weight, _ = var_exn a in
        let b, b_weight, _ = var_exn b in
        let c, c_weight, _ = var_exn c in
        choose_best [ ( (), (a_weight, b_weight, c_weight)) ]
          (fun () -> (a, b, c))
  end

  let field_size : Bigint.R.t = Snarky_bn382.Fp.size ()

  module Verification_key = String

  module Proving_key = struct
    type t = Fp_index.t

    include Binable.Of_binable(Unit)(struct
        type t = Fp_index.t
        let to_binable _ = ()
        let of_binable () = failwith "TODO"
      end)

    let is_initialized _ = `Yes
    let set_constraint_system _ _ = ()
    let to_string _ = ""
    let of_string _ = failwith "TODO"
  end

  module Var = struct
    type t = int
    let index = Fn.id
    let create = Fn.id
  end

  module Keypair = struct
    type t = Fp_index.t

    let create
      { R1CS_constraint_system.public_input_size
      ; auxiliary_input_size
      ; m= {a; b; c }
      ; weight=_
      }
      =
      let vars = (1 + public_input_size) + auxiliary_input_size in
      Fp_index.create a b c
        (Unsigned.Size_t.of_int vars)
        (Unsigned.Size_t.of_int (public_input_size + 1))

    let vk _ = ""
    let pk = Fn.id
  end

  module Proof = struct
    type t = 
      ( G1.Affine.t
      , Field.t
      , (G1.Affine.t, Field.t) Pairing_marlin_types.Openings.Wire.t
      ) Pairing_marlin_types.Proof.t
    [@@deriving bin_io]

    let of_backend t : t =
      let g1 f =
        let aff = f t in
        let res = G1.Affine.of_backend aff in
        Snarky_bn382.G1.Affine.delete aff;
        res
      in
      let fp' x =
        Caml.Gc.finalise Snarky_bn382.Fp.delete x;
        x
      in
      let fp f =
        let res = f t in
        Caml.Gc.finalise Snarky_bn382.Fp.delete res;
        res
      in
      let open Snarky_bn382.Fp_proof in
      let row_evals = row_evals t in
      let col_evals = col_evals t in
      let val_evals = val_evals t in
      let open Evals in
      { messages=
          { w_hat= g1 w_comm 
          ; s= failwith "remove s"
          ; z_hat_a= g1 za_comm
          ; z_hat_b= g1 zb_comm
          ; gh_1=
              (g1 g1_comm, g1 h1_comm) 
          ; sigma_gh_2=
              (fp sigma2, (g1 g2_comm, g1 h2_comm))
          ; sigma_gh_3=
              (fp sigma3, (g1 g3_comm, g1 h3_comm))
          }
      ; openings=
          { beta_1=
              { proof= g1 proof1
              ; values=
                  (* TODO: Rearrange the order *)
                  Vector.map ~f:fp
                    [ g1_eval
                    ; h1_eval
                    ; za_eval
                    ; zb_eval
                    ; w_eval
                    ; failwith "remove s"
                    ]
              }
          ; beta_2=
              { proof= g1 proof2
              ; values=
                  Vector.map ~f:fp
                  [ g2_eval
                  ; h2_eval
                  ]
              }
          ; beta_3=
              { proof= g1 proof3
              ; values=
                  [ fp g3_eval
                  ; fp h3_eval
                  ; fp' (f0 row_evals)
                  ; fp' (f1 row_evals)
                  ; fp' (f2 row_evals)
                  ; fp' (f0 col_evals)
                  ; fp' (f1 col_evals)
                  ; fp' (f2 col_evals)
                  ; fp' (f0 val_evals)
                  ; fp' (f1 val_evals)
                  ; fp' (f2 val_evals)
                  ]
              }
          }
      }

    type message = unit

    let create ?message:_ pk ~primary ~auxiliary =
      let res = Snarky_bn382.Fp_proof.create pk primary auxiliary in
      let t = of_backend res in
      Snarky_bn382.Fp_proof.delete res;
      t

    let verify ?message:_ _ _ _ = true
  end
end

module Inputs : Intf.Pairing_main_inputs.S = struct
  module Impl = Snarky.Snark.Run.Make (Bn382) (Unit)

  let%test_unit "one-identity" =
    let module F = Impl.Field.Constant in
    let x = F.random () in
    assert (F.equal x F.(one * x))

  module Fq_constant = struct
    type t = unit

    let size_in_bits = 382
  end

  open Impl

  module App_state = struct
    type t = Field.t

    module Constant = Field.Constant

    let to_field_elements x = [|x|]

    let typ = Typ.field

    let check_update x0 x1 =
      Field.(equal x1 (x0 + one))

    let is_base_case x = Field.(equal x zero)
  end

  module Poseidon_inputs = struct

    module Field = Impl.Field

    let rounds_full = 8

    let rounds_partial = 55

    let to_the_alpha x = Impl.Field.(square (square x) * x)

    module Operations = struct
      (* TODO: experiment with sealing version of this *)
      let add_assign ~state i x = state.(i) <- Field.( + ) state.(i) x

      let apply_affine_map (matrix, constants) v =
        let seal x =
          let x' = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
          Field.Assert.equal x x';
          x'
        in
        let dotv row =
          Array.reduce_exn 
            (Array.map2_exn row v ~f:Field.( * )) ~f:Field.( + )
        in
        Array.mapi matrix ~f:(fun i row ->
          seal (Field.(constants.(i) + dotv row) ))

      let copy = Array.copy
    end 
  end

  module S = Sponge.Make_sponge (Sponge.Poseidon (Poseidon_inputs))

  let sponge_params =
    Sponge.Params.(
      map bn128 ~f:Impl.Field.(Fn.compose constant Constant.of_string))

  module Sponge = struct
    module S = struct
      type t = S.t

      let create ?init params =
        S.create
          ?init
          params 

      let absorb t input =
        ksprintf Impl.with_label "absorb: %s" __LOC__ (fun () ->
            S.absorb t input )

      let squeeze t =
        ksprintf Impl.with_label "squeeze: %s" __LOC__ (fun () ->
            (S.squeeze t) )
    end

    include Sponge.Make_bit_sponge (struct
                type t = Impl.Boolean.var
              end)
              (struct
                include Impl.Field

                let to_bits t =
                  Bitstring_lib.Bitstring.Lsb_first.to_list
                    (Impl.Field.unpack_full t)
              end)
              (S)

    let absorb t input =
      match input with
      | `Field x ->
          absorb t x
      | `Bits bs ->
          absorb t (Field.pack bs)
  end

  module G = struct
    module Inputs = struct
      module Impl = Impl

      module F = struct
        include struct
          open Impl.Field

          type nonrec t = t

          let ( * ), ( + ), ( - ), inv_exn, square, scale, if_, typ, constant =
            (( * ), ( + ), ( - ), inv, square, scale, if_, typ, constant)

          let negate x = scale x Constant.(negate one)
        end

        module Constant = struct
          open Impl.Field.Constant

          type nonrec t = t

          let ( * ), ( + ), ( - ), inv_exn, square, negate =
            (( * ), ( + ), ( - ), inv, square, negate)
        end

        let assert_square x y = Impl.assert_square x y

        let assert_r1cs x y z = Impl.assert_r1cs x y z
      end

      module Constant = struct
        open Snarky_bn382.G
        type nonrec t = t

        let to_affine_exn t =
          let t = to_affine_exn t in
          Affine.(x t, y t)

        let of_affine (x, y) =
          of_affine_coordinates x y

        let random () = Snarky_bn382.G.random ()

        let negate = negate
        let ( + ) = add
      end

      module Params = struct
        open Impl.Field.Constant

        let a = zero

        let b = of_int 7

        let one =
          Constant.to_affine_exn(Snarky_bn382.G.one ())

        let group_size_in_bits = 382
      end

    end

    module Constant = Inputs.Constant
    module T = Snarky_curve.For_native_base_field (Inputs)

    type t = T.t

    let typ = T.typ

    let ( + ) _ _ = (exists Field.typ, exists Field.typ)

    let scale t bs =
      let constraints_per_bit =
        let x, _y = t in
        if Option.is_some (Field.to_constant x) then 2 else 6
      in
      ksprintf Impl.with_label "scale %s" __LOC__ (fun () ->
          (* Dummy constraints *)
          let x = exists Field.typ in
          let y = exists Field.typ in
          let num_bits = List.length bs in
          for _ = 1 to constraints_per_bit * num_bits do
            Impl.assert_r1cs x y x
          done ;
          (x, y) )

    (*         T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) *)
    let to_field_elements (x, y) = [x; y]

    let scale_inv = scale

    let scale_by_quadratic_nonresidue t = T.double (T.double t) + t

    let scale_by_quadratic_nonresidue_inv = scale_by_quadratic_nonresidue

    let negate = T.negate

    let one = T.one

    let if_ b ~then_:(tx, ty) ~else_:(ex, ey) =
      (Field.if_ b ~then_:tx ~else_:ex, Field.if_ b ~then_:ty ~else_:ey)
  end

  let domain_k = Domain.Pow_2_roots_of_unity 18

  let domain_h = Domain.Pow_2_roots_of_unity 18

  module Input_domain = struct
    let domain = Domain.Pow_2_roots_of_unity 5

    let lagrange_commitments =
      Array.init (Domain.size domain) ~f:(fun _ -> G.one)
  end

  module Generators = struct
    let g = G.one

    let h = G.one
  end
end

let%test_unit "pairing-main" =
  let module M = Pairing_main.Main (Inputs) in
  let module Stmt = Types.Pairing_based.Statement in
  let input =
    let open Vector in
    Snarky.Typ.tuple4 
      (typ M.Fq.typ Nat.N4.n)
      (typ Inputs.Impl.Field.typ Nat.N3.n)
                (typ M.Challenge.typ Nat.N9.n)
                (Snarky.Typ.array ~length:16
                   (Types.Pairing_based.Bulletproof_challenge.typ
                      M.Challenge.typ Inputs.Impl.Boolean.typ))
  in
  let n =
    Inputs.Impl.constraint_count (fun () ->
        M.main
          (Stmt.of_data
          (Inputs.Impl.exists
             (input)) ) )
  in
  let main = 
      (fun x () ->
         M.main (Stmt.of_data x))
  in
  Core.printf "pairing-main: %d / %d\n%!" n !weight;
  let _k =
    Inputs.Impl.generate_keypair
      ~exposing:[input]
      main
  in
  Core.printf "pairing-main: %d / %d\n%!" n !weight;
  (*
  let pi =
    let pass_through =
      { Types.Pairing_based.Proof_state.Pass_through.
        pairing_marlin_index
      ; pairing_marlin_acc
      }
    in
    let module I = Inputs.Impl in
    I.prove
      (I.Keypair.pk k)
      [ input ]
      main
      ()
      (Stmt.to_data
         { proof_state=
            { deferred_values
            ; sponge_digest_before_evaluations
            ; me_only }
         ; pass_through
         })
  in *)
  ()

module Dlog_inputs : Intf.Dlog_main_inputs.S = struct
  open Inputs
  module Impl = Impl
  module G1 = G
  module Input_domain = Input_domain

  let domain_k = domain_k

  let domain_h = domain_h

  module Generators = Generators

  let sponge_params = sponge_params

  module Fp_params = struct
    let size_in_bits = 382

    let p =
      Bigint.of_string
        "5543634365110765627805495722742127385843376434033820803590214255538854698464778703795540858859767700241957783601153"
  end

  module Sponge = struct
    include Sponge

    let absorb t x = absorb t (`Field x)
  end
end
(*

let%test_unit "dlog-main" =
  let module Inputs = Dlog_inputs in
  let module M = Dlog_main.Dlog_main (Inputs) in
  let n =
    let open Vector in
    Inputs.Impl.constraint_count (fun () ->
        M.main
          (Inputs.Impl.exists
             (Snarky.Typ.tuple5
                (typ M.Fp.Unpacked.typ Nat.N3.n)
                (typ M.Challenge.typ Nat.N9.n)
                (typ Inputs.Impl.Field.typ Nat.N3.n))) )
  in
  Core.printf "dlog-main: %d\n%!" n
*)
    (*
    module Field = struct
      open Impl

      (* The linear combinations involved in computing Poseidon do not involve very many
   variables, but if they are represented as arithmetic expressions (that is, "Cvars"
   which is what Field.t is under the hood) the expressions grow exponentially in
   in the number of rounds. Thus, we compute with Field elements represented by
   a "reduced" linear combination. That is, a coefficient for each variable and an
   constant term.
*)
      type t = Impl.field Int.Map.t * Impl.field

      let to_cvar ((m, c) : t) : Field.t =
        Map.fold m ~init:(Field.constant c) ~f:(fun ~key ~data acc ->
            let x =
              let v = Snarky.Cvar.Var key in
              if Field.Constant.equal data Field.Constant.one then v
              else Scale (data, v)
            in
            match acc with
            | Constant c when Field.Constant.equal Field.Constant.zero c ->
                x
            | _ ->
                Add (x, acc) )

      let constant c = (Int.Map.empty, c)

      let of_cvar (x : Field.t) =
        match x with
        | Constant c ->
            constant c
        | Var v ->
            (Int.Map.singleton v Field.Constant.one, Field.Constant.zero)
        | x ->
            let c, ts = Field.to_constant_and_terms x in
            ( Int.Map.of_alist_reduce
                (List.map ts ~f:(fun (f, v) -> (Impl.Var.index v, f)))
                ~f:Field.Constant.add
            , Option.value ~default:Field.Constant.zero c )

      let ( + ) (t1, c1) (t2, c2) =
        ( Map.merge t1 t2 ~f:(fun ~key:_ t ->
              match t with
              | `Left x ->
                  Some x
              | `Right y ->
                  Some y
              | `Both (x, y) ->
                  Some Field.Constant.(x + y) )
        , Field.Constant.add c1 c2 )

      let ( * ) (t1, c1) (t2, c2) =
        assert (Int.Map.is_empty t1) ;
        (Map.map t2 ~f:(Field.Constant.mul c1), Field.Constant.mul c1 c2)

      let zero : t = constant Field.Constant.zero
    end *)
