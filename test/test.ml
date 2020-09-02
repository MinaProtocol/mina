open Snarky_bn382

let () =
  let () =
    Format.printf "Testing Bigint@." ;
    let open Bigint384 in
    Format.printf "%i limbs of %i bytes@." (num_limbs ()) (bytes_per_limb ()) ;
    Format.printf "x = parse \"1\"@." ;
    let x = of_decimal_string "1" in
    print x ;
    let xp = Fp.of_bigint x in
    Fp.print xp ;
    let xq = Fq.of_bigint x in
    Fq.print xq ;
    Format.printf "y = parse \"50\"@." ;
    let y = of_decimal_string "50" in
    print y ;
    let yp = Fp.of_bigint y in
    Fp.print yp ;
    let yq = Fq.of_bigint y in
    Fq.print yq ;
    Format.printf "z = of_data (to_data y)@." ;
    let z = of_data (to_data y) in
    print z ;
    let zp = Fp.of_bigint z in
    Fp.print zp ;
    let zq = Fq.of_bigint z in
    Fq.print zq ;
    Format.printf "compare z z = %d@." (Unsigned.UInt8.to_int (compare z z)) ;
    Format.printf "compare x y = %d@." (Unsigned.UInt8.to_int (compare x y)) ;
    Format.printf "compare y x = %d@." (Unsigned.UInt8.to_int (compare y x)) ;
    Format.printf "a = x / y@." ;
    let a = div x y in
    print a ;
    let ap = Fp.of_bigint z in
    Fp.print ap ;
    let aq = Fq.of_bigint z in
    Fq.print aq ;
    Format.printf "b = parse(\"FF\", 16)@." ;
    let b = of_numeral "FF" 2 16 in
    print b ;
    let bp = Fp.of_bigint z in
    Fp.print bp ;
    let bq = Fq.of_bigint z in
    Fq.print bq ;
    Format.printf "True? %b False? %b@." (test_bit b 1) (test_bit x 2) ;
    List.iter delete [x; y; z; a; b] ;
    List.iter Fp.delete [xp; yp; zp; ap; bp] ;
    List.iter Fq.delete [xq; yq; zq; aq; bq]
  in
  let () =
    Format.printf "Testing Fp@." ;
    let open Fp in
    Format.printf "size(bits): %i@." (size_in_bits ()) ;
    Format.printf "size:@." ;
    let s = size () in
    Bigint384.print s ;
    let s_ = of_bigint s in
    print s_ ;
    Format.printf "x = of_int 1@." ;
    let x = of_int (Unsigned.UInt64.of_int 1) in
    print x ;
    Format.printf "is_square x = %b@." (is_square x) ;
    Format.printf "y = of_int 1@." ;
    let y = of_int (Unsigned.UInt64.of_int 2) in
    print y ;
    Format.printf "is_square y = %b@." (is_square y) ;
    Format.printf "z = random ()@." ;
    let z = random () in
    print z ;
    Format.printf "a = add x y@." ;
    let a = add x y in
    print a ;
    Format.printf "b = mul x y@." ;
    let b = mul x y in
    print b ;
    Format.printf "c = sub x y@." ;
    let c = sub y x in
    print c ;
    Format.printf "d = sub x y@." ;
    let d = sub x y in
    print d ;
    Format.printf "mut_add d c@." ;
    mut_add d c ;
    print d ;
    Format.printf "mut_mul a a@." ;
    mut_mul a a ;
    print a ;
    Format.printf "mut_sub a a@." ;
    mut_sub a a ;
    print a ;
    Format.printf "copy a b@." ;
    copy a b ;
    print a ;
    Format.printf "e = rng 1@." ;
    let e = rng 1 in
    print e ;
    Format.printf "f = rng 1@." ;
    let f = rng 1 in
    print f ;
    Format.printf "equal e f = %b@." (equal e f) ;
    Format.printf "g = rng 2@." ;
    let g = rng 2 in
    print g ;
    Format.printf "equal e g = %b@." (equal e g) ;
    Format.printf "h = rng 2@." ;
    let h = rng 2 in
    print h ;
    Format.printf "i = to_bigint a@." ;
    let i = to_bigint a in
    Bigint384.print i ;
    Format.printf "j = of_bigint i@." ;
    let j = of_bigint i in
    print j ;
    List.iter Bigint384.delete [i; s] ;
    List.iter delete [x; y; z; a; b; c; d; e; f; g; h; j; s_]
  in
  let () =
    Format.printf "Testing Fq@." ;
    let open Fp in
    Format.printf "size(bits): %i@." (size_in_bits ()) ;
    Format.printf "size:@." ;
    let s = size () in
    Bigint384.print s ;
    let s_ = of_bigint s in
    print s_ ;
    Format.printf "x = of_int 1@." ;
    let x = of_int (Unsigned.UInt64.of_int 1) in
    print x ;
    Format.printf "is_square x = %b@." (is_square x) ;
    Format.printf "y = of_int 1@." ;
    let y = of_int (Unsigned.UInt64.of_int 2) in
    print y ;
    Format.printf "is_square y = %b@." (is_square y) ;
    Format.printf "z = random ()@." ;
    let z = random () in
    print z ;
    Format.printf "a = add x y@." ;
    let a = add x y in
    print a ;
    Format.printf "b = mul x y@." ;
    let b = mul x y in
    print b ;
    Format.printf "c = sub x y@." ;
    let c = sub y x in
    print c ;
    Format.printf "d = sub x y@." ;
    let d = sub x y in
    print d ;
    Format.printf "mut_add d c@." ;
    mut_add d c ;
    print d ;
    Format.printf "mut_mul a a@." ;
    mut_mul a a ;
    print a ;
    Format.printf "mut_sub a a@." ;
    mut_sub a a ;
    print a ;
    Format.printf "copy a b@." ;
    copy a b ;
    print a ;
    Format.printf "e = rng 1@." ;
    let e = rng 1 in
    print e ;
    Format.printf "f = rng 1@." ;
    let f = rng 1 in
    print f ;
    Format.printf "equal e f = %b@." (equal e f) ;
    Format.printf "g = rng 2@." ;
    let g = rng 2 in
    print g ;
    Format.printf "equal e g = %b@." (equal e g) ;
    Format.printf "h = rng 2@." ;
    let h = rng 2 in
    print h ;
    Format.printf "i = to_bigint a@." ;
    let i = to_bigint a in
    Bigint384.print i ;
    Format.printf "j = of_bigint i@." ;
    let j = of_bigint i in
    print j ;
    List.iter Bigint384.delete [i; s] ;
    List.iter delete [x; y; z; a; b; c; d; e; f; g; h; j; s_]
  in
  ()
