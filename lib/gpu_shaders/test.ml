open Core
open Unsigned
open Gpu_dsl

let program =
  let open Dsl in
  let open Dsl.Type in
  let open Dsl.Let_syntax in
  declare_function "main"
    ~args:Arguments_spec.[]
    ~vars:Local_variables_spec.[]
    ~returning:Void
    (fun () ->
      let%bind x = constant Uint32 (UInt32.of_int 2) in
      let%bind y = constant Uint32 (UInt32.of_int 5) in
      let%bind r = add_ignore_overflow ~name:"r" x y in
      Pure void )

let () =
  assert (Array.length Sys.argv >= 2) ;
  Compiler.compile program Sys.argv.(1)
