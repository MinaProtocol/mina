let () =
  let alphabet =
    B58.make_alphabet
      "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  in
  let data = Bytes.of_string "Hello World" in
  let b58 = B58.encode alphabet data in
  print_endline @@ Bytes.to_string b58
