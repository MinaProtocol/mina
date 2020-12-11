# Base 58 Encoding OCaml library

This library provide encoding and decoding function for the Base 58 encoding. 

### Install

```bash 
opam install base58 
```

### Documentation 

OCamldoc generated doc can be found [here](http://mransan.github.io/base58/).

### Example

```OCaml
let () = 
  let alphabet = B58.make_alphabet "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz" in 
  let data     = Bytes.of_string "Hello World"  in 
  let b58      = B58.encode alphabet data in 
  print_endline @@ Bytes.to_string b58
```

Then to compile:

```bash 
ocamlbuild -use-ocamlfind -pkgs base58 example01.native
```

