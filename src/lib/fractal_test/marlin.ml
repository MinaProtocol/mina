open Core_kernel
open Fractal

type m = A | B | C

let abc a b c = function A -> a | B -> b | C -> c

let all_but x0 = List.filter ~f:(fun x -> x <> x0)
let reducei xs ( + ) f =
  match xs with
  | [] ->
      assert false
  | x :: xs ->
      List.foldi ~init:(f 0 x) ~f:(fun i acc x -> acc + f i x) xs

let reduce xs add f = reducei xs add (fun _ -> f)

let sum xs f = reduce xs Arithmetic_expression.( + ) f

let product xs f = reduce xs Arithmetic_expression.( * ) f

let sumi xs = reducei xs Arithmetic_expression.( + )

let b = 1

module Randomness = struct
  type (_, _) t =
    | ()
      : ('field, < field : 'field; ..>) t
end

module Query_program = struct
  module F = struct
    type ('a, 'env) t =
      | Query
        : ('poly, 'n) Vector.t
          * 'field
          * (('field, 'n) Vector.t -> 'k)
          -> ('k, < poly: 'poly; field: 'field; ..> ) t

    let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
      fun t ~f ->
        match t with
        | Query (vs, x, k) -> Query (vs, x, fun ys -> f (k ys))
  end

  include Free_monad.Make2(F)

  let query polys pt = Free (Query (polys, pt, return))

  let query' Hlist.HlistId.[h_3; g_3 ; row; col; value] beta_3 =
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
    Hlist.HlistId.[ h_3_beta_3
    ; g_3_beta_3
          ; abc row_A_beta_3 row_B_beta_3 row_C_beta_3
          ; abc col_A_beta_3 col_B_beta_3 col_C_beta_3
          ; abc value_A_beta_3 value_B_beta_3 value_C_beta_3
    ]
end

module Index = struct
  type 'poly t = {row: m -> 'poly; col: m -> 'poly; value: m -> 'poly}
end

module AHIOP = struct
  module Computation = Trivial_computation

  module Prover = struct
    module A = struct
      type ('a, 'e) t = 
        | Divide_by_vanishing_poly
          : 'poly * Domain.t
          -> ('poly * 'poly, < poly: 'poly; ..>) t
        | Add : 'poly * 'poly -> ('poly, < poly: 'poly; ..>) t
    end

    module F = struct
      type ('k, 'e) t =
        | Perform : ('a, 'e) t * ('a -> 'k) -> ('k, 'e) t

      let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
        fun t ~f ->
        match t with
        | Perform (eff, k) -> Perform (eff, fun x -> f (k x))
    end

    include Free_monad.Make2(F)
  end

  module Prover_message = struct
    type (_, _) t =
      | W_hat : { witness_size: int; b : int } -> ('poly, < poly: 'poly; ..>) t
      | Z_hat_ : { b : int; domain_h: Domain.t; m : m } -> ('poly, < poly: 'poly; ..>) t
      | Random_poly : { degree_less_than : int } -> ('poly, < poly: 'poly; ..>) t
      | H0 :
          { z_hat_ : m -> 'poly; domain_h : Domain.t }
          -> ('poly, < poly: 'poly; ..>) t
      | GH1
        : { b : int; domain_h : Domain.t }
          -> ('poly * 'poly, < poly: 'poly; ..>) t
      | Sigma_1
        : ('field, < field: 'field; ..>) t
      | Sigma_3
        : ('field, < field: 'field; ..>) t
      | Sigma_GH2
        : { domain_h : Domain.t; beta_1 : 'field; eta : m -> 'field; index : 'poly Index.t }
          -> ('field * 'poly * 'poly, < field: 'field; poly: 'poly; ..>) t
      | GH3
        : { domain_k : Domain.t }
          -> ('poly * 'poly, < poly: 'poly; ..>) t

    let type_ : type a e. (a, e) t -> (a, e) Type.t =
      fun t ->
      match t with
      | W_hat { witness_size; b } ->
        Polynomial (witness_size + b)
      | Z_hat_ { b; domain_h; m=_} -> 
        Polynomial (Domain.size domain_h + b)
      | Random_poly { degree_less_than } ->
        Polynomial degree_less_than
      | H0  { z_hat_=_ ; domain_h } -> 
        Polynomial (Domain.size domain_h + 2 * b - 1)
      | GH1 { b; domain_h } ->
          Pair 
            (Polynomial (Domain.size domain_h - 1)
               , Polynomial (Domain.size domain_h + b - 1))
      | Sigma_1 -> Field
      | Sigma_3 -> Field
      | Sigma_GH2 { domain_h ; beta_1=_; index=_ ; eta=_ } ->
        Triple (Field, Polynomial (Domain.size domain_h - 1)
                ,Polynomial (Domain.size domain_h - 1))
      | GH3 { domain_k } ->
        Pair
          (Polynomial (Domain.size domain_k - 1)
             , Polynomial (Domain.size domain_k * 6 - 6))
  end

  include Ip.T(Randomness)(Messaging.F(Prover_message))(Computation)

  let send t_q q t_r = interact (Send_and_receive (t_q, q, t_r, return))

  let interact ~send:q ~receive =
    let n = Vector.length q in
    send (Type.Vector (Field, n)) q receive

  let receive t =
    let%map x = send (Hlist []) [] t in
    x

  let abc f =
    let%map a = f A
    and b = f B
    and c = f C in
    abc a b c

  (* TODO: Make parameters *)
  let domain_h = Domain.Binary_roots_of_unity 20
  let domain_k = Domain.Binary_roots_of_unity 10
  let witness_size = 100 

  let s () = Prover_message.Random_poly
      { degree_less_than =
          2 * Domain.size domain_h + b - 1 }

  let z_hat_ m = Prover_message.Z_hat_ {b; m; domain_h }

  let r (type f) domain (alpha : f) =
    let open Arithmetic_expression in
    let open Arithmetic_circuit.E in
    let v_H = Domain.vanishing domain in
    let%map v_H_alpha = v_H !alpha in
    fun y ->
      let%map v_H_y = v_H y in
      (!v_H_alpha - !v_H_y) / (!alpha - y)

  let ( == ) x y = (x, y)

  let vanishing_poly (_domain : 'field Sequence.t) (prefix_length : int) =
    assert (prefix_length = 1) ;
    fun x ->
      let open Arithmetic_expression in
      x - int 1

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

  (* Section 5.3.2 *)
  let z_hat domain input w_hat =
    let open Arithmetic_expression in
    let input_length = List.length input in
    let x_hat = interpolate domain input in
    fun t -> (w_hat * vanishing_poly domain input_length t) + x_hat t

  let protocol (type field poly)
      ({ Index. row; col; value } as index : poly Index.t )
      input
    : ((( (field Arithmetic_expression.t * field Arithmetic_expression.t) list, < field: field; ..> ) Arithmetic_circuit.E.t
       , < field: field; poly: poly > ) Query_program.t,
       < field: field; poly: poly; ..>) t
    =
    let%bind (w_hat : poly) = receive (W_hat { witness_size; b }) in
    let%bind (s : poly) = receive (s ()) in
    let%bind (sigma_1 : field) = receive Sigma_1 in
    let%bind z_hat_ = abc (fun m -> receive (z_hat_ m)) in
    let%bind h_0 = receive (H0 { z_hat_; domain_h }) in
    let%bind alpha = sample () 
    and eta = abc (fun _ -> sample ()) in
    let%bind (g_1, h_1) =
      interact
        ~send:[ alpha; eta A; eta B; eta C ] 
        ~receive:(GH1 {b; domain_h })
    in
    let%bind (beta_1 : field) = sample () in
    let%bind (sigma_2, g_2, h_2) = interact ~send:[beta_1] ~receive:(Sigma_GH2 { domain_h; eta; index; beta_1 }) in
    let%bind (beta_2 : field) = sample () in
    let%bind (sigma_3 : field) =
      interact ~send:[ beta_2 ]
        ~receive:Sigma_3
    in
    let%bind (g_3, h_3) = receive (GH3 { domain_k }) in
    let%bind (beta_3 : field) = sample () in
    return begin
      let open Query_program in
      let open Arithmetic_expression in
      let eta x = !(eta x) in
      let%map [ h_3_beta_3; g_3_beta_3; row; col; value ] =
        query' [ h_3; g_3; row; col; value ] beta_3
      and [h_2_beta_2; g_2_beta_2] =
        query [h_2; g_2] beta_2
      and [ h_0_beta_1; h_1_beta_1; g_1_beta_1; z_A_beta_1; z_B_beta_1; z_C_beta_1; w_hat_beta1; s_beta_1 ] =
        query [h_0; h_1; g_1; z_hat_ A; z_hat_ B; z_hat_ C; w_hat; s] beta_1
      in
      let open Arithmetic_circuit.E in
      let%bind r_alpha =
        let%map f = (r domain_h alpha) in
        fun y -> f (! y)
      in
      let%bind (v_H_beta_2 : field) =
          (Domain.vanishing domain_h (! beta_2))
      and (v_H_beta_1 : field) =
          (Domain.vanishing domain_h (! beta_1))
      in
      let a_beta_3, b_beta_3 =
        let a =
          sum [A; B; C] (fun m ->
              eta m
              * !v_H_beta_2 * !v_H_beta_1
              * ! (value m)
              * product
                  (all_but m [A; B; C])
                  (fun n -> (!beta_2 - !(row n) )
                            * (!beta_1 * !(col n)) ))
        in
        let b =
          product [A; B; C] (fun m ->
              (!beta_2 - !(row m)) * (!beta_1 - ! (col m)))
        in
        (a, b)
      in
      let h_size = Domain.size domain_h in
      let%bind r_alpha_beta_2 = r_alpha beta_2 in
      let%bind r_alpha_beta_1 = r_alpha beta_1 in
      let z_hat_beta_1 =
        z_hat Sequence.empty (* TODO *)
          (Vector.to_list input )
          (!w_hat_beta1)
          (!beta_1)
      in
      let%bind v_K_beta_3 =
        Domain.vanishing domain_k (!beta_3)
      in
      return
        (* TODO: Maybe multiply through by h_size to avoid division. *)
        [ !h_3_beta_3 * !v_K_beta_3
          ==
          a_beta_3
          - b_beta_3
          * ( !beta_3 * !g_3_beta_3 + !sigma_3 / int (Domain.size domain_k)
            )
        ; r_alpha_beta_2 * !sigma_3
          ==
          (!h_2_beta_2 * !v_H_beta_2 + !beta_2 * !g_2_beta_2)
          + !sigma_2 / int h_size
        ; 
          (!s_beta_1
           + r_alpha_beta_1 *
             (eta A * !z_A_beta_1
              + eta B * !z_B_beta_1
              + eta C * !z_C_beta_1)
          - !sigma_2 * z_hat_beta_1 )
          ==
          (!h_1_beta_1 * !v_H_beta_1
          + !beta_1 * !g_1_beta_1 )
          + !sigma_1 / int h_size
        ; ! z_A_beta_1 * ! z_B_beta_1 - ! z_C_beta_1
          == !h_0_beta_1 * !v_H_beta_1
        ]
    end
end

module Linear_combination = struct
  type ('v, 'field) t =
    | Base of 'v
    | Add of 'v * ('v, 'field) t
    | Scale of 'field * ('v, 'field) t

  let scaling xi =
    let rec go acc = function
      | [] -> acc
      | p :: ps ->
        let acc =
          Add (p, Scale (xi, acc))
        in
        go acc ps
    in
    function [] -> assert false 
    | p :: ps -> go (Base p) ps

  let rec to_arithmetic_expression t =
    let open Arithmetic_expression in
    match t with
    | Base v -> ! v
    | Add (v, t) -> !v + to_arithmetic_expression t
    | Scale (x, t) ->
      !x * to_arithmetic_expression t

  let to_expr ~conv ~scale ~add =
    let rec go = function
      | Base v -> conv v
      | Add (v, t) -> add (conv v) (go t)
      | Scale (x, t) -> scale x (go t)
    in
    go
end

module PCS_proof = struct
  module Randomness = Randomness

  module Prover_message = struct
    type ('a, 'e) t =
      | Evals :
          ('poly, 'n) Vector.t * 'field
          -> ( ('field, 'n) Vector.t
              , < poly: 'poly ; field: 'field ; .. > )
              t
      | Proof :
          'poly
          * 'field
          * 'field
          -> ('pi, < poly: 'poly ; field: 'field ; proof: 'pi ; .. >) t
  end

  include Ip.T(Randomness)(Messaging.F(Prover_message))(Trivial_computation)

  type ('field, 'poly) deferred_proof_check =
        [ `Check_single_proof
        of ('poly, 'field) Linear_combination.t
          * 'field
          * 'field Arithmetic_expression.t
        ]

  let receive msg =
    interact (Send_and_receive (Hlist [], [], msg, return))

  let eval ps x =
    receive ( Evals (ps, x) )

  (* Separate out the checks just in case we need it for recursion *)
  let rec compile
    : type a poly field proof.
      (field, poly) deferred_proof_check list
      -> (a, < poly:poly; field: field >) Query_program.t
      -> 
      (a * (field, poly) deferred_proof_check list
      , < poly:poly; field:field; proof:proof >) t
      (*
      (a * ('field, 'poly, 'proof) deferred_proof_check list
         , < poly:poly; field:field; proof:proof; .. >) t
         *)
    =
    fun acc p ->
    match p with
    | Pure x -> Pure (x, acc)
    | Free (Query (ps, x, k)) ->
      let%bind (xi : field) = sample () in
      let%bind ys = eval ps x in
      let next = k ys in
      let acc = `Check_single_proof
            ( Linear_combination.scaling xi (Vector.to_list ps),
              x,
              Linear_combination.(
                to_arithmetic_expression
                  (scaling xi (Vector.to_list ys) ))
            )
          :: acc
      in
      compile
        acc
        next
end

module Rust_compilation_target = struct
  module Prover_message = struct
    type ('a, 'e) t =
      | PCS_proof of ('a, 'e) PCS_proof.Prover_message.t
      | AHIOP of ('a, 'e) AHIOP.Prover_message.t

    let type_ : type a e. (a, e) t -> (a, e) Type.t =
      fun t ->
      match t with
      | PCS_proof (Evals (polys, _x)) ->
        Vector (Field, Vector.length polys)
      | PCS_proof (Proof (_poly, _x, _y)) ->
        Proof
      | AHIOP m -> AHIOP.Prover_message.type_ m

    let is_unique : type a e. (a, e) t -> bool =
      function
      | PCS_proof Evals (_ps, _x) -> true
      | PCS_proof Proof _ -> true
      | AHIOP _ -> false
  end

  module Computation = struct
    type ('a, 'e) t =
      | Arithmetic of ('a, 'e) Arithmetic_circuit.E.F.t
      | Eval_linear_combination
        : ('poly, 'field) Linear_combination.t
          * ('poly -> 'k)
          -> ('k, < field: 'field; poly: 'poly; ..>) t
      | Check_PCS_proof
        : 'poly * 'field * 'field * 'proof * 'k
          ->  ('k, < poly: 'poly; field: 'field; proof: 'proof; .. >) t
      | Assert_equal
        : 'field Arithmetic_expression.t
        * 'field Arithmetic_expression.t
        * 'k
          ->  ('k, < field: 'field; .. >) t


    let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e)t =
      fun t ~f ->
      match t with
      | Arithmetic c -> Arithmetic (Arithmetic_circuit.E.F.map c ~f)
      | Eval_linear_combination (lc, k) ->
        Eval_linear_combination (lc, fun x -> f ( k x))
      | Check_PCS_proof (p, x, y, pi, k) ->
        Check_PCS_proof (p, x, y, pi, f k)
      | Assert_equal (x, y, k) ->
        Assert_equal (x, y, f k)
  end

  module Snark = Fiat_shamir.Make(Randomness)(Prover_message)(Computation)

  module Compiler = struct

  let gen = unstage (Name.gen () )

  module Prover_params = struct
    type t =
      { committer_key : Expr.t
      ; sponge_params : Expr.t
      }
  end

  let fundef n name body =
    let indent s =
      List.map (String.split_lines s) ~f:(sprintf "  %s")
      |> String.concat ~sep:"\n"
    in
    let committer_key = gen ~name:"commiter_key" () in
    let sponge_params = gen ~name:"sponge_params" () in
    let v = Vector.init n ~f:(fun _ -> gen ()) in
    let (%:) = sprintf "%s : %s" in
    let traits = [
      "F", "Field";
      "SinglePC", "SinglePolynomialCommitment<F>";
      "Sponge", "sponge::Sponge<Message<F, SinglePC::Commitment>, F>"
    ]
    in
    sprintf "fn %s<%s>(%s) {\n%s\n}"
      name
      (String.concat ~sep:", " (List.map ~f:(Tuple2.uncurry (%:)) traits))
      (String.concat ~sep:", "
         ( [ committer_key %: "&SinglePC::CommitterKey"
           ; sponge_params %: "&Sponge::Params" ]
         @  List.map (Vector.to_list v) ~f:(sprintf "%s : F"))
      )
      (indent 
         (body { Prover_params.committer_key=Var committer_key; sponge_params= Var sponge_params }
            (Vector.map v ~f:(fun s -> Expr.Var s))))

    open Fiat_shamir

    let arithmetic_expression =
      Arithmetic_expression.to_expr'
        ~constant:Fn.id
        ~int:(fun n -> Expr.Var (sprintf "F(%d)" n))
        ~negate:(fun x -> Expr.Method_call (x, "neg", []))
        ~op:(fun op x y ->
            let meth =
              match op with
              | `Add -> "add"
              | `Mul -> "mul"
              | `Div -> "div"
              | `Sub -> "sub"
            in
            Method_call (x, meth, [ Prefix_op ("&", y) ]) )
        ~pow:(fun x n -> 
            Method_call (x, "pow", [ Int n ]))

    let bind_value' ?name (eq : (field, 'a) Type_equal.t) e : Program.t * 'a =
      let res = gen ?name () in
      ( [ Statement.Assign (res, e) ]
        , Type_equal.conv eq (Expr.Var res ) )

    let scale_commitment (x : field) (e : Expr.t) =
      Expr.Method_call (e, "scale", [ x ])

    let add_commitment (c1 : Expr.t) (c2 : Expr.t) =
      Expr.Method_call (c1, "add", [ c2 ])

    let add_poly p1 p2 =
      Expr.Method_call (p1, "add", [p2])

    let scale_poly x p =
      Expr.Method_call (p, "scale", [x])

    let compute
      : env Compiler(Computation).t =
      let f : type a. (a, env) Compiler(Computation).f =
          fun  ~append_lines (c : (a, env) Computation.t) ->
            match c with
            | Assert_equal (_, _, k)
            | Check_PCS_proof (_, _, _, _, k) ->
              (* No need to check as the prover. *)
              ( [], k)
            | Eval_linear_combination (lc, k) ->
              let e =
                Linear_combination.to_expr lc
                  ~conv:Fn.id
                  ~scale:(
                    Poly.scale
                      ~append_lines
                      ~scale_commitment
                      ~scale_poly
                  )
                  ~add:(Poly.add ~add_poly ~append_lines ~add_commitment)
              in
              ( [] , k e )
            | Arithmetic (Eval (x, k)) ->
              let prog, res =
                bind_value' T 
                  (arithmetic_expression x)
              in
              (prog, k res)
      in
      { f
      }

    let eval_poly p x =
      Expr.Method_call (p, "eval", [x])
    let add_field x y = arithmetic_expression Arithmetic_expression.(!x + !y)
    let mul_field x y = arithmetic_expression Arithmetic_expression.(!x * !y)

    let create_poly { Prover_params.committer_key; _ } ~append_lines e =
      let borrow e = Expr.Prefix_op ("&", e) in
      { Poly.expr = e
      ; commitment =
          lazy (
            let name = gen () in
            append_lines
              [ Statement.Assign
                  (name, Fun_call ("commit::<F, SinglePC>", [committer_key; borrow e]))
              ];
            Var name
          )
      ; evaluations = Expr.Table.create ()
      }

(* TODO: Needs access to some auxiliary information passed in
   (e.g., the variable for the witness) *)
    let prove params : env Compiler(Prover_message).t =
      let f : type a. (a, env) Compiler(Prover_message).f =
        fun  ~append_lines (m : (a, env) Prover_message.t) ->
          let create_poly = create_poly params ~append_lines in
          match m with
          | PCS_proof (Proof (p, x, y)) ->
            bind_value' ~name:"pi" T
              (Method_call (p.Poly.expr, "evalution_proof", [x; y]))
          | PCS_proof (Evals (polys, x)) ->
            let ys =
              Vector.map polys ~f:(fun p ->
                  eval_poly
                    p.expr
                    x)
            in
            ( [] , ys )
          | AHIOP m ->
            begin match m with
            | W_hat { witness_size=_; b=_ } ->
                let lines, e =
                  bind_value' T
                    (Fun_call ("w_hat", []))
                in
                (lines, create_poly e)
              | Sigma_1 -> 
                  bind_value' T
                    (Fun_call ("sigma1", []))
              | Sigma_3 ->
                  bind_value' T
                    (Fun_call ("sigma1", []))
              | H0  { z_hat_=_ ; domain_h=_ } -> 
                ( [], create_poly (Var "junk_h0"))
              | GH1 _ -> 
                ( [],
                  ( create_poly (Var "junk_g1")
                  ,create_poly (Var "junk_h1")
                  ) )
              | Sigma_GH2 _ -> 
                ( [],
                  ( Var "sigma_2_junk"
                  , create_poly (Var "junk_g2")
                  ,create_poly (Var "junk_h2")
                  ) )
              | GH3 _ -> 
                ( [],
                  ( create_poly (Var "junk_g3")
                  ,create_poly (Var "junk_h3")
                  ) )
              | Z_hat_  _ ->
                ( [], create_poly (Var "junk_z_hat"))
              | Random_poly  _ ->
                ( [], create_poly (Var "junk_random_poly"))
            end
      in
      { f
      }

    let initialize () = 
      bind_value' ~name:"sponge" T
        (Raw "Sponge::new()")

    let squeeze { Prover_params.sponge_params; _ } hash_state : env Compiler(Randomness).t =
      let f : type a. (a, env) Compiler(Randomness).f =
        fun ~append_lines:_ (r : (a, env) Randomness.t) ->
          match r with
          | () ->
            bind_value' ~name:"challenge" T
              (Method_call (hash_state, "squeeze", [ sponge_params ]))
      in
      { f
      }

    let absorb { Prover_params.sponge_params; _ } hash_state (input : env Snark.Hash_input.t) =
      let absorb tag value =
        [ Statement.Method_call
            ( hash_state
            , "absorb"
            , [ sponge_params
              ; Prefix_op
                  ("&", 
                   Fun_call(
                     (sprintf "Message::%s" tag),
                     [ Method_call (value, "clone", [])]
                   ))  ])
        ]
      in
      match input with
      | Field x -> absorb "Field" x
      | Polynomial p -> absorb "Commitment" (Lazy.force p.commitment)
      |  PCS_proof _ -> []

  end

  include Ip.T(Randomness)(Messaging.F(Prover_message))(Computation)

  let receive msg =
    interact (Send_and_receive (Hlist [], [], msg, return))

  let eval ae = compute (Arithmetic (Eval (ae, return)))
  let eval_lc lc = compute (Eval_linear_combination (lc, return))

  let compile_query_program
    : type a field poly proof.
      (a, < field:field; poly:poly >) Query_program.t
      -> (a, < field:field; poly:poly; proof:proof > ) t 
    =
    fun protocol ->
      let protocol = PCS_proof.compile [] protocol in
      let module C =
        Ip.Computation.Bind
          (Randomness)
          (Messaging.F(PCS_proof.Prover_message))
          (Trivial_computation)
          (Computation)
          (struct
            let f (Trivial_computation.Nop k) 
              : _ Ip.T(Randomness)
                  (Messaging.F(PCS_proof.Prover_message))
                  (Computation).t
              = Pure k
          end)
      in
      let module I =
        Ip.Interaction.Map
          (Randomness)
          (Computation)
          (Messaging.F(PCS_proof.Prover_message))
          (Messaging.F(Prover_message))
          (struct
            let f (Send_and_receive (t, q, m, k)
                : _ Messaging.F(PCS_proof.Prover_message).t )
                : _ Messaging.F(Prover_message).t
              =
              Send_and_receive (t, q, PCS_proof m, k)
          end)
      in
      let protocol = I.f (C.f protocol) in
      let%bind x, checks = protocol in
      let%bind () =
        all_unit (List.map checks ~f:(
            fun (`Check_single_proof (poly, x, y)) ->
              let%bind y = eval y in
              let%bind poly = eval_lc poly in
              let%bind proof =
                receive (PCS_proof (Proof (poly, x, y)))
              in
              compute (Check_PCS_proof (poly, x, y, proof, return ())) ))
      in
      return x

  let protocol index input =
    let protocol =
      let module C =
        Ip.Computation.Bind
          (Randomness)
          (Messaging.F(AHIOP.Prover_message))
          (Trivial_computation)
          (Computation)
          (struct
            let f (Trivial_computation.Nop k) 
              : _ Ip.T(Randomness)
                  (Messaging.F(AHIOP.Prover_message))
                  (Computation).t
              = Pure k
          end)
      in
      C.f
        (AHIOP.protocol index input)
    in
    let protocol =
      let module I =
        Ip.Interaction.Map
          (Randomness)
          (Computation)
          (Messaging.F(AHIOP.Prover_message))
          (Messaging.F(Prover_message))
          (struct
            let f (Send_and_receive (t, q, m, k)
                : _ Messaging.F(AHIOP.Prover_message).t )
                : _ Messaging.F(Prover_message).t
              =
              Send_and_receive (t, q, AHIOP m, k)
          end)
      in
      I.f protocol
    in
    let%bind qp = protocol in
    let module A = Free_monad.Bind2(Arithmetic_circuit.E.F)
        (Ip.F(Randomness)(Messaging.F(Prover_message))(Computation))
        (struct
          let f (type a e) (t : (a, e) Arithmetic_circuit.E.F.t) : (a, e) t =
            match  t with
            | Eval (x, k) ->
              let%map x = eval x in
              k x
        end)
    in
    let%bind arithmetic_checks = compile_query_program qp in
    let%bind arithmetic_checks = A.f arithmetic_checks in
    all_unit
      (List.map arithmetic_checks ~f:(fun (x, y) ->
           compute (Assert_equal (x, y, return ()))))

  let snark index input =
    Snark.fiat_shamir
      [ Snark.absorb_value
          (Vector (Field, Vector.length input))
          input
      ] 
      (protocol index input)

  let f =
    Compiler.fundef (S Z)
      "prover"
      (fun prover_params input ->
    let index =
      let junk name = Compiler.create_poly
                        prover_params
          ~append_lines:(fun _ -> ())
          (Var name )
      in
      { Index.row
        = abc 
            (junk "row_a")
            (junk "row_b")
            (junk "row_c")
      ; col
        = abc 
            (junk "col_a")
            (junk "col_b")
            (junk "col_c")
      ; value
        = abc 
            (junk "value_a")
            (junk "value_b")
            (junk "value_c")
      }
    in
      Snark.prover
        (snark index input)
        ~compute:Compiler.compute
        ~prove:(Compiler.prove prover_params)
        ~squeeze:(Compiler.squeeze prover_params)
        ~absorb:(Compiler.absorb prover_params)
        ~initialize:Compiler.initialize
      |> Program.to_rust 
      )
    |> print_endline
end
