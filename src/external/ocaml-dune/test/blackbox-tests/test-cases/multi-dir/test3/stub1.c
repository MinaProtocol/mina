#include "include/dune_test.h"

CAMLprim value dune_test_x()
{
  return caml_copy_string("Hello,");
}
