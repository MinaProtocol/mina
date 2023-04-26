open Core_bench

let bench_add =
  let x = Pasta_bindings.Fp.random () in
  let y = Pasta_bindings.Fp.random () in
  Bench.Test.create ~name:"Benchmark Pasta Fp add" (fun () ->
      ignore (Pasta_bindings.Fp.add x y) )

let bench_mul =
  let x = Pasta_bindings.Fp.random () in
  let y = Pasta_bindings.Fp.random () in
  Bench.Test.create ~name:"Benchmark Pasta Fp mul" (fun () ->
      ignore (Pasta_bindings.Fp.mul x y) )

let () =
  Command_unix.run (Core_bench.Bench.make_command [ bench_add; bench_mul ])
