module Configurator = Configurator.V1

let () =
  Configurator.main ~name:"c_test" (fun t ->
    let c_result =
      Configurator.c_test t {c|
#include <stdio.h>
int main()
{
   printf("Hello, World!");
   return 0;
}
|c} in
    assert c_result;
    print_endline "Successfully compiled c program"
  )
