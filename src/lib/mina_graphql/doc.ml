open Core_kernel

let date ?(extra = "") s =
  sprintf
    "%s (stringified Unix time - number of milliseconds since January 1, \
     1970)%s"
    s extra
