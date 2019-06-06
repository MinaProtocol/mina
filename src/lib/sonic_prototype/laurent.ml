open Snarkette
open Snarkette.Mnt6_80

exception PolyDivisionError of string

type 'f laurent = {starting_index: int; coefficients: 'f list}

let makeLaurent idx coeffs = {starting_index= idx; coefficients= coeffs}

let laurentZero = makeLaurent 0 []

let rec eqList a b =
  match (a, b) with
  | [], [] ->
      true
  | [], _ | _, [] ->
      false
  | aHd :: aTl, bHd :: bTl ->
      Fq.equal aHd bHd && eqList aTl bTl

let rec mulList x lst =
  match lst with [] -> [] | hd :: tl -> Fq.( * ) x hd :: mulList x tl

(* assumes that length of a > length of b *)
let rec subtractList a b =
  match a with
  | [] ->
      []
  | aHd :: aTl -> (
    match b with
    | [] ->
        a
    | bHd :: bTl ->
        Fq.( - ) aHd bHd :: subtractList aTl bTl )

let rec trimLaurent poly =
  match poly.coefficients with
  | [] ->
      poly
  | hd :: tl ->
      if Fq.equal hd Fq.zero then
        trimLaurent (makeLaurent (poly.starting_index + 1) tl)
      else poly

let evalLaurent poly pt =
  let rec loop remainingCoeffs pt currentPower =
    match remainingCoeffs with
    | [] ->
        Fq.zero
    | _ :: _ ->
        Fq.( + ) currentPower
          (loop (List.tl remainingCoeffs) pt (Fq.( * ) pt currentPower))
  in
  loop poly.coefficients pt (Fq.( ** ) pt (Nat.of_int poly.starting_index))

let printLaurent poly =
  let rec printLoop idx coeffs =
    match coeffs with
    | [] ->
        Printf.printf "\n" ; ()
    | hd :: tl ->
        if not (Fq.equal hd Fq.zero) then
          Printf.printf "%s%s%s"
            (if Fq.equal hd Fq.one && idx != 0 then "" else Fq.to_string hd)
            ( if idx = 0 then ""
            else "x" ^ if idx != 1 then "^" ^ string_of_int idx else "" )
            (if List.length tl > 0 then " + " else "")
        else () ;
        printLoop (idx + 1) tl
  in
  printLoop poly.starting_index poly.coefficients

let laurentIsZero poly = List.length poly.coefficients = 0

let negateLaurent poly =
  let rec negateList lst =
    match lst with
    | [] ->
        []
    | hd :: tl ->
        Fq.( - ) Fq.zero hd :: negateList tl
  in
  makeLaurent poly.starting_index (negateList poly.coefficients)

let eqLaurent a b =
  let aT = trimLaurent a in
  let bT = trimLaurent b in
  aT.starting_index = bT.starting_index
  && eqList aT.coefficients bT.coefficients

let addLaurent a b =
  let rec pad lst howMuch =
    if howMuch = 0 then lst else Fq.zero :: pad lst (howMuch - 1)
  in
  let rec addLoop aCoeffs bCoeffs =
    match aCoeffs with
    | [] ->
        bCoeffs
    | aHd :: aTl -> (
      match bCoeffs with
      | [] ->
          aCoeffs
      | bHd :: bTl ->
          Fq.( + ) aHd bHd :: addLoop aTl bTl )
  in
  let newStartingIndex = min a.starting_index b.starting_index in
  let paddedACoeffs =
    if newStartingIndex < a.starting_index then
      pad a.coefficients (a.starting_index - newStartingIndex)
    else a.coefficients
  in
  let paddedBCoeffs =
    if newStartingIndex < b.starting_index then
      pad b.coefficients (b.starting_index - newStartingIndex)
    else b.coefficients
  in
  makeLaurent newStartingIndex (addLoop paddedACoeffs paddedBCoeffs)

let subtractLaurent a b = addLaurent a (negateLaurent b)

let rec mulLaurent a b =
  if laurentIsZero a || laurentIsZero b then laurentZero
  else
    let firstProduct =
      makeLaurent
        (a.starting_index + b.starting_index)
        (mulList (List.hd a.coefficients) b.coefficients)
    in
    let remainingProduct =
      mulLaurent
        (makeLaurent (a.starting_index + 1) (List.tl a.coefficients))
        b
    in
    addLaurent firstProduct remainingProduct

let rec quotLaurent dividend divisor =
  if List.length dividend.coefficients < List.length divisor.coefficients then
    raise (PolyDivisionError "not divisible!")
  else
    let fac =
      Fq.( / ) (List.hd dividend.coefficients) (List.hd divisor.coefficients)
    in
    let partialStartingIndex =
      dividend.starting_index - divisor.starting_index
    in
    let partialQuotient = makeLaurent partialStartingIndex [fac] in
    let reducedCoefficients =
      List.tl
        (subtractList dividend.coefficients (mulList fac divisor.coefficients))
    in
    let reduced =
      makeLaurent (dividend.starting_index + 1) reducedCoefficients
    in
    if List.length reducedCoefficients < List.length divisor.coefficients then
      partialQuotient
    else addLaurent partialQuotient (quotLaurent reduced divisor)
