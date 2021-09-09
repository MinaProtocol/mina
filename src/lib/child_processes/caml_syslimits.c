#include <limits.h>
#include <caml/mlvalues.h>

CAMLprim value caml_syslimits_path_max() {
  return Val_int(PATH_MAX);
}
