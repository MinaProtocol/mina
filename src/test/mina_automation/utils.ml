open Integration_test_lib

let wget ~url ~target = Util.run_cmd_exn "." "wget" [ "-c"; url; "-O"; target ]

let sed ~search ~replacement ~input =
  Util.run_cmd_exn "." "sed"
    [ "-i"; "-e"; Printf.sprintf "s/%s/%s/g" search replacement; input ]

let untar ~archive ~output =
  Util.run_cmd_exn "." "tar" [ "-xf"; archive; "-C"; output ]
