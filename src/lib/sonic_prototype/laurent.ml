open Core

exception Poly_division_error of string

module type Ring = sig
  type nat

  type t [@@deriving eq]

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( ** ) : t -> nat -> t

  val negate : t -> t

  val zero : t

  val one : t

  val to_string : t -> string
end

module type Field = sig
  include Ring

  val ( - ) : t -> t -> t

  val ( / ) : t -> t -> t
end

module type Laurent = sig
  type field

  type nat

  type t = int * field list

  val create : int -> field list -> t

  val deg : t -> int

  val coeffs : t -> field list

  val eval : t -> field -> field

  val equal : t -> t -> bool

  val negate : t -> t

  val zero : t

  val one : t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( ** ) : t -> nat -> t

  val ( / ) : t -> t -> t

  val to_string : t -> string
end

module Make_laurent (N : sig
  type t

  val of_int : int -> t

  val to_int_exn : t -> int
end)
(F : Field with type nat := N.t) :
  Laurent with type field := F.t and type nat := N.t = struct
  type t = int * F.t list

  let create starting_degree coefficients = (starting_degree, coefficients)

  let deg poly =
    let starting_degree, _ = poly in
    starting_degree

  let coeffs poly =
    let _, coefficients = poly in
    coefficients

  let eval poly pt =
    let starting_degree, coefficients = poly in
    let rec loop remaining_coeffs pt current_power =
      match remaining_coeffs with
      | [] ->
          F.zero
      | hd :: tl ->
          F.( + ) (F.( * ) hd current_power)
            (loop tl pt (F.( * ) pt current_power))
    in
    let starting_pt =
      if starting_degree < 0 then
        F.( / ) F.one (F.( ** ) pt (N.of_int (-starting_degree)))
      else F.( ** ) pt (N.of_int starting_degree)
    in
    loop coefficients pt starting_pt

  let trim poly =
    let starting_degree, coefficients = poly in
    let rec all_zeros lst =
      match lst with
      | [] ->
          true
      | hd :: tl ->
          F.equal F.zero hd && all_zeros tl
    in
    let rec remove_zeros_from_end lst =
      match lst with
      | [] ->
          []
      | hd :: tl ->
          if all_zeros lst then [] else hd :: remove_zeros_from_end tl
    in
    let rec trim_beginning starting_degree coeffs =
      match coeffs with
      | [] ->
          create starting_degree coeffs
      | hd :: tl ->
          if F.equal F.zero hd then trim_beginning (starting_degree + 1) tl
          else create starting_degree coeffs
    in
    let trimmed_coeffs = remove_zeros_from_end coefficients in
    if trimmed_coeffs = [] then create 0 []
    else trim_beginning starting_degree trimmed_coeffs

  let equal poly_a poly_b =
    let rec eqList lst_a lst_b =
      match (lst_a, lst_b) with
      | [], [] ->
          true
      | [], _ | _, [] ->
          false
      | a_hd :: a_tl, b_hd :: b_tl ->
          F.equal a_hd b_hd && eqList a_tl b_tl
    in
    let trimmed_a = trim poly_a in
    let trimmed_b = trim poly_b in
    let deg_a, coeffs_a = trimmed_a in
    let deg_b, coeffs_b = trimmed_b in
    deg_a = deg_b && eqList coeffs_a coeffs_b

  let negate poly =
    let starting_degree, coefficients = poly in
    let rec negateList lst =
      match lst with [] -> [] | hd :: tl -> F.negate hd :: negateList tl
    in
    create starting_degree (negateList coefficients)

  let zero = create 0 []

  let one = create 0 [F.one]

  let ( + ) poly_a poly_b =
    let rec pad lst how_much =
      if how_much <= 0 then lst else F.zero :: pad lst (how_much - 1)
    in
    let rec addLoop aCoeffs bCoeffs =
      match (aCoeffs, bCoeffs) with
      | [], _ ->
          bCoeffs
      | _, [] ->
          aCoeffs
      | a_hd :: a_tl, b_hd :: b_tl ->
          F.( + ) a_hd b_hd :: addLoop a_tl b_tl
    in
    let deg_a, coeffs_a = poly_a in
    let deg_b, coeffs_b = poly_b in
    let padded_coeffs_a = pad coeffs_a (deg_a - deg_b) in
    let padded_coeffs_b = pad coeffs_b (deg_b - deg_a) in
    create (min deg_a deg_b) (addLoop padded_coeffs_a padded_coeffs_b)

  let ( - ) poly_a poly_b = poly_a + negate poly_b

  let ( * ) poly_a poly_b =
    let rec mul poly_a poly_b =
      if equal poly_a zero || equal poly_b zero then zero
      else
        let deg_a, coeffs_a = poly_a in
        let deg_b, coeffs_b = poly_b in
        match coeffs_a with
        | [] ->
            zero
        | a_hd :: a_tl ->
            let firstProduct =
              create
                Int.(deg_a + deg_b)
                (List.map coeffs_b ~f:(fun c -> F.( * ) c a_hd))
            in
            let remainingProduct = mul (create Int.(deg_a + 1) a_tl) poly_b in
            firstProduct + remainingProduct
    in
    mul poly_a poly_b

  let ( ** ) poly_a n =
    let rec pow poly_a n =
      if n = 1 then poly_a else poly_a * pow poly_a Int.(n - 1)
    in
    pow poly_a (N.to_int_exn n)

  let to_string poly =
    let starting_degree, coefficients = poly in
    let rec print_loop deg coeffs =
      match coeffs with
      | [] ->
          ""
      | hd :: tl ->
          let first =
            if not (F.equal hd F.zero) then
              Printf.sprintf "(%s)%s%s"
                (* (if F.equal hd F.one && deg <> 0 then "" else F.to_string hd) *)
                (F.to_string hd)
                ( if deg = 0 then ""
                else "x" ^ if deg <> 1 then "^" ^ string_of_int deg else "" )
                (if List.length tl > 0 then " + " else "")
            else if List.length tl = 0 then "0"
            else ""
          in
          Printf.sprintf "%s%s" first (print_loop Int.(deg + 1) tl)
    in
    print_loop starting_degree coefficients

  let ( / ) poly_a poly_b =
    let rec div poly_a poly_b =
      let deg_a, coeffs_a = poly_a in
      let deg_b, coeffs_b = poly_b in
      if List.length coeffs_a < List.length coeffs_b then
        raise (Poly_division_error "not divisible!")
      else
        match coeffs_a with
        | [] ->
            zero
        | a_hd :: a_tl -> (
          match coeffs_b with
          | [] ->
              raise (Poly_division_error "dividing by zero!")
          | b_hd :: b_tl ->
              let fac = F.( / ) a_hd b_hd in
              let partial_quotient = create Int.(deg_a - deg_b) [fac] in
              if List.length coeffs_a = List.length coeffs_b then
                partial_quotient
              else
                let rec subtract_multiple x y =
                  match (x, y) with
                  | [], _ ->
                      []
                  | _, [] ->
                      x
                  | x_hd :: x_tl, y_hd :: y_tl ->
                      F.( - ) x_hd (F.( * ) fac y_hd)
                      :: subtract_multiple x_tl y_tl
                in
                let reduced =
                  create Int.(deg_a + 1) (subtract_multiple a_tl b_tl)
                in
                partial_quotient + div reduced poly_b )
    in
    div poly_a poly_b
end
