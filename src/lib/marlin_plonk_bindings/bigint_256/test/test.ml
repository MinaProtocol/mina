open Marlin_plonk_bindings_bigint_256

let () =
  Format.printf "%i limbs of %i bytes@." (num_limbs ()) (bytes_per_limb ()) ;
  let x = of_decimal_string "12345" in
  print x ;
  Format.printf "%s@." (to_string x) ;
  let y = of_decimal_string "45" in
  print y ;
  Format.printf "%s@." (to_string y) ;
  let comparisons x y =
    Format.printf "%s < %s? %b@.%s = %s? %b@.%s > %s? %b@." (to_string x)
      (to_string y) (x < y) (to_string x) (to_string y) (x = y) (to_string x)
      (to_string y) (x > y)
  in
  comparisons x x ;
  comparisons x y ;
  comparisons y x ;
  Format.printf "compare(%s, %s)=%i@." (to_string x) (to_string x) (compare x x) ;
  Format.printf "compare(%s, %s)=%i@." (to_string x) (to_string y) (compare x y) ;
  Format.printf "compare(%s, %s)=%i@." (to_string y) (to_string x) (compare y x) ;
  let z = div x y in
  Format.printf "%s@." (to_string z) ;
  Format.printf "test_bit(1, 0)=%b@." (test_bit (of_decimal_string "1") 0)
