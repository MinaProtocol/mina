(* Test that Scalars_tokens_interpreter produces identical results to the
   tree-walking Scalars module for both Tick and Tock, with random inputs. *)

module type Field_ops = sig
  type t

  val random : unit -> t

  val add : t -> t -> t

  val sub : t -> t -> t

  val mul : t -> t -> t

  val square : t -> t

  val of_int : int -> t

  val of_bigint : Kimchi_pasta.Pasta.Bigint256.t -> t

  val equal : t -> t -> bool

  val to_string : t -> string
end

let field_of_hex (type f) (module F : Field_ops with type t = f) s =
  Kimchi_pasta.Pasta.Bigint256.of_hex_string s |> F.of_bigint

type feature_config =
  | All_disabled
  | All_enabled
  | Only_enabled of Kimchi_types.feature_flag list

let feature_flag_name : Kimchi_types.feature_flag -> string = function
  | RangeCheck0 -> "RangeCheck0"
  | RangeCheck1 -> "RangeCheck1"
  | ForeignFieldAdd -> "ForeignFieldAdd"
  | ForeignFieldMul -> "ForeignFieldMul"
  | Xor -> "Xor"
  | Rot -> "Rot"
  | LookupTables -> "LookupTables"
  | RuntimeLookupTables -> "RuntimeLookupTables"
  | LookupPattern _ -> "LookupPattern"
  | TableWidth n -> Printf.sprintf "TableWidth(%d)" n
  | LookupsPerRow n -> Printf.sprintf "LookupsPerRow(%d)" n

let feature_config_name = function
  | All_disabled -> "all disabled"
  | All_enabled -> "all enabled"
  | Only_enabled flags ->
      Printf.sprintf "only [%s]"
        (List.map flags ~f:feature_flag_name |> String.concat ~sep:", ")

let is_feature_enabled config flag =
  match config with
  | All_disabled -> false
  | All_enabled -> true
  | Only_enabled flags ->
      List.exists flags ~f:(fun f ->
          String.equal (feature_flag_name f) (feature_flag_name flag))

let make_env
    (type f)
    (module F : Field_ops with type t = f)
    ~(feature_config : feature_config) : f Plonk_checks.Scalars.Env.t =
  let pow (x, n) =
    let rec go acc = function 0 -> acc | i -> go (F.mul acc x) (i - 1) in
    go (F.of_int 1) n
  in
  let var_tbl = Hashtbl.Poly.create () in
  let mds_tbl = Hashtbl.Poly.create () in
  let lagrange_tbl = Hashtbl.Poly.create () in
  let alpha = F.random () in
  let max_alpha = 40 in
  let alpha_pows = Array.init (max_alpha + 1) ~f:(fun i -> pow (alpha, i)) in
  { add = F.add
  ; sub = F.sub
  ; mul = F.mul
  ; pow
  ; square = F.square
  ; zk_polynomial = F.random ()
  ; omega_to_minus_zk_rows = F.random ()
  ; zeta_to_n_minus_1 = F.random ()
  ; zeta_to_srs_length = lazy (F.random ())
  ; var =
      (fun key ->
        Hashtbl.find_or_add var_tbl key ~default:(fun () -> F.random ()))
  ; field = field_of_hex (module F)
  ; cell = Fn.id
  ; alpha_pow =
      (fun i -> if i <= max_alpha then alpha_pows.(i) else pow (alpha, i))
  ; double = (fun x -> F.add x x)
  ; endo_coefficient = F.random ()
  ; mds =
      (fun key ->
        Hashtbl.find_or_add mds_tbl key ~default:(fun () -> F.random ()))
  ; srs_length_log2 = 16
  ; vanishes_on_zero_knowledge_and_previous_rows = F.random ()
  ; joint_combiner = F.random ()
  ; beta = F.random ()
  ; gamma = F.random ()
  ; unnormalized_lagrange_basis =
      (fun key ->
        Hashtbl.find_or_add lagrange_tbl key ~default:(fun () -> F.random ()))
  ; if_feature =
      (fun (flag, if_true, if_false) ->
        if is_feature_enabled feature_config flag then if_true ()
        else if_false ())
  }

let test_equivalence
    (type f)
    (module F : Field_ops with type t = f)
    ~name
    ~(original : f Plonk_checks.Scalars.Env.t -> f)
    ~(interpreter : f Plonk_checks.Scalars.Env.t -> f)
    ~feature_config =
  let env = make_env (module F) ~feature_config in
  let result_original = original env in
  let result_interpreter = interpreter env in
  if F.equal result_original result_interpreter then (
    Printf.printf "  PASS: %s (%s)\n%!" name (feature_config_name feature_config) ;
    true)
  else (
    Printf.printf "  FAIL: %s (%s)\n%!" name (feature_config_name feature_config) ;
    Printf.printf "    original:    %s\n%!" (F.to_string result_original) ;
    Printf.printf "    interpreter: %s\n%!" (F.to_string result_interpreter) ;
    false)

(* All feature flags that appear in the Tick linearization *)
let tick_flags : Kimchi_types.feature_flag list =
  [ RangeCheck0
  ; RangeCheck1
  ; ForeignFieldAdd
  ; ForeignFieldMul
  ; Xor
  ; Rot
  ; LookupTables
  ]

let () =
  Printf.printf
    "Equivalence test: Scalars vs Scalars_tokens_interpreter\n\n%!" ;
  let all_pass = ref true in
  (* Test 1: Features disabled (10 rounds) *)
  Printf.printf "=== All features disabled ===\n%!" ;
  for round = 1 to 10 do
    Printf.printf "Round %d:\n%!" round ;
    if
      not
        (test_equivalence
           (module Kimchi_pasta.Pasta.Fp)
           ~name:"Tick" ~feature_config:All_disabled
           ~original:Plonk_checks.Scalars.Tick.constant_term
           ~interpreter:
             Plonk_checks.Scalars_tokens_interpreter.Tick.constant_term)
    then all_pass := false ;
    if
      not
        (test_equivalence
           (module Kimchi_pasta.Pasta.Fq)
           ~name:"Tock" ~feature_config:All_disabled
           ~original:Plonk_checks.Scalars.Tock.constant_term
           ~interpreter:
             Plonk_checks.Scalars_tokens_interpreter.Tock.constant_term)
    then all_pass := false
  done ;
  (* Test 2: Individual features enabled *)
  Printf.printf "\n=== Individual features ===\n%!" ;
  List.iter tick_flags ~f:(fun flag ->
      let config = Only_enabled [ flag ] in
      Printf.printf "Testing with %s:\n%!" (feature_config_name config) ;
      if
        not
          (test_equivalence
             (module Kimchi_pasta.Pasta.Fp)
             ~name:"Tick" ~feature_config:config
             ~original:Plonk_checks.Scalars.Tick.constant_term
             ~interpreter:
               Plonk_checks.Scalars_tokens_interpreter.Tick.constant_term)
      then all_pass := false) ;
  (* Test 3: All features enabled *)
  Printf.printf "\n=== All features enabled ===\n%!" ;
  for round = 1 to 10 do
    Printf.printf "Round %d:\n%!" round ;
    if
      not
        (test_equivalence
           (module Kimchi_pasta.Pasta.Fp)
           ~name:"Tick" ~feature_config:All_enabled
           ~original:Plonk_checks.Scalars.Tick.constant_term
           ~interpreter:
             Plonk_checks.Scalars_tokens_interpreter.Tick.constant_term)
    then all_pass := false ;
    if
      not
        (test_equivalence
           (module Kimchi_pasta.Pasta.Fq)
           ~name:"Tock" ~feature_config:All_enabled
           ~original:Plonk_checks.Scalars.Tock.constant_term
           ~interpreter:
             Plonk_checks.Scalars_tokens_interpreter.Tock.constant_term)
    then all_pass := false
  done ;
  if !all_pass then
    Printf.printf "\nAll equivalence tests passed!\n%!"
  else (
    Printf.printf "\nSome tests FAILED!\n%!" ;
    exit 1)
