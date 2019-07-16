open Core
open Default_backend.Backend

let coeffs_list_to_triple deg coeffs =
  let rec helper deg lst =
    match lst with
    | [] -> (0, Fr.zero, (0, []))
    | hd::tl -> if Fr.(equal hd zero) then helper (deg + 1) tl else (deg, hd, (deg + 1, tl)) in
  let first_deg, first_val, first_rest = helper deg coeffs in
  let first_rest_deg, first_rest_coeffs = first_rest in
  let second_deg, second_val, second_rest = helper first_rest_deg first_rest_coeffs in
  let second_rest_deg, second_rest_coeffs = second_rest in
  let third_deg, third_val, _ = helper second_rest_deg second_rest_coeffs in
  ((first_deg, first_val), (second_deg, second_val), (third_deg, third_val))

let convert_to_sigmas_psis poly n =
  let poly_coeffs = Bivariate_fr_laurent.coeffs poly in
  let rec parse_coeffs remaining_coeffs =
    match remaining_coeffs with
    | [] -> []
    | hd::tl ->
        let deg = Fr_laurent.deg hd in
        let coeffs = Fr_laurent.coeffs hd in
        (coeffs_list_to_triple deg coeffs) :: parse_coeffs tl in
  let input = parse_coeffs poly_coeffs in
  let as_lists = List.concat (List.map input ~f:(fun (a, b, c) -> [a; b; c])) in
  let nonzero = List.filter as_lists ~f:(fun (_, b) -> (not Fr.(equal b zero))) in
  let all_firsts = List.sort (List.map nonzero ~f:(fun (a, _) -> a)) ~compare:( - ) in
  let rec count_remove item lst =
    match lst with
    | [] -> 0, []
    | hd::tl ->
      let count_in_remaining, new_lst = count_remove item tl in
      if item = hd then 1 + count_in_remaining, new_lst else count_in_remaining, hd::new_lst in
  let rec count_all lst =
    match lst with
    | [] -> []
    | hd::_ ->
      let count_of_hd, new_lst = count_remove hd lst in
      (hd, count_of_hd) :: (count_all new_lst) in
  let counts = count_all all_firsts in
  let rec get_count x counts = 
    match counts with
    | [] -> 0
    | (a, b)::tl -> if a = x then b else get_count x tl in
  let to_fill_in = List.map ~f:(fun x -> (x, 3 - (get_count x counts))) (List.range 1 (n + 1)) in
  let rec repeat x n =
    if n = 0 then [] else x :: (repeat x (n - 1)) in
  let all_to_fill_in = List.fold_left to_fill_in ~init:[] ~f:(fun accum (a, b) -> accum @ (repeat a b)) in
  let rec fill_in so_far remaining =
    match so_far with
    | [] -> []
    | hd::tl ->
    let (a1, a2), (b1, b2), (c1, c2) = hd in
    let new_first, remaining1 = if Fr.(equal a2 zero) then ((List.hd_exn remaining), Fr.zero), (List.tl_exn remaining) else (a1, a2), remaining in
    let new_second, remaining2 = if Fr.(equal b2 zero) then ((List.hd_exn remaining1), Fr.zero), (List.tl_exn remaining1) else (b1, b2), remaining1 in
    let new_third, remaining3 = if Fr.(equal c2 zero) then ((List.hd_exn remaining2), Fr.zero), (List.tl_exn remaining2) else (c1, c2), remaining2 in
    (new_first, new_second, new_third) :: (fill_in tl remaining3) in
  (* Printf.printf "input: "; List.iter ~f:(fun ((a1, a2), (b1, b2), (c1, c2)) -> Printf.printf "((%d, %s), (%d, %s), (%d, %s))\n" a1 (Fr.to_string a2) b1 (Fr.to_string b2) c1 (Fr.to_string c2)) input; Printf.printf "\n"; *)
  let filled_in = fill_in input all_to_fill_in in
  let get_options first second third =
    [(first, second, third);
     (first, third, second);
     (second, first, third);
     (second, third, first);
     (third, second, first);
     (third, first, second)] in
  let is_good first second third first_so_far second_so_far third_so_far =
    (not (List.exists ~f:(fun x -> fst x = fst first) first_so_far))
    && (not (List.exists ~f:(fun x -> fst x = fst second) second_so_far))
    && (not (List.exists ~f:(fun x -> fst x = fst third) third_so_far)) in
  let rec rearrange first_so_far second_so_far third_so_far lst =
    match lst with
    | [] -> (first_so_far, second_so_far, third_so_far)
    | hd::tl ->
    let (first, second, third) = hd in
    let options = get_options first second third in
    let good_option = List.find_exn options ~f:(fun (f, s, t) -> is_good f s t first_so_far second_so_far third_so_far) in
    let new_first, new_second, new_third = good_option in
    let new_first_so_far = first_so_far @ [new_first] in
    let new_second_so_far = second_so_far @ [new_second] in
    let new_third_so_far = third_so_far @ [new_third] in
    rearrange new_first_so_far new_second_so_far new_third_so_far tl in
  let f, s, t = rearrange [] [] [] filled_in in
  let sigma_1 = List.map f ~f:fst in
  let sigma_2 = List.map s ~f:fst in
  let sigma_3 = List.map t ~f:fst in
  let psi_1 = List.map f ~f:snd in
  let psi_2 = List.map s ~f:snd in
  let psi_3 = List.map t ~f:snd in
  sigma_1, sigma_2, sigma_3, psi_1, psi_2, psi_3

let%test_unit "convert to sigmas/psis test" =
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
    Printf.printf "psi_3: "; List.iter ~f:(fun s -> Printf.printf "%s, " (Fr.to_string s)) psi_3; Printf.printf "\n"