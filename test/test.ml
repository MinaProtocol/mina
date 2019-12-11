open Snarky_bn382

let () =
  let () =
    let open Fp in
    Format.printf "%i@." (size_in_bits ()) ;
    let x = of_int 1 in
    print x ;
    Format.printf "is_square:%b@." (is_square x) ;
    let y = of_int 2 in
    print y ;
    Format.printf "is_square:%b@." (is_square y) ;
    let z = random () in
    print z ;
    let a = add x y in
    (* 3 *)
    print a ;
    let b = mul x y in
    (* 2 *)
    print b ;
    let c = sub y x in
    (* 1 *)
    print c ;
    let d = sub x y in
    (* -1 *)
    print d ;
    mut_add d c ;
    (* d=0 *)
    print d ;
    mut_mul a a ;
    (* a=9 *)
    print a ;
    mut_sub a a ;
    (* a=0 *)
    print a ;
    copy a b ;
    (* a=2 *)
    print a ;
    let e = rng 1 in
    print e ;
    let f = rng 1 in
    print f ;
    Format.printf "equal? %b@." (equal e f) ;
    let g = rng 2 in
    print g ;
    Format.printf "equal? %b@." (equal e g) ;
    let h = rng 2 in
    print h ;
    List.iter delete [x; y; z; a; b; c; d; e; f; g; h]
  in
  let () =
    let open Fq in
    Format.printf "%i@." (size_in_bits ()) ;
    let x = of_int 1 in
    print x ;
    Format.printf "is_square:%b@." (is_square x) ;
    let y = of_int 2 in
    print y ;
    Format.printf "is_square:%b@." (is_square y) ;
    let z = random () in
    print z ;
    let a = add x y in
    (* 3 *)
    print a ;
    let b = mul x y in
    (* 2 *)
    print b ;
    let c = sub y x in
    (* 1 *)
    print c ;
    let d = sub x y in
    (* -1 *)
    print d ;
    mut_add d c ;
    (* d=0 *)
    print d ;
    mut_mul a a ;
    (* a=9 *)
    print a ;
    mut_sub a a ;
    (* a=0 *)
    print a ;
    copy a b ;
    (* a=2 *)
    print a ;
    let e = rng 1 in
    print e ;
    let f = rng 1 in
    print f ;
    Format.printf "equal? %b@." (equal e f) ;
    let g = rng 2 in
    print g ;
    Format.printf "equal? %b@." (equal e g) ;
    let h = rng 2 in
    print h ;
    List.iter delete [x; y; z; a; b; c; d; e; f; g; h]
  in
  ()
