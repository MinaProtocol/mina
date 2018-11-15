#include "../include/dune_test.h"

CAMLprim value dune_test_y()
{
  return caml_copy_string(" world!");
}
