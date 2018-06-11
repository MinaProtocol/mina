open Core_kernel

let average a b = (a +. b) /. 2.
;;

let range a b =
  let rec go acc i = 
    if i < a
    then acc
    else go (i :: acc) (i - 1)
  in
  go [] (b - 1)
;;

let positive_sum a b =
  let a = max a 0 in
  let b = max b 0 in
  a + b
;;

let () =
  printf "average %f\n" (average 4.0 (Float.of_int 3));
  printf "range "; (List.iter ~f:(printf "%d, ") (range 0 4)); printf "\n";
  printf "positive_sum %d\n" (positive_sum (-4) 2);
;;
