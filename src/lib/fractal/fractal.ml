open Core_kernel
open Hlist

module type F2 = Free_monad.Functor.S2

type m = A | B | C


(* b from the paper *)
let zk_margin = 1

let gen_name =
  let r = ref (-1) in
  fun () -> incr r ; sprintf "a%d" !r

let reduce xs ( + ) f =
  match xs with
  | [] ->
      assert false
  | x :: xs ->
      List.fold ~init:(f x) ~f:(fun acc x -> acc + f x) xs

let sum xs f = reduce xs Arithmetic_expression.( + ) f

let product xs f = reduce xs Arithmetic_expression.( * ) f

module AHIOP = struct
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

      let to_statement ~assert_equal ~constant ~int ~negate ~op =
        let expr = Arithmetic_expression.to_expr ~constant ~int ~op ~negate in
        function
        | Eval (e, k) ->
            let name = gen_name () in
            (Statement.Assign (name, expr e), k (Expr.Var name))
        | Assert_equal (x, y, k) ->
            (assert_equal (expr x) (expr y), k)

      let to_program ~assert_equal ~constant ~int ~negate  ~op t =
        let s, k = to_statement ~assert_equal ~constant ~int ~negate ~op t in
        ([s], k)
    end

    include Free_monad.Make2 (F)

    let to_program ~assert_equal ~constant ~int ~negate ~op =
      let rec go : type a. (a, 'f) t -> Program.t -> Program.t * a =
       fun t acc ->
        match t with
        | Pure x ->
            (List.rev acc, x)
        | Free f ->
            let s, k = F.to_statement f ~assert_equal ~constant ~int ~negate ~op in
            go k (s :: acc)
      in
      fun t -> go t []

    let eval x = Free (Eval (x, return))

    let ( = ) x y = Free (Assert_equal (x, y, return ()))

    let rec circuit : type a f. (a, f) Arithmetic_circuit.t -> (a, f) t =
     fun t ->
      match t with
      | Pure x ->
          Pure x
      | Free (Eval (c, k)) ->
          Free (Eval (c, fun y -> circuit (k y)))
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

  module AHP = struct
    module Interaction = struct
      type (_, _) t =
        | Query :
            (('poly, 'n) Vector.t * 'field * (('field, 'n) Vector.t -> 'k))
            -> ('k, < poly: 'poly ; field: 'field ; .. >) t

      let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
       fun t ~f ->
        match t with Query (ps, x, k) -> Query (ps, x, fun res -> f (k res))
    end

    include Free_monad.Make2 (Interaction)

    let query ps x = Free (Query (ps, x, return))

    let query ps x =
      query ps x >>| Vector.map ~f:Arithmetic_expression.constant
  end

  module PCS_IP = struct
    module Interaction = struct
      module Message = struct
        type (_, _) t =
          | Evals :
              ('poly, 'n) Vector.t * 'field
              -> ( ('field, 'n) Vector.t
                 , < poly: 'poly ; field: 'field ; .. > )
                 t
          | Proof :
              'poly * 'field * 'field
              -> ('pi, < poly: 'poly ; field: 'field ; proof: 'pi ; .. >) t
      end

      type (_, _) t = Receive : ('a, 'e) Message.t * ('a -> 'k) -> ('k, 'e) t

      let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
       fun t ~f ->
        let cont k x = f (k x) in
        match t with Receive (m, k) -> Receive (m, cont k)
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
            -> ('k, < poly: 'poly ; field: 'field ; proof: 'pi ; .. >) t

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

    include Ip.T (Interaction) (Computation)

    let eval ps x = interact (Receive (Evals (ps, x), return))

    let scale_poly x p = compute (Scale_poly (x, p, return))

    let add_poly x y = compute (Add_poly (x, y, return))

    let field_op o x y =
      compute
        (Arithmetic
           (Arithmetic_computation.F.Eval
              (Arithmetic_expression.(op o !x !y), return)))

    let add_field x y = field_op `Add x y

    let scale_field x y = field_op `Mul x y

    let get_and_check_proof poly ~input:x ~output:y =
      let%bind pi = interact (Receive (Proof (poly, x, y), return)) in
      compute (Check_proof (poly, x, y, pi, return ()))

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
           (a, < field: 'field ; poly: 'poly >) AHP.t
        -> (a, < field: 'field ; poly: 'poly ; proof: 'pi >) t =
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
              scaling ~scale:scale_poly ~add:add_poly xi (Vector.to_list ps)
            and v =
              scaling ~scale:scale_field ~add:add_field xi (Vector.to_list vs)
            in
            let%bind () = get_and_check_proof p ~input:x ~output:v in
            ahp_compiler (k vs) )
  end

  module Verifier = struct
    module Pairing = struct
      module F = struct
        type ('k, _) t =
          | Arithmetic :
              ('k, 'f) Arithmetic_computation.F.t
              -> ('k, < field: 'f ; .. >) t
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
        -> field
        -> (a, < field: field ; g1: g1 >) Pairing.t =
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
                  Free (Assert_equal (`pair_H x1, `pair_betaH x2, return ()))
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
                      let%bind xi_x = Free (Scale (xi, x, return)) in
                      Free (Add (xi_x, p, return))
                    in
                    let%map x1' = cons p1 x1 and x2' = cons p2 x2 in
                    (x1', x2') )
              in
              go xi (Some acc) k
          | _ ->
              Free (Pairing.F.map t ~f:(go xi acc)) )
      in
      fun xi -> go xi None t

    (* Pairing -> Random(Pairing) *)
  end

  let abc a b c = function A -> a | B -> b | C -> c

  module Index = struct
    type 'poly t = {row: m -> 'poly; col: m -> 'poly; value: m -> 'poly}
  end

  module Fractal = struct
    module Fof = struct
      let add (p1, q1) (p2, q2) =
        let open Arithmetic_expression in
        let denom = (q1 * q2)
        and num = (p1*q2 + p2*q1) in
        (num, denom)
    end

    module Prover_message = struct
      let ell : Domain.t = failwith "todo"

      type ('field, 'poly) basic =
        [`Field of 'field | `X | `Poly of 'poly | `M_hat of m * 'field]

      type ('a, 'env) t =
        | F_w :
            { input : 'field list
            ; h: Domain.t }
            -> ('poly, < poly: 'poly; field: 'field; .. >) t
        | Mz_random_extension :
            { m: m
            ; b: int
            ; h : Domain.t }
            -> ('poly, < poly: 'poly ; .. >) t
        | Random_summing_to_zero :
            { h : Domain.t
            ; degree : int }
            -> ('poly, < poly: 'poly ; .. >) t
        | Linear_combination :
            ('field * [`u of m * 'field]) list 
            -> ('poly, < poly: 'poly ; field: 'field; .. >) t
        | Eval : 'poly * 'field
            -> ('poly, < poly: 'poly ; field: 'field; .. >) t
        | Sigma_residue
          : { f : [`Field of 'field | `Poly of 'poly] Arithmetic_expression.t
            ; q : [`Field of 'field | `Poly of 'poly] Arithmetic_expression.t
            ; domain : Domain.t }
        (* Given f, q, sigma, and domain H,
           compute g such that exists h such that

           Sigma_H(g, sigma) q + h v_H = f.

           g can be computed as

           (* r + h v_H = f *)
           let (h, r) = div_mod(f, v_H) in 
           ((r / q) - sigma / |H|) / X
        *)
            -> ('poly, < poly: 'poly ; field: 'field; .. >) t
    end

    module Basic_IP = struct
      module Interaction = Messaging.F(Prover_message)
      module Computation = Arithmetic_circuit.F
      include Ip.T (Interaction) (Computation)

      let send t_q q t_r = interact (Send_and_receive (t_q, q, t_r, return))

      let challenge m =
        let open Let_syntax in
        let%bind c = sample in
        let%map x = send Field c m in
        (c, x)

      let receive t =
        let%map x = send (Hlist []) [] t in
        x

      let interact ~send:q ~receive =
        let n = Vector.length q in
        send (Type.Vector (Field, n)) q receive
    end

    open Basic_IP

    let sample_eta () =
      let%map a = sample
      and b = sample
      and c = sample in
      abc a b c 

    (* Sigma_S(g, sigma) = X g(X) + sigma / |S| *)

(* g_1 such that exists h 

   X g_1(X) + h v_H = f.

   let (q, r) such that
     { f = v_H q + r}
    =
    div_mod (f, v_H)
   in
*)

    let abc f =
      let%map a = f A
      and b = f B
      and c = f C in
      abc a b c

    let protocol (type poly field) { Index.row; col; value } b domain_H domain_K (input : field list) : ('a, < field: field; poly: poly; ..>) t =
      let%bind f_w = receive (F_w { input; h=domain_H })
      and f_ = abc (fun m ->receive (Mz_random_extension { m; h=domain_H; b}) )
      and r = receive (Random_summing_to_zero { h=domain_H; degree=2 * Domain.size domain_H + b - 2 })
      in
      let%bind alpha = sample in
      let%bind eta = abc (fun _ -> sample) in
      let%bind t =
        interact ~send:[ alpha; eta A; eta B; eta C ]
          ~receive:(
            Linear_combination (List.map [A;B;C]  ~f:(fun m ->
                (eta m, `u (m, alpha)))))
      in
      let open Arithmetic_expression in
      let%bind g_1 =
        let f_x = failwith "TODO" in
        let u_H _ = failwith "TODO" in
        let f =
          !(`Poly r) - !(`Poly t) * f_x + sum [A;B;C] (fun m ->
            !(`Field (eta m)) * u_H alpha * f_ m )
        in
        receive
          (Sigma_residue { f; q=Int 1; domain=domain_H })
      in
      let%bind beta = sample in
      let%bind gamma =
        interact
          ~send:[beta]
          ~receive:(Eval (t, beta))
      in
      let%bind g_2 =
        let%bind v_H_alpha_v_H_beta =
          let v_H x = Domain.vanishing domain_H x in
          lift_compute Arithmetic_circuit.(
              let%bind (a : field) = v_H (!alpha)
              and (b : field) = v_H (!beta)
              in
              eval (!a * !b)
            )
        in
        let open Arithmetic_expression in
        let f, q =
          let top, bot =
            reduce [A;B;C] Fof.add (fun m ->
                let (/) = Tuple2.create in
                (! (`Field (eta m)) * value m) / 
                ((! (`Field alpha) - row m) * (! (`Field beta) - col m)) )
          in
          (Negate (! (`Field v_H_alpha_v_H_beta)) * top, bot)
        in
        let message = Prover_message.Sigma_residue { f; q; domain= domain_K } in
        receive
          ()
      in
      return ()
  end

  module Marlin_prover_message = struct
    type ('field, 'poly) basic =
      [`Field of 'field | `X | `Poly of 'poly | `M_hat of m * 'field]

    (* All degrees are actuall a strict upper bound on the degree *)
    type (_, _) t =
      | Sum :
          Domain.t
          * ((('field, 'poly) basic as 'lit), 'lit) Arithmetic_circuit.t
          -> ('field, < field: 'field ; poly: 'poly ; .. >) t
      | PCS : ('a, 'e) PCS_IP.Interaction.Message.t -> ('a, 'e) t
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
      | Sum _ ->
          Field
      | Random_mask n ->
          Polynomial n
      | GH (domain, _expr) ->
          let degree_g = Domain.size domain - 1 in
          let degree_h = failwith "TODO" in
          Pair (Polynomial degree_g, Polynomial degree_h)
      | W_hat {degree; _} ->
          Polynomial degree
      | Mz_hat {domain; _} ->
          Polynomial (Domain.size domain + zk_margin)
      | PCS (Evals (v, _)) ->
          Vector (Field, Vector.length v)
      | PCS (Proof _) ->
          Proof

    let zk_only = function Random_mask _ -> true | _ -> false

    let domain_sum dom e = Sum (dom, e)

    let random_mask d = Random_mask d

    let w_hat degree domain input_size = W_hat {degree; domain; input_size}

    let mz_hat domain m = Mz_hat {domain; m; b= zk_margin}
  end

  module Basic_IP = struct
    module Interaction = Messaging.F(Marlin_prover_message)
    module Computation = Trivial_computation
    include Ip.T (Interaction) (Computation)

    let send t_q q t_r = interact (Send_and_receive (t_q, q, t_r, return))

    let challenge m =
      let open Let_syntax in
      let%bind c = sample in
      let%map x = send Field c m in
      (c, x)

    module Of_PCS = struct end
  end

  module SNARK (Computation : F2) = struct
    module Proof_component = Marlin_prover_message

    module Hash_input = struct
      type 'e t =
        | Field : 'field -> < field: 'field ; .. > t
        | Polynomial : 'poly -> < poly: 'poly ; .. > t
        | PCS_proof : 'proof -> < proof: 'proof ; .. > t
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
      | Field ->
          absorb (Field x)
      | Pair (t1, t2) ->
          let x1, x2 = x in
          let%map () = absorb_value t1 x1 and () = absorb_value t2 x2 in
          ()
      | Polynomial _ ->
          absorb (Polynomial x)
      | Hlist ts0 ->
          let rec go : type ts.
              (ts, e) Type.Hlist.t -> ts HlistId.t -> (unit, e) t =
           fun ts xs ->
            match (ts, xs) with
            | [], [] ->
                return ()
            | t :: ts, x :: xs ->
                let%bind () = absorb_value t x in
                go ts xs
          in
          go ts0 x
      | Proof ->
          absorb (PCS_proof x)
      | Vector (t, _n) ->
          let rec go : type n a.
              (a, e) Type.t -> (a, n) Vector.t -> (unit, e) t =
           fun ty xs ->
            match xs with
            | [] ->
                return ()
            | x :: xs ->
                let%bind () = absorb_value ty x in
                go ty xs
          in
          go t x

    type field = Expr.t

    module Poly = struct
      type basic = Expr.t

      type 'poly expr =
        [`Scale of field * 'poly | `Add of 'poly * 'poly | `Constant of basic]

      type t =
        { expr: t expr
        ; commitment: Expr.t Lazy.t
        ; evaluations: Expr.t Expr.Table.t }

      let commitment t = Lazy.force t.commitment

      let add ~append_lines ~add_commitment t1 t2 =
        { expr= `Add (t1, t2)
        ; commitment=
            lazy
              (let c1 = Lazy.force t1.commitment in
               let c2 = Lazy.force t2.commitment in
               let name = gen_name () in
               append_lines [Statement.Assign (name, add_commitment c1 c2)] ;
               Var name)
        ; evaluations= Expr.Table.create () }

      let scale ~append_lines ~scale_commitment x t =
        { expr= `Scale (x, t)
        ; commitment=
            lazy
              (let name = gen_name () in
               append_lines
                 [ Statement.Assign
                     (name, scale_commitment x (Lazy.force t.commitment)) ] ;
               Var name)
        ; evaluations= Expr.Table.create () }

      (* This isn't necessarily the most efficient way to evaluate things, 
   but probably it is negligible compared to the cost of e.g., doing
   mulit-exps. *)
      let eval ~eval_poly ~add_field ~mul_field =
        let rec eval t x =
          Hashtbl.find_or_add t.evaluations x ~default:(fun () ->
              match t.expr with
              | `Constant p ->
                  eval_poly p x
              | `Add (t1, t2) ->
                  add_field (eval t1 x) (eval t2 x)
              | `Scale (s, t) ->
                  mul_field s (eval t x) )
        in
        eval
    end

    type env = < field: field ; poly: Poly.t ; proof: Expr.t >

    module Compiler (F : sig
      type (_, _) t
    end) =
    struct
      type t =
        { f:
            'a.    append_lines:(Program.t -> unit) -> ('a, env) F.t
            -> Program.t * 'a }
    end

    type compute = Compiler(Computation).t

    module Proof = struct
      type t =
        { field_elements: Expr.t list
        ; polynomials: Expr.t list
        ; pcs_proofs: Expr.t list }
      [@@deriving fields]

      let to_expr {field_elements; polynomials; pcs_proofs} =
        Expr.Struct
          [ ("field_elements", Array field_elements)
          ; ("polynomials", Array polynomials)
          ; ("pcs_proofs", Array pcs_proofs) ]

      let empty = {field_elements= []; polynomials= []; pcs_proofs= []}

      let rev_append t1 t2 =
        let a f = List.rev_append (Field.get f t1) (Field.get f t2) in
        Fields.map ~field_elements:a ~polynomials:a ~pcs_proofs:a

      let rev (t : t) =
        let r f = List.rev (Field.get f t) in
        Fields.map ~field_elements:r ~polynomials:r ~pcs_proofs:r

      let rec cons : type a. (a, env) Type.t * a -> t -> t =
       fun (ty, x) t ->
        let field = Fields.field_elements in
        let poly = Fields.polynomials in
        let proof = Fields.pcs_proofs in
        let fcons f x = Field.map f t ~f:(List.cons x) in
        match ty with
        | Vector (ty, _) ->
            List.fold (Vector.to_list x)
              ~f:(fun acc x -> cons (ty, x) acc)
              ~init:t
        | Field ->
            fcons field x
        | Polynomial _ ->
            fcons poly (Poly.commitment x)
        | Proof ->
            fcons proof x
        | Pair (ty1, ty2) ->
            let x1, x2 = x in
            cons (ty1, x1) t |> cons (ty2, x2)
        | Hlist ts ->
            let rec go : type xs.
                (xs, env) Type.Hlist.t -> xs HlistId.t -> t -> t =
             fun tys xs t ->
              match (tys, xs) with
              | [], [] ->
                  t
              | ty :: tys, x :: xs ->
                  go tys xs (cons (ty, x) t)
            in
            go ts x t

      let cons (c, x) t = cons (Proof_component.type_ c, x) t
    end

    let prover ~(compute : compute) ~(prove : Compiler(Proof_component).t)
        ~absorb ~squeeze ~initialize =
      let acc = ref [] in
      let append_lines lines = acc := List.rev_append lines !acc in
      let rec go proof t =
        match t with
        | Pure _ ->
            proof
        | Free (Compute c) ->
            let lines, k = compute.f c ~append_lines in
            append_lines lines ; go proof k
        | Free (Absorb (x, k)) ->
            append_lines (absorb x) ;
            go proof k
        | Free (Proof_component (c, k)) ->
            let lines, pi = prove.f c ~append_lines in
            append_lines lines ;
            go (Proof.cons (c, pi) proof) (k pi)
        | Free (Squeeze k) ->
            let lines, challenge = squeeze () in
            append_lines lines ;
            go proof (k challenge)
      in
      fun t ->
        acc := [initialize] ;
        let proof = go Proof.empty t in
        let proof = Proof.rev proof in
        List.rev (Statement.Return (Proof.to_expr proof) :: !acc)

    type 'e pending_absorptions = (unit, 'e) t list

    let rec fiat_shamir : type a e.
           (unit, e) t list
        -> (a, e) Ip.T(Basic_IP.Interaction)(Computation).t
        -> (e pending_absorptions * a, e) t =
     fun pending_absorptions t ->
      match t with
      | Pure x ->
          Pure (pending_absorptions, x)
      | Free (Compute c) ->
          Free
            (Compute (Computation.map c ~f:(fiat_shamir pending_absorptions)))
      | Free (Sample k) ->
          let%bind () = all_unit (List.rev pending_absorptions) in
          Free (Squeeze (fun x -> fiat_shamir [] (k x)))
      | Free (Interact (Send_and_receive (t_q, q, m, k))) ->
          let pending_absorptions =
            absorb_value t_q q :: pending_absorptions
          in
          Free
            (Proof_component
               ( m
               , fun r ->
                   fiat_shamir
                     ( absorb_value (Marlin_prover_message.type_ m) r
                     :: pending_absorptions )
                     (k r) ))
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

  let all_but x0 = List.filter ~f:(fun x -> x <> x0)

  let domain_H = failwith "TODO"

  let domain_K = failwith "TODO"

  let receive t =
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

  let vanishing_polynomial d x =
    let open Arithmetic_expression in
    Arithmetic_computation.(circuit (Domain.vanishing d x) >>| constant)

  (* Radically fair environment *)

  let query' HlistId.[h_3; g_3 ; row; col; value] beta_3 =
    let open AHP in
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
        ; row A
        ; row B
        ; row C
        ; col A
        ; col B
        ; col C
        ; value A
        ; value B
        ; value C ]
        beta_3
    in
    HlistId.[ h_3_beta_3
    ; g_3_beta_3
          ; abc row_A_beta_3 row_B_beta_3 row_C_beta_3
          ; abc col_A_beta_3 col_B_beta_3 col_C_beta_3
          ; abc value_A_beta_3 value_B_beta_3 value_C_beta_3
    ]


  let interact ~send:q ~receive =
    let n = Vector.length q in
    send (Type.Vector (Field, n)) q receive

  let ( ->! ) send receive = interact ~send ~receive

  let ( !<- ) = receive

  let assert_all = Arithmetic_computation.all_unit

  open Marlin_prover_message
  open Arithmetic_expression

  let todo = failwith "TODO"

  let protocol {Index.row; col; value} input =
    let input_size = List.length input in
    let v_K = vanishing_polynomial domain_K in
    let v_H = vanishing_polynomial domain_H in
    (* s can be ignored if we don't need zero knowledge *)
    let%bind s        = receive (random_mask Int.((2 * h) + zk_margin - 1)) in
    let%bind sigma_1  = receive (domain_sum domain_H (Arithmetic_circuit.eval !(`Poly s)))
    and w_hat         = receive (w_hat Int.(w + zk_margin) domain_H input_size)
    and z_A           = receive (mz_hat domain_H A)
    and z_B           = receive (mz_hat domain_H B) in
    let%bind alpha    = sample
    and eta_A         = sample
    and eta_B         = sample
    and eta_C         = sample in
    let eta           = abc eta_A eta_B eta_C in
    let%bind g_1, h_1 = interact ~send:[alpha; eta_A; eta_B; eta_C] ~receive:(GH (domain_H, todo)) in
    let%bind beta_1   = sample in
    let%bind sigma_2  =
      receive
        (let summand =
           let open Arithmetic_circuit in
           let%bind r_alpha = r domain_H (`Field alpha) in
           let%bind r_alpha_x = r_alpha !`X in
           eval
             ( r_alpha_x
             * sum [A; B; C] (fun m ->
                   !(`Field (eta m)) * !(`M_hat (m, beta_1)) ) )
         in
         domain_sum domain_H summand)
    in
    let%bind g_2, h_2 = interact ~send:[beta_1] ~receive:(GH (domain_H, todo)) in
    let%bind beta_2   = sample in
    let%bind sigma_3  = interact ~send:[beta_2] ~receive:(domain_sum domain_K todo) in
    let%bind g_3, h_3 = receive (GH (domain_K, todo)) in
    let%map beta_3    = sample in
    let open AHP in
    let%map [ h_3_beta_3; g_3_beta_3; row; col; value ] =
      query' [ h_3; g_3; row; col; value ] beta_3
    and [h_2_beta_2; g_2_beta_2] =
      query [h_2; g_2] beta_2
    and [ h_1_beta_1; g_1_beta_1; z_B_beta_1; z_A_beta_1; w_hat_beta1; s_beta_1 ] =
      query [h_1; g_1; z_B; z_A; w_hat; s] beta_1
    in
    let open Arithmetic_computation in
    let%bind r_alpha =
      let%map f = circuit (r domain_H alpha) in
      fun y -> circuit (f y)
    in
    let eta x = !(eta x) in
    let beta_1, beta_2, beta_3 = !beta_1, !beta_2, !beta_3 in
    let sigma_1, sigma_2, sigma_3 = !sigma_1, !sigma_2, !sigma_3 in
    let%bind a_beta_3, b_beta_3 =
      let%map a =
        let%map v_H_beta_2 = v_H beta_2 and v_H_beta_1 = v_H beta_1 in
        sum [A; B; C] (fun m ->
            eta m * v_H_beta_2 * v_H_beta_1 * value m
            * product
                (all_but m [A; B; C])
                (fun n -> (beta_2 - row n) * (beta_1 * col n)) )
      in
      let b =
        product [A; B; C] (fun m -> (beta_2 - row m) * (beta_1 - col m))
      in
      (a, b)
    in
    let%bind v_K_beta_3 = v_K beta_3
    and v_H_beta_1 = v_H beta_1
    and v_H_beta_2 = v_H beta_2
    and r_alpha_beta_1 = r_alpha beta_1
    and r_alpha_beta_2 = r_alpha beta_2 in
    let z_hat_beta_1 =
      z_hat Sequence.empty (* TODO *) input w_hat_beta1 beta_1
    in
    let z_C_beta_1 = z_A_beta_1 * z_B_beta_1 in
    assert_all
      [ h_3_beta_3 * v_K_beta_3
        = a_beta_3
          - (b_beta_3 * ((beta_3 * g_3_beta_3) + (sigma_3 / int k)))
      ; r_alpha_beta_2 * sigma_3
        = (h_2_beta_2 * v_H_beta_2) + (beta_2 * g_2_beta_2)
          + (sigma_2 / int h)
      ; s_beta_1
        + r_alpha_beta_1
          * ( (eta A * z_A_beta_1)
            + (eta B * z_B_beta_1)
            + (eta C * z_C_beta_1) )
        - (sigma_2 * z_hat_beta_1)
        = (h_1_beta_1 * v_H_beta_1) + (beta_1 * g_1_beta_1)
          + (sigma_1 / int h) ]

  module type IP_intf = sig
    type field
    type poly
    type e = < field: field; poly: poly >
    val receive : ('a, e) Marlin_prover_message.t -> 'a
    val sample : unit -> field
    val send : (field, 'n) Vector.t -> unit
  end

  type ('f, 'p) ip = (module IP_intf with type field = 'f and type poly = 'p)

  let protocol (type f p) ((module IP) : (f, p) ip) {Index.row; col; value} input =
    let open IP in
    let input_size = List.length input in
    let v_K = vanishing_polynomial domain_K in
    let v_H = vanishing_polynomial domain_H in
    (* s can be ignored if we don't need zero knowledge *)
    let s       = receive (random_mask Int.((2 * h) + zk_margin - 1)) in
    let sigma_1 = receive (domain_sum domain_H (Arithmetic_circuit.eval !(`Poly s))) in
    let w_hat   = receive (w_hat Int.(w + zk_margin) domain_H input_size) in
    let z_A     = receive (mz_hat domain_H A) in
    let z_B     = receive (mz_hat domain_H B) in
    let alpha   = sample () in
    let eta_A   = sample () in
    let eta_B   = sample () in
    let eta_C   = sample () in
    let eta     = abc eta_A eta_B eta_C in
    send [alpha; eta_A; eta_B; eta_C] ;
    let g_1, h_1 = receive (GH (domain_H, todo)) in
    let beta_1   = sample () in
    let sigma_2  =
      receive
        (let summand =
           let open Arithmetic_circuit in
           let%bind r_alpha = r domain_H (`Field alpha) in
           let%bind r_alpha_x = r_alpha !`X in
           eval
             ( r_alpha_x
             * sum [A; B; C] (fun m ->
                   !(`Field (eta m)) * !(`M_hat (m, beta_1)) ) )
         in
         domain_sum domain_H summand)
    in
    send [beta_1];
    let g_2, h_2 = receive (GH (domain_H, todo)) in
    let beta_2   = sample () in
    send [ beta_2 ];
    let sigma_3  = receive (domain_sum domain_K todo) in
    let g_3, h_3 = receive (GH (domain_K, todo)) in
    let beta_3   = sample () in
    let open AHP in
    let%map [ h_3_beta_3; g_3_beta_3; row; col; value ] =
      query' [ h_3; g_3; row; col; value ] beta_3
    and [h_2_beta_2; g_2_beta_2] =
      query [h_2; g_2] beta_2
    and [ h_1_beta_1; g_1_beta_1; z_B_beta_1; z_A_beta_1; w_hat_beta1; s_beta_1 ] =
      query [h_1; g_1; z_B; z_A; w_hat; s] beta_1
    in
    let open Arithmetic_computation in
    let%bind r_alpha =
      let%map f = circuit (r domain_H alpha) in
      fun y -> circuit (f y)
    in
    let eta x = !(eta x) in
    let beta_1, beta_2, beta_3 = !beta_1, !beta_2, !beta_3 in
    let sigma_1, sigma_2, sigma_3 = !sigma_1, !sigma_2, !sigma_3 in
    let%bind a_beta_3, b_beta_3 =
      let%map a =
        let%map v_H_beta_2 = v_H beta_2 and v_H_beta_1 = v_H beta_1 in
        sum [A; B; C] (fun m ->
            eta m * v_H_beta_2 * v_H_beta_1 * value m
            * product
                (all_but m [A; B; C])
                (fun n -> (beta_2 - row n) * (beta_1 * col n)) )
      in
      let b =
        product [A; B; C] (fun m -> (beta_2 - row m) * (beta_1 - col m))
      in
      (a, b)
    in
    let%bind v_K_beta_3 = v_K beta_3
    and v_H_beta_1 = v_H beta_1
    and v_H_beta_2 = v_H beta_2
    and r_alpha_beta_1 = r_alpha beta_1
    and r_alpha_beta_2 = r_alpha beta_2 in
    let z_hat_beta_1 =
      z_hat Sequence.empty (* TODO *) input w_hat_beta1 beta_1
    in
    let z_C_beta_1 = z_A_beta_1 * z_B_beta_1 in
    assert_all
      [ h_3_beta_3 * v_K_beta_3
        = a_beta_3
          - (b_beta_3 * ((beta_3 * g_3_beta_3) + (sigma_3 / int k)))
      ; r_alpha_beta_2 * sigma_3
        = (h_2_beta_2 * v_H_beta_2) + (beta_2 * g_2_beta_2)
          + (sigma_2 / int h)
      ; s_beta_1
        + r_alpha_beta_1
          * ( (eta A * z_A_beta_1)
            + (eta B * z_B_beta_1)
            + (eta C * z_C_beta_1) )
        - (sigma_2 * z_hat_beta_1)
        = (h_1_beta_1 * v_H_beta_1) + (beta_1 * g_1_beta_1)
          + (sigma_1 / int h) ] 
  (*
    *)

  let ahp_to_pcs_ip = Basic_IP.map ~f:PCS_IP.ahp_compiler

  module S = SNARK (PCS_IP.Computation)

  let p = protocol (failwith "TODO") []

  let p = ahp_to_pcs_ip p

  (* Everything after this essentially only concerns the verifier *)
  let p_for_prover =
    let open Basic_IP in
    let module IP1 = Ip.T (Basic_IP.Interaction) (PCS_IP.Computation) in
    let module Expand_outer_computation =
      Ip.Computation.Bind (Interaction) (Computation) (PCS_IP.Computation)
        (struct
          let f (Computation.Nop k) = IP1.Pure k
        end)
    in
    let module Expand_inner_interaction =
      Ip.Interaction.Map (PCS_IP.Computation) (PCS_IP.Interaction)
        (Basic_IP.Interaction)
        (struct
          let f (PCS_IP.Interaction.Receive (pcs, k)) =
            Basic_IP.Interaction.Send_and_receive (Hlist [], [], PCS pcs, k)
        end)
    in
    IP1.bind (Expand_outer_computation.f p) ~f:Expand_inner_interaction.f

  let p = S.fiat_shamir [] p_for_prover

  let _ = p

  let _ = p

  let ocaml_prover =
    let assert_equal x y = failwith "" in
    let op o = failwith "" in
    let int _ = failwith "" in
    let constant _ = failwith "" in
    let scale_commitment _ _ = failwith "" in
    let add_commitment _ _ = failwith "" in
    let add_field _ _ = failwith "" in
    let mul_field _ _ = failwith "" in
    let open_commitment _ _ _ = failwith "" in
    let compute : S.compute =
      { f=
          (fun ~append_lines c ->
            match c with
            | Arithmetic c ->
                Arithmetic_computation.F.to_program c ~assert_equal ~constant
                  ~int ~op
            | Scale_poly (x, p, k) ->
                let xp = S.Poly.scale ~append_lines ~scale_commitment x p in
                ([], k xp)
            | Add_poly (p1, p2, k) ->
                let p = S.Poly.add ~append_lines ~add_commitment p1 p2 in
                ([], k p)
            | Check_proof (_p, _x, _y, _pi, k) ->
                ([], k) ) }
    in
    let prove : S.Compiler(S.Proof_component).t =
      let f : type a.
             append_lines:(Program.t -> unit)
          -> (a, S.env) S.Proof_component.t
          -> Program.t * a =
       fun ~append_lines c ->
        match c with
        | PCS (Proof (p, x, y)) ->
            open_commitment p x y
        | PCS (Evals (ps, pt)) ->
            let eval_poly (p : S.Poly.basic) x =
              let r = gen_name () in
              append_lines
                [Statement.Assign 
                   (r, Method_call
                      (p, "evaluate", [x]))] ;
              Expr.Var r
            in
            ( []
            , Vector.map ps ~f:(fun p ->
                  S.Poly.eval ~eval_poly ~add_field ~mul_field p pt ) )
      in
      {f}
    in
    S.prover ~compute ~prove

  (*   let p = S.fiat_shamir [(* Input goes here *)] p *)
end

type domain = I | L | H | K

module Oracle = struct
  type t = F_input | F_A
end
