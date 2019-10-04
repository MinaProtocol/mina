open Core_kernel

module Domain = struct
  type t = Binary_roots_of_unity of int

  let size = function Binary_roots_of_unity k -> Int.pow 2 k

  module Expr = struct
    type nonrec t = Domain of t | Set_minus_input of t * int
  end
end

module C 
    (F : Free_monad.Functor.S2)
    (G : Free_monad.Functor.S2) = struct
  type ('a, 'e) t =
    | Outer of ('a, 'e) F.t
    | Inner of ('a, 'e) G.t

  let map t ~f =
    match t with
    | Outer x ->Outer (F.map x ~f)
    | Inner y -> Inner(G.map y ~f)
end

module type F2 = Free_monad.Functor.S2

module IP
    (Interaction : Free_monad.Functor.S2)
    (Computation : Free_monad.Functor.S2) = struct
  module F = struct
    type ('a, 'e) t =
      | Sample : ('field -> 'k) -> ('k, < field: 'field; ..>) t
      | Interact : ('a, 'e) Interaction.t -> ('a, 'e) t
      | Compute : ('a, 'e) Computation.t -> ('a, 'e) t

  let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
    fun t ~f ->
    match t with
    | Sample k -> Sample (fun x -> f (k x))
    | Interact x -> Interact (Interaction.map x ~f)
    | Compute x -> Compute (Computation.map x ~f)
  end

  include Free_monad.Make2(F)

  let interact x = Free (Interact x)
  let compute x = Free (Compute x)
  let sample = Free (Sample return)
end

module Map_computation (I : F2) (C1 : F2) (C2 : F2) (Eta : sig
    val f : ('a, 'e) C1.t -> ('a, 'e) IP(I)(C2).t
  end) = struct

  (* TODO: Not sure why I have to redefine this. *)
  let rec bind : type a b e.
    (a, e) IP(I)(C2).t -> f:(a -> (b, e) IP(I)(C2).t) -> (b, e) IP(I)(C2).t
      =
    fun t ~f ->
      match t with
      | Pure x -> f x
      | Free t ->
        Free (
        match t with
        | Sample k -> Sample (fun x -> bind ~f (k x))
        | Interact x -> Interact (I.map x ~f:(bind ~f))
        | Compute x -> Compute (C2.map x ~f:(bind ~f)))

  let rec f : type a e. (a, e) IP(I)(C1).t -> (a, e) IP(I)(C2).t =
    fun t ->
      match t with
      | Pure x -> Pure x
      | Free t ->
        match t with
        | Sample k ->  Free (Sample (fun x -> f (k x)))
        | Interact i -> Free (Interact (I.map i ~f))
        | Compute c ->  
          let ip =  (Eta.f c) in
          bind ip ~f 
end

module Map_interaction (C : F2) (I1 : F2) (I2 : F2) (Eta : sig
    val f : ('a, 'e) I1.t -> ('a, 'e) I2.t
  end) = struct
  let rec f : type a e. (a, e) IP(I1)(C).t -> (a, e) IP(I2)(C).t =
    fun t ->
      match t with
      | Pure x -> Pure x
      | Free t ->
        Free (match t with
        | Sample k ->  Sample (fun x -> f (k x))
        | Compute c ->  Compute (C.map c ~f)
        | Interact i -> Interact (I2.map (Eta.f i) ~f) )
end

module AHIOP (Inputs : sig
  module Verifier : Monad.S

  module Prover : Monad.S
end) =
struct

  module Arithmetic_expression = struct
    type 'f t =
      | Op of [`Add | `Sub | `Mul | `Div] * 'f t * 'f t
      | Constant of 'f
      | Int of int

    let op o x y = Op (o, x, y)

    let ( + ) x y = op `Add x y

    let ( - ) x y = op `Sub x y

    let ( * ) x y = op `Mul x y

    let ( / ) x y = op `Div x y

    let constant x = Constant x

    let int x = Int x

    let ( ! ) = constant
  end

  module Arithmetic_circuit = struct
    module F = struct
      type ('k, 'f) t =
        | Eval : 'f Arithmetic_expression.t * ('f -> 'k) -> ('k, 'f) t

      let map t ~f = match t with Eval (x, k) -> Eval (x, fun y -> f (k y))
    end

    module T = Free_monad.Make2 (F)

    include (T : module type of T with module Let_syntax := T.Let_syntax)

    let eval x = Free (Eval (x, return))

    module Let_syntax = struct
      module Let_syntax = T.Let_syntax
      include Let_syntax.Let_syntax
    end
  end

  module Random = struct
    type (_, _) t =
      | Sample : ('field -> 'k) -> ('k, < field: 'field; ..>) t

    let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
      fun t ~f ->
      match t with
      | Sample k -> Sample (fun x -> f (k x))
  end

  module Randomized = C(Random)

  module Arithmetic_computation = struct
    module F = struct
      type ('k, 'f) t =
        | Eval of 'f Arithmetic_expression.t * ('f -> 'k)
        | Assert_equal of
            'f Arithmetic_expression.t * 'f Arithmetic_expression.t * 'k

      let map t ~f =
        let cont k x = f (k x) in
        match t with
        | Eval (x, k) ->
            Eval (x, cont k)
        | Assert_equal (x, y, k) ->
            Assert_equal (x, y, f k)
    end

    include Free_monad.Make2 (F)

    let eval x = Free (Eval (x, return))

    let ( = ) x y = Free (Assert_equal (x, y, return ()))

    let rec circuit : type a f.
        (a, f) Arithmetic_circuit.t -> (a, f) t =
      fun t ->
      match t with
      | Pure x -> Pure x
      | Free (Eval (c, k)) -> Free  (Eval (c,  fun y -> circuit (k y)))
  end

  module Verifier = struct

    module AHP_query = struct
      module Interaction = struct
        type (_, _) t =
          | Query :
              (('poly, 'n) Vector.t * 'field * (('field, 'n) Vector.t -> 'k))
              -> ('k, < poly: 'poly ; field: 'field ; .. >) t

        let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
         fun t ~f ->
          match t with
          | Query (ps, x, k) ->
              Query (ps, x, fun res -> f (k res))
      end

      include Free_monad.Make2(Interaction)

      let query ps x = Free (Query (ps, x, return))
    end

    module Batch_AHP_arithmetic = struct
      module F = struct
        type ('k, _) t =
          | Arithmetic :
              ('k, 'field) Arithmetic_computation.F.t
              -> ('k, < field: 'field ; .. >) t
          | Query :
              (('poly, 'n) Vector.t * 'field * (('field, 'n) Vector.t -> 'k))
              -> ('k, < poly: 'poly ; field: 'field ; .. >) t

        let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
         fun t ~f ->
          match t with
          | Arithmetic a ->
              Arithmetic (Arithmetic_computation.F.map a ~f)
          | Query (ps, x, k) ->
              Query (ps, x, fun res -> f (k res))
      end

      include Free_monad.Make2 (F)

      let query ps x = Free (Query (ps, x, return))

      let eval x = Free (Arithmetic (Eval (x, return)))

      let ( = ) x y = Free (Arithmetic (Assert_equal (x, y, return ())))

      let rec circuit : type a f.
          (a, f) Arithmetic_circuit.t -> (a, < field: f ; .. >) t =
       fun t ->
        match t with
        | Pure x ->
            Pure x
        | Free (Eval (c, k)) ->
            Free (Arithmetic (Eval (c, fun y -> circuit (k y))))
    end

    module PCS_IP = struct
      module Interaction = struct
        module Message = struct
          type (_, _) t =
            | Evals :
                ('poly, 'n) Vector.t * 'field 
                -> (('field, 'n) Vector.t, < poly: 'poly; field: 'field; ..>) t
            | Proof :
                'poly * 'field * 'field
                -> ('pi, < poly: 'poly ; field: 'field; proof: 'pi; .. >) t
        end

        type (_, _) t =
          | Receive : ('a, 'e) Message.t * ('a -> 'k) -> ('k, 'e) t

        let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
          fun t ~f ->
          let cont k x = f (k x) in
          match t with
          | Receive (m, k) -> Receive (m, cont k)
      end

      module Computation = struct
        type ('k, _) t =
          | Arithmetic :
              ('k, 'field) Arithmetic_computation.F.t
              -> ('k, < field: 'field ; .. >) t
          | Scale_poly :
              'field * 'poly * ('poly -> 'k)
              -> ('k, < poly: 'poly ; field: 'field ; .. >) t
          | Add_poly :
              'poly * 'poly * ('poly -> 'k)
              -> ('k, < poly: 'poly ; .. >) t
          | Check_proof :
              'poly * 'field * 'field * 'pi * 'k
              -> ('k, < poly: 'poly ; field: 'field; proof: 'pi; .. >) t

        let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
          fun t ~f ->
          let cont k x = f (k x) in
          match t with
          | Arithmetic a ->
              Arithmetic (Arithmetic_computation.F.map a ~f)
          | Check_proof (poly, x, y, pi, k) ->
              Check_proof (poly, x, y, pi, f k)
          | Scale_poly (x, p, k) ->
              Scale_poly (x, p, cont k)
          | Add_poly (p, q, k) ->
              Add_poly (p, q, cont k)
      end
      include IP (Interaction)(Computation)

      let eval ps x = 
        interact (Receive (Evals (ps, x), return))

      let scale_poly x p = 
        compute (Scale_poly (x, p, return))

      let add_poly x y =
          compute (Add_poly (x, y, return))

      let field_op o x y =
        compute
          ((Arithmetic
              (Arithmetic_computation.F.Eval (Arithmetic_expression.(op o !x !y), return))))

      let add_field x y = field_op `Add x y

      let scale_field x y = field_op `Mul x y

      let get_and_check_proof poly ~input:x ~output:y =
        let%bind pi =
          interact (Receive (Proof (poly, x, y), return))
        in
        compute
          (Check_proof (poly, x, y, pi, return ()))

      let scaling ~scale ~add xi =
        let open Let_syntax in
        let rec go acc = function
          | [] ->
              return acc
          | p :: ps ->
              let%bind acc = scale xi acc >>= add p in
              go acc ps
        in
        function [] -> assert false | p :: ps -> go p ps

      (* TODO: Cata *)
      let rec ahp_compiler : type a.
        (a, < field: 'field ; poly: 'poly >) 
          AHP_query.t
        -> (a, < field: 'field ; poly: 'poly; proof: 'pi >) t =
        fun v ->
        match v with
        | Pure x ->
            Pure x
        | Free v -> (
          match v with
          | Query (ps, x, k) ->
              let open Let_syntax in
              let%bind vs = eval ps x in
              let%bind xi = sample in
              let%bind p =
                scaling ~scale:scale_poly ~add:add_poly xi
                  (Vector.to_list ps)
              and v =
                scaling ~scale:scale_field ~add:add_field xi
                  (Vector.to_list vs)
              in
              let%bind () = get_and_check_proof p ~input:x ~output:v in
              ahp_compiler (k vs) 
        )
    end


    module Pairing = struct
      module F = struct
        type ('k, _) t =
          | Arithmetic : ('k, 'f) Arithmetic_computation.F.t -> ('k, < field: 'f ; .. >) t
          | Scale :
              'f * 'g1 * ('g1 -> 'k)
              -> ('k, < field: 'f ; g1: 'g1 ; .. >) t
          | Add : 'g1 * 'g1 * ('g1 -> 'k) -> ('k, < g1: 'g1 ; .. >) t
          | Assert_equal :
              [`pair_H of 'g1] * [`pair_betaH of 'g1] * 'k
              -> ('k, < g1: 'g1 ; .. >) t

        let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
         fun t ~f ->
          let cont k x = f (k x) in
          match t with
          | Arithmetic k ->
              Arithmetic (Arithmetic_computation.F.map k ~f)
          | Scale (x, g, k) ->
              Scale (x, g, cont k)
          | Add (x, y, k) ->
              Add (x, y, cont k)
          | Assert_equal (p1, p2, k) ->
              Assert_equal (p1, p2, f k)
      end

      include Free_monad.Make2 (F)
    end

    let batch_pairing : type a field g1.
           (a, < field: field ; g1: g1 >) Pairing.t
           -> 
           (field ->
            ( a
            , < field: field ; g1: g1 > ) Pairing.t) =
     fun t ->
      let module E = struct
        type t = < field: field ; g1: g1 >
      end in
      let open Pairing.Let_syntax in
      let rec go (xi : field) (acc : (g1 * g1) option) (t : (a, E.t) Pairing.t)
          =
        match t with
        | Pure v ->
            Option.value_map acc ~default:(return v) ~f:(fun (x1, x2) ->
                let%map () =
                  Free
                    ((Assert_equal (`pair_H x1, `pair_betaH x2, return ())))
                in
                v )
        | Free t -> (
          match t with
          | Assert_equal (`pair_H p1, `pair_betaH p2, k) ->
              let%bind acc =
                Option.value_map acc
                  ~default:(return (p1, p2))
                  ~f:(fun (x1, x2) ->
                    let cons p x =
                      let%bind xi_x = Free ((Scale (xi, x, return))) in
                      Free ((Add (xi_x, p, return)))
                    in
                    let%map x1' = cons p1 x1 and x2' = cons p2 x2 in
                    (x1', x2') )
              in
              go xi (Some acc) k
          | _ ->
              Free (Pairing.F.map t ~f:(go xi acc))) 
      in
      fun xi ->
        go xi None t

    (* Pairing -> Random(Pairing) *)
  end

  module Hlist (F : sig
    type _ t
  end) =
  struct
    type _ t = [] : unit t | ( :: ) : 'a F.t * 'b t -> ('a * 'b) t
  end

  module Hlist2 (F : sig
    type (_, _) t
  end) =
  struct
    type (_, 's) t =
      | [] : (unit, _) t
      | ( :: ) : ('a, 's) F.t * ('b, 's) t -> ('a * 'b, 's) t
  end

  module Id = struct
    type 'a t = 'a
  end

  module HlistId = Hlist (Id)

  module Type = struct
    module rec T : sig
      type (_, _) t =
        | Field : ('field, < field: 'field ; .. >) t
        | Polynomial : int -> ('poly, < poly: 'poly ; .. >) t
        | Pair : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t
        | Vector : ('a, 'e) t * 'n Vector.nat -> (('a, 'n) Vector.t, 'e) t
        | Hlist : ('a, 'e) Hlist2(T).t -> ('a HlistId.t, 'e) t
        | Proof : ('proof, < proof: 'proof; ..>) t
    end =
      T

    module Hlist = Hlist2(T)

    include T

    let field = Field
  end

  let b = 1

  module Prover_message = struct
    type m = [`A | `B | `C]

    type ('field, 'poly) basic =
      [`Field of 'field | `X | `Poly of 'poly | `M_hat of m * 'field]

(* All degrees are actuall a strict upper bound on the degree *)
    type (_, _) t =
      | Sum :
          Domain.t
          * ((('field, 'poly) basic as 'lit), 'lit) Arithmetic_circuit.t
          -> ('field, < field: 'field ; poly: 'poly ; .. >) t
      | PCS : ('a, 'e) Verifier.PCS_arithmetic.Single.Interaction.Message.t
            -> ('a, 'e) t
      | Random_mask : int -> ('poly, < poly: 'poly ; .. >) t
      | W_hat :
          { degree: int
          ; domain: Domain.t
          ; input_size: int }
          -> ('poly, < poly: 'poly ; .. >) t
      | Mz_hat :
          { m: m
          ; b: int
          ; domain: Domain.t }
          -> ('poly, < poly: 'poly ; .. >) t
      | GH :
          Domain.t * ('field, 'poly) basic
          -> ('poly * 'poly, < field: 'field ; poly: 'poly ; .. >) t

    let type_ : type a e. (a, e) t -> (a, e) Type.t = function
      | Sum _ -> Field
      | Random_mask n -> Polynomial n
      | GH (domain, _expr) -> 
        let degree_g = Domain.size domain - 1 in
        let degree_h = failwith "TODO" in
        Pair (Polynomial degree_g, Polynomial degree_h)
      | W_hat { degree; _ } ->
        Polynomial degree
      | Mz_hat { domain; _ } ->
        Polynomial (Domain.size domain + b)
      | PCS (Evals (v, _)) ->
         Vector (Field, Vector.length v)
      | PCS (Proof  _) -> Proof

    let zk_only = function Random_mask _ -> true | _ -> false

    let sum dom e = Sum (dom, e)

    let random_mask d = Random_mask d

    let w_hat degree domain input_size = W_hat {degree; domain; input_size}

    let mz_hat ~b domain m = Mz_hat {domain; m; b}
  end

  (*

  module Prover_message = struct
    type (_, 'field, 'poly) t =
      | Get_sum
        : Domain.t
        -> ('field, 'field, 'poly)
  end
*)

  (*
    type ('k, 'who) t =
      | Prover : 'a Message_type.t * ('a -> ('k, [`V]) t) -> ('k, [`P]) t
      | Challenge : (Field.t -> ('k, [`P]) t) -> ('k, [`V]) t
      | Check : unit Verifier.t * ('k, [ `P ]) t -> ('k, [`V]) t
*)

  module Trivial_computation = struct
    type (_, _) t =
      | Nop : 'k -> ('k, _) t

    let map (Nop k) ~f = Nop (f k)
  end

  module Basic_IP = struct
    module Interaction = struct
      type ('k, 'env) t =
        | Send_and_receive
            (* Interactive *) :
            ('q, 'env) Type.t * 'q * ('r, 'env) Prover_message.t * ('r -> 'k)
            -> ('k, 'env) t

      let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
       fun t ~f ->
        let cont k x = f (k x) in
        match t with
        | Send_and_receive (t_q, q, t_r, k) ->
            Send_and_receive (t_q, q, t_r, cont k)
    end

    module Computation = Trivial_computation

    include IP(Interaction)(Computation)

    let send t_q q t_r =
      interact (Send_and_receive (t_q, q, t_r, return))

    let challenge m =
      let open Let_syntax in
      let%bind c = sample in
      let%map x = send Field c m in
      (c, x)

    module Of_PCS = struct
    end
  end

  module SNARK (Computation : F2) = struct
    module Proof_component = struct
      type (_, _) t =
        | Poly_eval :
            ('poly, 'n) Vector.t * 'field
            -> (('field, 'n) Vector.t, < poly: 'poly ; field: 'field ; .. >) t
        | Evaluation_proof :
            'poly * 'field * 'field
            -> ('pi, < pcs_proof: 'pi ; poly: 'poly ; field: 'field ; .. >) t
        | Prover_message
          : ('a, 'e) Prover_message.t
              -> ('a, 'e) t
    end

    module Hash_input = struct
      type 'e t =
        | Field : 'field -> < field: 'field ; .. > t
        | Polynomial : 'poly -> < poly: 'poly ; .. > t
        | PCS_proof : 'proof -> < proof: 'proof; ..> t
    end

    module F = struct
      type ('k, 'e) t =
        | Proof_component :
            ('r, 'e) Proof_component.t * ('r -> 'k)
            -> ('k, 'e) t
        | Compute : ('a, 'e) Computation.t -> ('a, 'e) t
        | Absorb : 'e Hash_input.t * 'k -> ('k, 'e) t
        | Squeeze : ('field -> 'k) -> ('k, < field: 'field ; .. >) t

      let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
       fun t ~f ->
        let cont k x = f (k x) in
        match t with
        | Compute c ->
          Compute (Computation.map c ~f)
        | Squeeze k ->
            Squeeze (cont k)
        | Absorb (h, k) ->
            Absorb (h, f k)
        | Proof_component (c, k) ->
            Proof_component (c, cont k)
    end

    include Free_monad.Make2 (F)

    let absorb x = Free (Absorb (x, return ()))

    let rec absorb_value : type x e. (x, e) Type.t -> x -> (unit, e) t =
      fun t x ->
      match t with
      | Field -> absorb (Field x)
      | Pair (t1, t2) ->
        let (x1, x2) = x in
        let%map () = absorb_value t1 x1
        and () = absorb_value t2 x2 in
        ()
      | Polynomial _ -> absorb (Polynomial x)
      | Hlist ts0 ->
        let rec go : type ts. (ts, e) Type.Hlist.t -> ts HlistId.t -> (unit, e) t =
          fun ts xs ->
            match ts, xs with
            | [], [] -> return ()
            | t :: ts, x :: xs ->
              let%bind () = absorb_value t x in
              go ts xs
        in
        go ts0 x
      | Proof ->
        absorb (PCS_proof x)
      | Vector (t, _n) ->
        let rec go : type n a. (a, e) Type.t -> (a, n) Vector.t -> (unit, e) t =
          fun ty xs ->
            match xs with
            | [] -> return ()
            | x :: xs ->
              let%bind () = absorb_value ty x in
              go ty xs
        in
        go t x

    type 'e pending_absorptions = (unit, 'e) t list

    let rec fiat_shamir
      : type a e. (unit, e) t list
        -> (a, e) IP(Basic_IP.Interaction)(Computation).t -> (e pending_absorptions * a, e) t =
      fun pending_absorptions t ->
      match t with
      | Pure x -> Pure (pending_absorptions, x)
      | Free (Compute c) ->
        Free (Compute (Computation.map c ~f:(fiat_shamir pending_absorptions))
             )
      | Free (Sample k) ->
        let%bind () = all_unit (List.rev pending_absorptions) in
        Free (Squeeze (fun x -> fiat_shamir [] (k x)))
      | Free (Interact (Send_and_receive (t_q, q, m, k))) ->
        let pending_absorptions =
          (absorb_value t_q q) :: pending_absorptions
        in
        Free (
          Proof_component
            (Prover_message m, fun r ->
                fiat_shamir
                  ((absorb_value (Prover_message.type_ m) r) :: pending_absorptions)
                  (k r)))

  end

  open Basic_IP

  let h = 5

  let d = 5

  let k = 5

  (*
Minimal zero knowledge query bound. The query algorithm of the AHP verifier V queries each prover
polynomial at exactly one location, regardless of the randomness used to generate the queries. In particular,
ŵ(X), ẑ A (X), ẑ B (X), ẑ C (X) are queried at exactly one location. So it suffices to set the parameter b := 1.
    *)
  (*
Eliminating σ 1 . We can sample the random polynomial s(X) conditioned on it summing to zero on H.
The prover can thus omit σ 1 , because it will always be zero, without affecting zero knowledge. *)
  (*. In particular, only the polynomials ŵ, ẑ A , ẑ B , ẑ C , s, h 1 , and g 1 need hiding
commitments. *)
    (* TODO: enforce the degree bounds on the g_i *)
  (*. When compiling our AHP, we need this feature only when committing to g 1 , g 2 , g 3 (the exact
degree bound matters for soundness) but for all other polynomials it suffices to rely on the maximum degree
bound and so for them we omit the shifted polynomials altogether. This increases the soundness error by a
negligible amount (which is fine), and lets us reduce argument size by 9 group elements. *)

  let w = 100

  let challenge t =
    let%bind x = sample in
    let%map r = send Field x t in
    (x, r)

  (* For simplicity we just handle 1 public input for now. *)
  let interpolate
      (* The first element of the domain is 1 *)
      (_domain : 'field Sequence.t) (values : 'field list) =
    match values with
    | [v] ->
        fun x ->
          let open Arithmetic_expression in
          !v * (x - int 1)
    | _ ->
        assert false

  let vanishing_poly (_domain : 'field Sequence.t) (prefix_length : int) =
    assert (prefix_length = 1) ;
    fun x ->
      let open Arithmetic_expression in
      x - int 1

  (* Section 5.3.2 *)
  let z_hat domain input w_hat =
    let open Arithmetic_expression in
    let input_length = List.length input in
    let x_hat = interpolate domain input in
    fun t -> (w_hat * vanishing_poly domain input_length t) + x_hat t

  module Domain = struct
    type t = Pow2_roots_of_unity of int

    let vanishing = function
      | Pow2_roots_of_unity k ->
          let rec go acc i =
            let open Arithmetic_expression in
            let open Arithmetic_circuit in
            if Int.(i = k) then eval (acc - int 1)
            else
              let%bind acc = eval (acc * acc) in
              go !acc Int.(i + 1)
          in
          fun x -> go x 1
  end

  let reduce xs ( + ) f =
    match xs with
    | [] ->
        assert false
    | x :: xs ->
        List.fold ~init:(f x) ~f:(fun acc x -> acc + f x) xs

  let all_but x0 = List.filter ~f:(fun x -> x <> x0)

  module Index = struct
    type m = [`A | `B | `C]

    type 'poly t = {row: m -> 'poly; col: m -> 'poly; value: m -> 'poly}
  end

  let domain_H = failwith "TODO"

  let domain_K = failwith "TODO"

  let get t =
    let%map x = send (Hlist []) [] t in
    x

  let r (type f) domain (alpha : f) =
    let open Arithmetic_expression in
    let open Arithmetic_circuit in
    let open Let_syntax in
    let v_H = Domain.vanishing domain in
    let%map v_H_alpha = v_H !alpha in
    fun y ->
      let%map v_H_y = v_H y in
      (!v_H_alpha - !v_H_y) / (!alpha - y)

  let ms : _ list = [`A; `B; `C]

  let protocol (type field poly) {Index.row; col; value} input :
      ( ( (unit, field) Arithmetic_computation.t
        , < field: field ; poly: poly ; .. > )
        Verifier.AHP_query.t
      , < field: field ; poly: poly ; .. > )
      Basic_IP.t =
    let input_size = List.length input in
    let open Let_syntax in
    let open Prover_message in
    let van d x =
      Arithmetic_computation.circuit (Domain.vanishing d x)
    in
    let v_K = van domain_K in
    let v_H = van domain_H in
    let f = Type.field in
    let open Arithmetic_expression in
    (* s can be ignored if we don't need zero knowledge *)
    (* z_C = z_A z_B + something v_H *)
    let%bind (s : poly) = get (random_mask Int.((2 * h) + b - 1)) in
    let%bind (sigma_1 : field) =
      get (sum domain_H (Arithmetic_circuit.eval !(`Poly s)))
    and w_hat = get (w_hat Int.(w + b) domain_H input_size)
    and z_A = get (mz_hat ~b domain_H `A)
    and z_B = get (mz_hat ~b domain_H `B) in
    let%bind (alpha : field) = sample
    and eta_A = sample
    and eta_B = sample
    and eta_C = sample in
    let eta = function `A -> eta_A | `B -> eta_B | `C -> eta_C in
    let%bind g_1, h_1 =
      send
        (Hlist [f; f; f; f])
        [alpha; eta_A; eta_B; eta_C]
        (GH (domain_H, failwith "TOD"))
    in
    let%bind beta_1 = sample in
    let%bind (sigma_2 : field) =
      get
        (let summand =
           let open Arithmetic_circuit in
           let open Let_syntax in
           let alpha = `Field alpha in
           let%bind r_alpha = r domain_H alpha in
           let%bind r_alpha_x = r_alpha !`X in
           eval
             ( r_alpha_x
             * reduce ms ( + ) (fun m ->
                   !(`Field (eta m)) * !(`M_hat (m, beta_1)) ) )
         in
         sum domain_H summand)
    in
    let%bind g_2, h_2 = send Field beta_1 (GH (domain_H, failwith "TODO")) in
    let%bind beta_2 = sample in
    let%bind sigma_3 = send Field beta_2 (sum domain_K (failwith "TOD")) in
    let%bind g_3, h_3 = get (GH (domain_K, failwith "TOD")) in
    let%bind beta_3 = sample in
    return
      (let open Verifier.AHP_query in
      let open Let_syntax in
      let%map [ h_3_beta_3
               ; g_3_beta_3
               ; row_A_beta_3
               ; row_B_beta_3
               ; row_C_beta_3
               ; col_A_beta_3
               ; col_B_beta_3
               ; col_C_beta_3
               ; value_A_beta_3
               ; value_B_beta_3
               ; value_C_beta_3 ] =
        query
          [ h_3
          ; g_3
          ; row `A
          ; row `B
          ; row `C
          ; col `A
          ; col `B
          ; col `C
          ; value `A
          ; value `B
          ; value `C ]
          beta_3
      and [h_2_beta_2; g_2_beta_2] = query [h_2; g_2] beta_2
      and [ h_1_beta_1
          ; g_1_beta_1
          ; z_B_beta_1
          ; z_A_beta_1
          ; w_hat_beta1
          ; s_beta_1 ] =
        query [h_1; g_1; z_B; z_A; w_hat; s] beta_1
      in
      let open Arithmetic_computation in
      let open Let_syntax in
      let%bind r_alpha =
        let%map f = circuit (r domain_H alpha) in
        fun y -> (f y)
      in
      let%bind a_beta_3, b_beta_3 =
        let abc a b c = function `A -> !a | `B -> !b | `C -> !c in
        let row = abc row_A_beta_3 row_B_beta_3 row_C_beta_3
        and col = abc col_A_beta_3 col_B_beta_3 col_C_beta_3
        and value = abc value_A_beta_3 value_B_beta_3 value_C_beta_3 in
        let%map a =
          let%map v_H_beta_2 = v_H !beta_2 and v_H_beta_1 = v_H !beta_1 in
          reduce ms ( + ) (fun m ->
              !(eta m)
              * !v_H_beta_2 * !v_H_beta_1 * value m
              * reduce (all_but m ms) ( * ) (fun n ->
                    (!beta_2 - row n) * (!beta_1 * col n) ) )
        in
        let b =
          reduce ms ( * ) (fun m -> (!beta_2 - row m) * (!beta_1 - col m))
        in
        (a, b)
      in
      let%bind v_K_beta_3 = v_K !beta_3
      and v_H_beta_1 = v_H !beta_1
      and v_H_beta_2 = v_H !beta_2 in
      let%bind r_alpha_beta_1 = circuit (r_alpha !beta_1)
      and r_alpha_beta_2 = circuit (r_alpha !beta_2) in
      let z_hat_beta_1 =
        z_hat Sequence.empty (* TODO *) input !w_hat_beta1 !beta_1
      in
      let z_C_beta_1 = !z_A_beta_1 * !z_B_beta_1 in
      all_unit
        [ !h_3_beta_3 * !v_K_beta_3
          = a_beta_3
            - (b_beta_3 * ((!beta_3 * !g_3_beta_3) + (!sigma_3 / int k)))
        ; r_alpha_beta_2 * !sigma_3
          = (!h_2_beta_2 * !v_H_beta_2)
            + (!beta_2 * !g_2_beta_2)
            + (!sigma_2 / int h)
        ; !s_beta_1
          + r_alpha_beta_1
            * ( (!eta_A * !z_A_beta_1) + (!eta_B * !z_B_beta_1)
              + (!eta_C * z_C_beta_1) )
          - (!sigma_2 * z_hat_beta_1)
          = (!h_1_beta_1 * !v_H_beta_1)
            + (!beta_1 * !g_1_beta_1)
            + (!sigma_1 / int h) ])

  module S = SNARK(Trivial_computation)

  let p  = protocol (failwith "TODO") []
  let p  = Basic_IP.map p
      ~f:Verifier.PCS_arithmetic.Single.ahp_compiler
  let _ = p
  let _ = p
(*   let p = S.fiat_shamir [(* Input goes here *)] p *)
end

type domain = I | L | H | K

module Oracle = struct
  type t = F_input | F_A
end
