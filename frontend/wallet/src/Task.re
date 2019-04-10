type t_(+'a) = unit => Js.Promise.t('a);

let ignore_ = ignore;

include Monad.Make({
  type nonrec t(+'a) = t_('a);
  let return: 'a => t('a) = (x, ()) => Js.Promise.resolve(x);
  let map = `Define_using_bind;
  let bind: (t('a), ~f: 'a => t('b)) => t('b) =
    (t, ~f, ()) => {
      Js.Promise.then_(a => f(a, ()), t());
    };
  let all_array =
    `Custom((ts, ()) => Js.Promise.all(Array.map(t => t(), ts)));
});

let create: (('a => unit) => unit) => t('a) =
  (cb, ()) => {
    Js.Promise.make((~resolve, ~reject as _) => cb(a => resolve(. a)));
  };

let never: t('a) = create(ignore_);

let any: array(t('a)) => t('a) =
  (ts, ()) => {
    Js.Promise.race(Array.map(t => t(), ts));
  };

let fork = (t, ~f) => {
  let cb = {
    let fresh = ref(true);
    r => {
      fresh^ ? f(r) : ();
      fresh := false;
    };
  };

  // we're running the promise for it's effects
  let _ =
    t()
    |> Js.Promise.then_(a => Js.Promise.resolve(Some(a)))
    |> Js.Promise.catch(err => {
         cb(Result.fail(Obj.magic(err)));
         Js.Promise.resolve(None);
       })
    |> Js.Promise.then_(a =>
         switch (a) {
         | None => Js.Promise.resolve()
         | Some(a) => Js.Promise.resolve(cb(Result.return(a)))
         }
       );

  ();
};

module Result = {
  type t0('a, 'err) = t(Result.t('a, 'err));

  include Monad.Make2({
    type t('a, 'err) = t0('a, 'err);

    let map = `Define_using_bind;

    let bind: (t('a, 'c), ~f: 'a => t('b, 'c)) => t('b, 'c) =
      (t, ~f) => {
        bind(t, ~f=res =>
          switch (res) {
          | Result.Ok(x) => f(x)
          | Result.Error(e) => return(Result.Error(e))
          }
        );
      };

    let return = x => return(Result.return(x));
  });

  let uncallbackify0 = f => {
    create(cb =>
      f(err =>
        switch (Js.Nullable.toOption(err)) {
        | Some(err) => cb(Result.fail(err))
        | None => cb(Result.return())
        }
      )
    );
  };

  let uncallbackify = f => {
    create(cb =>
      f((err, x) =>
        switch (Js.Nullable.toOption(err), Js.Nullable.toOption(x)) {
        | (Some(err), _) => cb(Result.fail(err))
        | (_, Some(x)) => cb(Result.return(x))
        | (_, _) => failwith("The JS call you've bridged is funky")
        }
      )
    );
  };
};
