type t_(+'a, +'b) =
  | Ok('a)
  | Error('b);

include Monad.Make2({
  type t(+'a, 'b) = t_('a, 'b);
  let return = a => Ok(a);
  let map = `Define_using_bind;
  let bind = (t, ~f) =>
    switch (t) {
    | Ok(x) =>
      switch (f(x)) {
      | Ok(x') => Ok(x')
      | Error(e) => Error(e)
      }
    | Error(e) => Error(e)
    };
});

let fail = b => Error(b);
let ok = t =>
  switch (t) {
  | Ok(x) => Some(x)
  | Error(_) => None
  };
let ok_exn = (t: t('a, Js.Exn.t)) =>
  switch (t) {
  | Ok(x) => x
  | Error(e) => raise(Obj.magic(e))
  };
let err = t =>
  switch (t) {
  | Ok(_) => None
  | Error(e) => Some(e)
  };

let map_error = (t, ~f) =>
  switch (t) {
  | Ok(x) => Ok(x)
  | Error(e) => Error(f(e))
  };
