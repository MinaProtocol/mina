open Core
open Default_backend.Backend

(* helper function turn a univariate Y polynomial a_1 Y^j_1 + a_2 Y^j_2 + a_3 Y^j_3
   (the coefficient of some X^i term) into the triple
   ((j_1, a_1), (j_2, a_2), (j_3, a_3))
*)
let coeffs_list_to_triple deg coeffs =
  let rec helper deg lst =
    match lst with
    | [] ->
        (0, Fr.zero, (0, []))
    | hd :: tl ->
        if Fr.(equal hd zero) then helper (deg + 1) tl
        else (deg, hd, (deg + 1, tl))
  in
  let first_deg, first_val, first_rest = helper deg coeffs in
  let first_rest_deg, first_rest_coeffs = first_rest in
  let second_deg, second_val, second_rest =
    helper first_rest_deg first_rest_coeffs
  in
  let second_rest_deg, second_rest_coeffs = second_rest in
  let third_deg, third_val, _ = helper second_rest_deg second_rest_coeffs in
  ((first_deg, first_val), (second_deg, second_val), (third_deg, third_val))

(* input:   a bivariate polynomial poly(X, Y), which we assume has no more than three Y^j terms
            multiplying any particular X^i term
   output:  three permutations sigma_1, sigma_2, and sigma_3 of {1, ..., n} and and three vectors
            psi_1, psi_2, and psi_3 such that poly(X, Y) = sum_i=1^n phi_{sigma_{1,i}} X^i Y^sigma_{1,i}
                                                                   + phi_{sigma_{2,i}} X^i Y^sigma_{2,i}
                                                                   + phi_{sigma_{3,i}} X^i Y^sigma_{3,i}
*)
let convert_to_sigmas_psis poly n =
  let poly_coeffs = Bivariate_fr_laurent.coeffs poly in
  (* helper function to turn polynomial into list of tuples:
       (a_1 Y^j_1 + a_2 Y^j_2 + a_3 Y^j_3) X^1
     + (b_1 Y^k_1 + b_2 Y^k_2 + b_3 Y^k_3) X^2
     + (c_1 Y^l_1 + c_2 Y^l_2 + c_3 Y^l_3) X^3
      --> [ ((j_1, a_1), (j_2, a_2), (j_3, a_3))
          ; ((k_1, b_1), (k_2, b_2), (k_3, b_3))
          ; ((l_1, c_1), (l_2, c_2), (l_3, c_3)) ]
   *)
  let rec parse_coeffs remaining_coeffs =
    match remaining_coeffs with
    | [] ->
        []
    | hd :: tl ->
        let deg = Fr_laurent.deg hd in
        let coeffs = Fr_laurent.coeffs hd in
        coeffs_list_to_triple deg coeffs :: parse_coeffs tl
  in
  let input = parse_coeffs poly_coeffs in
  let rec pad lst n =
    if List.length lst >= n then lst
    else pad (lst @ [((0, Fr.zero), (0, Fr.zero), (0, Fr.zero))]) n
  in
  let padded_input = pad input n in
  List.iter padded_input ~f:(fun ((a, b), (c, d), (e, f)) ->
      Printf.printf "((%d, %s), (%d, %s), (%d, %s))\n" a (Fr.to_string b) c
        (Fr.to_string d) e (Fr.to_string f)) ;
  let as_lists =
    List.concat (List.map padded_input ~f:(fun (a, b, c) -> [a; b; c]))
  in
  (* remove all the "filler" terms with zero coefficients (added in ) *)
  let nonzero =
    List.filter as_lists ~f:(fun (_, b) -> not Fr.(equal b zero))
  in
  List.iter nonzero ~f:(fun (a, b) ->
      Printf.printf "%d, %s\n" a (Fr.to_string b)) ;
  (* list of all the powers j s.t. Y^j has non-zero coefficient (so we can count them) *)
  let all_powers =
    List.sort (List.map nonzero ~f:(fun (a, _) -> a)) ~compare:( - )
  in
  (* helper function to count occurrences of first item in a list *)
  let rec count_remove item lst =
    match lst with
    | [] ->
        (0, [])
    | hd :: tl ->
        let count_in_remaining, new_lst = count_remove item tl in
        if item = hd then (1 + count_in_remaining, new_lst)
        else (count_in_remaining, hd :: new_lst)
  in
  (* turn list of powers Y^j into counts of how many there *)
  let rec count_all lst =
    match lst with
    | [] ->
        []
    | hd :: _ ->
        let count_of_hd, new_lst = count_remove hd lst in
        (hd, count_of_hd) :: count_all new_lst
  in
  let counts = count_all all_powers in
  let rec get_count x counts =
    match counts with
    | [] ->
        0
    | (a, b) :: tl ->
        if a = x then b else get_count x tl
  in
  (* for each power Y^j, we need to "fill in" terms with coefficient 0, for *any* X^i so there's 3 occurrences *)
  let to_fill_in =
    List.map ~f:(fun x -> (x, 3 - get_count x counts)) (List.range 1 (n + 1))
  in
  let rec repeat x n = if n = 0 then [] else x :: repeat x (n - 1) in
  let all_to_fill_in =
    List.fold_left to_fill_in ~init:[] ~f:(fun accum (a, b) ->
        accum @ repeat a b)
  in
  let rec fill_in so_far remaining =
    match so_far with
    | [] ->
        []
    | hd :: tl ->
        let (a1, a2), (b1, b2), (c1, c2) = hd in
        let new_first, remaining1 =
          if Fr.(equal a2 zero) then
            ((List.hd_exn remaining, Fr.zero), List.tl_exn remaining)
          else ((a1, a2), remaining)
        in
        let new_second, remaining2 =
          if Fr.(equal b2 zero) then
            ((List.hd_exn remaining1, Fr.zero), List.tl_exn remaining1)
          else ((b1, b2), remaining1)
        in
        let new_third, remaining3 =
          if Fr.(equal c2 zero) then
            ((List.hd_exn remaining2, Fr.zero), List.tl_exn remaining2)
          else ((c1, c2), remaining2)
        in
        (new_first, new_second, new_third) :: fill_in tl remaining3
  in
  let filled_in = fill_in padded_input all_to_fill_in in
  List.iter filled_in ~f:(fun ((a, b), (c, d), (e, f)) ->
      Printf.printf "((%d, %s), (%d, %s), (%d, %s))\n" a (Fr.to_string b) c
        (Fr.to_string d) e (Fr.to_string f)) ;
  (* all the possible ways to arrange the 3 Y^j powers for a given X^i *)
  let get_options first second third =
    [ (first, second, third)
    ; (first, third, second)
    ; (second, first, third)
    ; (second, third, first)
    ; (third, second, first)
    ; (third, first, second) ]
  in
  (* check if this arrangement "conflicts" with what we've chosen so far: that is, puts a Y^j power in the
     same permutation (sigma_1, sigma_2, or sigma_2) as that same Y^j for some other X^i *)
  let is_good first second third first_so_far second_so_far third_so_far =
    (not (List.exists ~f:(fun x -> fst x = fst first) first_so_far))
    && (not (List.exists ~f:(fun x -> fst x = fst second) second_so_far))
    && not (List.exists ~f:(fun x -> fst x = fst third) third_so_far)
  in
  let rec rearrange first_so_far second_so_far third_so_far lst =
    match lst with
    | [] ->
        (first_so_far, second_so_far, third_so_far)
    | hd :: tl ->
        let first, second, third = hd in
        let options = get_options first second third in
        Printf.printf "First so far: " ;
        List.iter first_so_far ~f:(fun (a, _) -> Printf.printf "%d, " a) ;
        Printf.printf "\n" ;
        Printf.printf "Second so far: " ;
        List.iter second_so_far ~f:(fun (a, _) -> Printf.printf "%d, " a) ;
        Printf.printf "\n" ;
        Printf.printf "Third so far: " ;
        List.iter third_so_far ~f:(fun (a, _) -> Printf.printf "%d, " a) ;
        Printf.printf "\n" ;
        Printf.printf "First, second, third: " ;
        Printf.printf "%d, %d, %d\n" (fst first) (fst second) (fst third) ;
        let good_option =
          List.find_exn options ~f:(fun (f, s, t) ->
              is_good f s t first_so_far second_so_far third_so_far)
        in
        let new_first, new_second, new_third = good_option in
        let new_first_so_far = first_so_far @ [new_first] in
        let new_second_so_far = second_so_far @ [new_second] in
        let new_third_so_far = third_so_far @ [new_third] in
        rearrange new_first_so_far new_second_so_far new_third_so_far tl
  in
  let f, s, t = rearrange [] [] [] filled_in in
  let sigma_1 = List.map f ~f:fst in
  let sigma_2 = List.map s ~f:fst in
  let sigma_3 = List.map t ~f:fst in
  let psi_1 = List.map f ~f:snd in
  let psi_2 = List.map s ~f:snd in
  let psi_3 = List.map t ~f:snd in
  Printf.printf "sigma_1: " ;
  List.iter ~f:(Printf.printf "%d, ") sigma_1 ;
  Printf.printf "\n" ;
  Printf.printf "sigma_2: " ;
  List.iter ~f:(Printf.printf "%d, ") sigma_2 ;
  Printf.printf "\n" ;
  Printf.printf "sigma_3: " ;
  List.iter ~f:(Printf.printf "%d, ") sigma_3 ;
  Printf.printf "\n" ;
  Printf.printf "psi_1: " ;
  List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_1 ;
  Printf.printf "\n" ;
  Printf.printf "psi_2: " ;
  List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_2 ;
  Printf.printf "\n" ;
  Printf.printf "psi_3: " ;
  List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_3 ;
  Printf.printf "\n" ;
  (sigma_1, sigma_2, sigma_3, psi_1, psi_2, psi_3)

(* let%test_unit "convert to sigmas/psis test" =
    let n = 15 in
    let poly = Bivariate_fr_laurent.create 1 [
      Fr_laurent.( + ) (Fr_laurent.create 1 [Fr.of_int 1]) (Fr_laurent.create 7 [Fr.of_int 1]) ;
      Fr_laurent.( + ) (Fr_laurent.create 2 [Fr.of_int 1]) (Fr_laurent.create 7 [Fr.of_int 2]) ;
      Fr_laurent.( + ) (Fr_laurent.create 3 [Fr.of_int 1]) (Fr_laurent.create 8 [Fr.of_int 4]) ;
      Fr_laurent.( + ) (Fr_laurent.create 7 [Fr.of_int (-1)]) (Fr_laurent.create 8 [Fr.of_int 1]) ;
      (Fr_laurent.create 8 [Fr.of_int (-1)]) ;
      (Fr_laurent.create 1 [Fr.of_int 1]);
      (Fr_laurent.create 2 [Fr.of_int 1]) ;
      (Fr_laurent.create 3 [Fr.of_int 1]) ;
      Fr_laurent.zero ;
      Fr_laurent.zero ;
      (Fr_laurent.create 4 [Fr.of_int 1]) ;
      (Fr_laurent.create 5 [Fr.of_int 1]) ;
      (Fr_laurent.create 6 [Fr.of_int 1]) ;
      Fr_laurent.zero ;
      Fr_laurent.zero
    ] in
    let sigma_1, sigma_2, sigma_3, psi_1, psi_2, psi_3 = convert_to_sigmas_psis poly n in
    Printf.printf "sigma_1: "; List.iter ~f:(Printf.printf "%d, ") sigma_1; Printf.printf "\n";
    Printf.printf "sigma_2: "; List.iter ~f:(Printf.printf "%d, ") sigma_2; Printf.printf "\n";
    Printf.printf "sigma_3: "; List.iter ~f:(Printf.printf "%d, ") sigma_3; Printf.printf "\n";
    Printf.printf "psi_1: "; List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_1; Printf.printf "\n";
    Printf.printf "psi_2: "; List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_2; Printf.printf "\n";
    Printf.printf "psi_3: "; List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_3; Printf.printf "\n" *)
