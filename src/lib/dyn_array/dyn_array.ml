open Core
include DynArray

let sexp_of_t sexp_of_a t = [%sexp_of: a list] (DynArray.to_list t)

let t_of_sexp a_of_sexp ls = DynArray.of_list ([%of_sexp: a list] ls)

include Binable.Of_binable1
          (Array)
          (struct
            type 'a t = 'a DynArray.t

            let to_binable = DynArray.to_array

            let of_binable = DynArray.of_array
          end)
