open Core

exception PolyDivisionError of string

module type Ring = sig
  type nat

  type t [@@deriving eq, sexp]

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

module type Ring_laurent = sig
  type ring

  type t = int * ring list

  val create : int -> ring list -> t

  val eval : t -> ring -> ring

  val equal : t -> t -> bool

  val negate : t -> t

  val zero : t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val ( * ) : t -> t -> t

  val to_string : t -> string
end

module Make_ring_laurent (N : sig
  type t

  val of_int : int -> t
end)
(R : Ring with type nat := N.t) : Ring_laurent with type ring := R.t = struct
  type t = int * R.t list

  let create starting_degree coefficients = (starting_degree, coefficients)

  let eval poly pt =
    let starting_degree, coefficients = poly in
    let rec loop remainingCoeffs pt currentPower =
      match remainingCoeffs with
      | [] ->
          R.zero
      | hd :: tl ->
          R.( + ) (R.( * ) hd currentPower)
            (loop tl pt (R.( * ) pt currentPower))
    in
    loop coefficients pt (R.( ** ) pt (N.of_int starting_degree))

  let trim poly =
    let starting_degree, coefficients = poly in
    let rec allZeroes lst =
      match lst with
      | [] ->
          true
      | hd :: tl ->
          R.equal R.zero hd && allZeroes tl
    in
    let rec removeZerosFromEnd lst =
      match lst with
      | [] ->
          []
      | hd :: tl ->
          if allZeroes lst then [] else hd :: removeZerosFromEnd tl
    in
    let rec trimBeginning starting_degree coeffs =
      match coeffs with
      | [] ->
          create starting_degree coeffs
      | hd :: tl ->
          if R.equal R.zero hd then trimBeginning (starting_degree + 1) tl
          else create starting_degree coeffs
    in
    trimBeginning starting_degree (removeZerosFromEnd coefficients)

  let equal polyA polyB =
    let rec eqList lstA lstB =
      match (lstA, lstB) with
      | [], [] ->
          true
      | [], _ | _, [] ->
          false
      | aHd :: aTl, bHd :: bTl ->
          R.equal aHd bHd && eqList aTl bTl
    in
    let trimmedA = trim polyA in
    let trimmedB = trim polyB in
    let degA, coeffsA = trimmedA in
    let degB, coeffsB = trimmedB in
    degA = degB && eqList coeffsA coeffsB

  let negate poly =
    let starting_degree, coefficients = poly in
    let rec negateList lst =
      match lst with [] -> [] | hd :: tl -> R.negate hd :: negateList tl
    in
    create starting_degree (negateList coefficients)

  let zero = create 0 []

  let ( + ) polyA polyB =
    let rec pad lst howMuch =
      if howMuch <= 0 then lst else R.zero :: pad lst (howMuch - 1)
    in
    let rec addLoop aCoeffs bCoeffs =
      match (aCoeffs, bCoeffs) with
      | [], _ ->
          bCoeffs
      | _, [] ->
          aCoeffs
      | aHd :: aTl, bHd :: bTl ->
          R.( + ) aHd bHd :: addLoop aTl bTl
    in
    let degA, coeffsA = polyA in
    let degB, coeffsB = polyB in
    let padded_coeffsA = pad coeffsA (degA - degB) in
    let padded_coeffsB = pad coeffsB (degB - degA) in
    create (min degA degB) (addLoop padded_coeffsA padded_coeffsB)

  let ( - ) polyA polyB = polyA + negate polyB

  let ( * ) polyA polyB =
    let rec mul polyA polyB =
      if equal polyA zero || equal polyB zero then zero
      else
        let degA, coeffsA = polyA in
        let degB, coeffsB = polyB in
        match coeffsA with
        | [] ->
            zero
        | aHd :: aTl ->
            let firstProduct =
              create
                Int.(degA + degB)
                (List.map coeffsB ~f:(fun c -> R.( * ) c aHd))
            in
            let remainingProduct = mul (create Int.(degA + 1) aTl) polyB in
            firstProduct + remainingProduct
    in
    mul polyA polyB

  let to_string poly =
    let starting_degree, coefficients = poly in
    let rec printLoop deg coeffs =
      match coeffs with
      | [] ->
          Printf.sprintf "\n"
      | hd :: tl ->
          let first =
            if not (R.equal hd R.zero) then
              Printf.sprintf "%s%s%s"
                (if R.equal hd R.one && deg <> 0 then "" else R.to_string hd)
                ( if deg = 0 then ""
                else "x" ^ if deg <> 1 then "^" ^ string_of_int deg else "" )
                (if List.length tl > 0 then " + " else "")
            else ""
          in
          Printf.sprintf "%s%s" first (printLoop Int.(deg + 1) tl)
    in
    printLoop starting_degree coefficients
end

module type Field_laurent = sig
  type field

  include Ring_laurent with type ring := field

  val ( / ) : t -> t -> t
end

module Make_field_laurent (N : sig
  type t

  val of_int : int -> t
end)
(F : Field with type nat := N.t) : Field_laurent with type field := F.t =
struct
  include Make_ring_laurent (N) (F)

  let ( / ) polyA polyB =
    let rec div polyA polyB =
      let degA, coeffsA = polyA in
      let degB, coeffsB = polyB in
      if List.length coeffsA < List.length coeffsB then
        raise (PolyDivisionError "not divisible!")
      else
        match coeffsA with
        | [] ->
            zero
        | aHd :: aTl -> (
          match coeffsB with
          | [] ->
              raise (PolyDivisionError "dividing by zero!")
          | bHd :: bTl ->
              let fac = F.( / ) aHd bHd in
              let partial_quotient = create Int.(degA - degB) [fac] in
              if List.length coeffsA = List.length coeffsB then
                partial_quotient
              else
                let rec subtractMultiple x y =
                  match (x, y) with
                  | [], _ ->
                      []
                  | _, [] ->
                      x
                  | xHd :: xTl, yHd :: yTl ->
                      F.( - ) xHd (F.( * ) fac yHd) :: subtractMultiple xTl yTl
                in
                let reduced =
                  create Int.(degA + 1) (subtractMultiple aTl bTl)
                in
                partial_quotient + div reduced polyB )
    in
    div polyA polyB
end
