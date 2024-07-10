#ifndef BOXROOT_H
#define BOXROOT_H

#include <caml/mlvalues.h>

typedef struct boxroot_private* boxroot;

/* `boxroot_create(v)` allocates a new boxroot initialised to the
   value `v`. This value will be considered as a root by the OCaml GC
   as long as the boxroot lives or until it is modified. A return
   value of `NULL` indicates a failure of allocation of the backing
   store. */
boxroot boxroot_create(value);

/* `boxroot_get(r)` returns the contained value, subject to the usual
   discipline for non-rooted values. `boxroot_get_ref(r)` returns a
   pointer to a memory cell containing the value kept alive by `r`,
   that gets updated whenever its block is moved by the OCaml GC. The
   pointer becomes invalid after any call to `boxroot_delete(r)` or
   `boxroot_modify(&r,v)`. The argument must be non-null. */
value boxroot_get(boxroot);
value const * boxroot_get_ref(boxroot);

/* `boxroot_delete(r)` desallocates the boxroot `r`. The value is no
   longer considered as a root by the OCaml GC. The argument must be
   non-null. */
void boxroot_delete(boxroot);

/* `boxroot_modify(&r,v)` changes the value kept alive by the boxroot
   `r` to `v`. It is equivalent to the following:
   ```
   boxroot_delete(r);
   r = boxroot_create(v);
   ```
   In particular, the root can be reallocated. However, unlike
   `boxroot_create`, `boxroot_modify` never fails, so `r` is
   guaranteed to be non-NULL afterwards. In addition, `boxroot_modify`
   is more efficient. Indeed, the reallocation, if needed, occurs at
   most once between two minor collections. */
void boxroot_modify(boxroot *, value);


/* The behaviour of the above functions is well-defined only after the
   allocator has been initialised with `boxroot_setup`, which must be
   called after OCaml startup, and before it has released its
   resources with `boxroot_teardown`. */
int boxroot_setup();
void boxroot_teardown();

/* Show some statistics on the standard output. */
void boxroot_print_stats();

#endif // BOXROOT_H
