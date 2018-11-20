#include "q.h"
#include <caml/mlvalues.h>
#include <caml/memory.h>

CAMLprim value ocaml_question (value unit)
{
  CAMLparam1 (unit);
  CAMLreturn (Val_int(ANSWER));
}
