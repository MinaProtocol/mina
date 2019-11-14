open Core_kernel
open Fractal

module Randomness = struct
  type (_, _) t =
    | Field
      : ('field, < field : 'field; ..>) t
end

module Computation = struct
  type (_, _) t =
    | Check_equal
      : 'field Arithmetic_expression.t * 'field Arithmetic_expression.t
        * 'k
        -> ('k, < field: 'field; ..>) t

  let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
    fun t ~f ->
      match t with
      | Check_equal (x, y, k) -> Check_equal (x, y, f k)
end

module Prover_message = struct
  type (_, _) t =
    | Square_root : 'field Arithmetic_expression.t -> ('field, < field: 'field; ..>) t

  let type_ : type a e. (a, e) t -> (a, e) Type.t =
    function
    | Square_root _ -> Field
end

module SNARK =
  Fiat_shamir.Make(Randomness)(Prover_message)(Computation)

module Compilers = struct
  open Fiat_shamir

  let gen = unstage (Name.gen () )

  let bind_value' (eq : (field, 'a) Type_equal.t) e : Program.t * 'a =
    let res = gen () in
    ( [ Statement.Assign (res, e) ]
      , Type_equal.conv eq (Expr.Var res ) )

  let bind_value (eq : (field, 'a) Type_equal.t) fn_name args : Program.t * 'a =
    bind_value'
      eq
      (Fun_call (fn_name, args))

  let compute
    ~check_equal
    ~arithmetic_expression
    : env Compiler(Computation).t =
    { f = fun ~append_lines:_ c ->
          match c with
          | Check_equal (x, y, k) ->
            ( [ Proc_call
                  (check_equal,
                  [arithmetic_expression x; arithmetic_expression y] )
              ]
            , k )
    }

  module Cpp = struct
    let preamble =
      {cpp|#include <vector>
  template<typename FieldT>
  struct proof {
    std::vector<FieldT> field_elements;
    std::vector<FieldT> polynomials; // TODO
    std::vector<FieldT> pcs_proofs; // TODO
  };
  |cpp}

    let fundef ret_type n name body =
      let indent s =
        List.map (String.split_lines s) ~f:(sprintf "  %s")
        |> String.concat ~sep:"\n"
      in
      let v = Vector.init n ~f:(fun _ -> gen ()) in
      sprintf "%s %s(%s) {\n%s\n};"
        ret_type
        name
        (String.concat ~sep:" " (List.map (Vector.to_list v) ~f:(sprintf "FieldT %s")))
        (indent (body (Vector.map v ~f:(fun s -> Expr.Var s))))
      

    let templated = sprintf "%s<FieldT>"

    let arithmetic_expression =
      Arithmetic_expression.to_expr
        ~constant:Fn.id
        ~int:(fun n -> Fun_call ("FieldT", [ Int n ]))
        ~negate:(fun e ->
            Fun_call (templated "negate", [ e ]))
        ~op:(fun t ->
            let s =
              match t with
              | `Add -> "add"
              | `Mul -> "mul"
              | `Div -> "div"
              | `Sub -> "sub"
            in
            templated s
          )
        ~pow:(fun e n -> Fun_call (templated "pow", [ e; Int n]))

    open Fiat_shamir

    let compute =
      compute
        ~check_equal:(templated "check_equal")
        ~arithmetic_expression

    let prove : env Compiler(Prover_message).t =
      let f : type a. (a, env) Compiler(Prover_message).f =
          fun  ~append_lines:_ (t : (a, env) Prover_message.t) ->
            match t with
            | Square_root expr ->
              bind_value T
                "FieldT::sqrt"
                [ arithmetic_expression expr ]
      in
      { f
      }

    let initialize () = 
      bind_value T "create_hash_state<FieldT>" []

    let squeeze hash_state : env Compiler(Randomness).t =
      let f : type a. (a, env) Compiler(Randomness).f =
        fun ~append_lines:_ (r : (a, env) Randomness.t) ->
          match r with
          | Field ->
            bind_value T
              "squeeze_hash_state<FieldT>"
              [ hash_state ]
      in
      { f
      }

    let absorb hash_state (input : env SNARK.Hash_input.t) =
      match input with
      | Field x ->
        [ Statement.Proc_call
            ( "absorb<FieldT>"
            , [ hash_state; x ])
        ]
      | _ -> failwith "Unimplemented"
  end

  module Rust = struct
    let preamble = {rust|
pub trait ModelParameters: Send + Sync + 'static {
    type BaseField: Field + SquareRootField;
    type ScalarField: PrimeField + SquareRootField + Into<<Self::ScalarField as PrimeField>::BigInt>;
    type PolynomialCommitment
    type PCSProof
}

struct Proof<P : ModelParameters> {
    pub field_elements P::BaseField,
    pub polynomials P::PolynomialCommitment,
    pub pcs_proofs P::PCSProof,
}
|rust}

    let fundef n name body =
      let indent s =
        List.map (String.split_lines s) ~f:(sprintf "  %s")
        |> String.concat ~sep:"\n"
      in
      let v = Vector.init n ~f:(fun _ -> gen ()) in
      sprintf "fn %s(%s) {\n%s\n}"
        name
        (String.concat ~sep:" " (List.map (Vector.to_list v) ~f:(sprintf "P::ScalarField %s")))
        (indent (body (Vector.map v ~f:(fun s -> Expr.Var s))))
      

    let arithmetic_expression =
      Arithmetic_expression.to_expr'
        ~constant:Fn.id
        ~int:(fun n -> Expr.Var (sprintf "P::ScalarField(%d)" n))
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

    let compute =
      compute
        ~check_equal:"assert_eq!"
        ~arithmetic_expression

    let prove : env Compiler(Prover_message).t =
      let f : type a. (a, env) Compiler(Prover_message).f =
          fun  ~append_lines:_ (t : (a, env) Prover_message.t) ->
            match t with
            | Square_root expr ->
              bind_value' T
                (Method_call
                   ( Method_call (arithmetic_expression expr, "sqrt", []),
                     "unwrap", []))
      in
      { f
      }

    let initialize () = 
      bind_value' T
        (Raw "Hash::new()")

    let squeeze hash_state : env Compiler(Randomness).t =
      let f : type a. (a, env) Compiler(Randomness).f =
        fun ~append_lines:_ (r : (a, env) Randomness.t) ->
          match r with
          | Field ->
            bind_value' T
              (Method_call (hash_state, "squeeze", []))
      in
      { f
      }

    let absorb hash_state (input : env SNARK.Hash_input.t) =
      match input with
      | Field x ->
        [ Statement.Method_call
            ( hash_state
            , "absorb"
            , [ x ])
        ]
      | _ -> failwith "Unimplemented"

  end
end

include Ip.T(Randomness)(Messaging.F(Prover_message))(Computation)

let protocol ([x] : _ Vector.t) =
  let open Arithmetic_expression in
  let%bind a = sample Field in
  let%bind r =
    interact
      (Send_and_receive
          (Field
          , a
          , Square_root (!a * !x)
          , return))
  in
  compute (
    Check_equal
      (!r * !r, !a * !x, return ()))

let snark input =
  SNARK.fiat_shamir
    [ SNARK.absorb_value
        (Vector (Field, Vector.length input))
        input
    ] 
    (protocol input)

let program =
  let open Compilers.Rust in
  preamble ^
  fundef (* "template<typename FieldT>\nproof<FieldT>" *) (S Z) "prove"
    (fun input ->
      SNARK.prover ~compute:compute ~prove:prove
        ~initialize:initialize
        ~squeeze:squeeze
        ~absorb:absorb
        (snark input )
      |> Program.to_rust)

let () = print_endline program
