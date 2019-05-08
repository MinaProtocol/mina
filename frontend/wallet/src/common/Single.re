/// "singleton"-like functionality that can also be dropped whenever the
/// `~drop` callback is invoked.

module Make =
       (
         T: {
           // Since the input type will typically contain something that is
           // capturing a failure (i.e. a `Result.t('x, 'a)`), and given that we
           // wish to capture errors using polymorphic variants (see
           // https://keleshev.com/composable-error-handling-in-ocaml for
           // rationale):
           //
           // We need to be polymphoric over the subtype of some row of errors:
           // i.e.
           //   ```
           //   [> | `Decode_failed]
           //   ```
           //   should unify with both
           //   ```
           //   [| `Decode_failed]
           //   ```
           //   and
           //   ```
           //   [| `Decode_failed | `Json_parse_error]
           //   ```
           //
           // Counterintuitively, note that "at least A" is a supertype of
           // "at least A or B" (think about it like: "at least A or B" is more
           // restrictive than "at least A".
           //
           // The pattern: `'a constraint 'a = [> ]` tells reason that `'a` is
           // used to quantify over rows of variants rather than the typical
           // type variable.
           type input('a) constraint 'a = [> ];
           type t;
           let make: (~drop: unit => unit, input('a)) => t;
         },
       ) => {
  let cache: ref(option(T.t)) = ref(None);

  let get = input => {
    switch (cache^) {
    | Some(w) => w
    | None =>
      let res = T.make(~drop=() => cache := None, input);
      cache := Some(res);
      res;
    };
  };
};
