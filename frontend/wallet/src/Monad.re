module type Basic = {
  type t(+'a);

  let return: 'a => t('a);
  let map: [
    | `Define_using_bind
    | `Custom((t('a), ~f: 'a => 'b) => t('b))
  ];
  /// Warning: This is O(n^2) if it's defined using bind
  let all_array: [
    | `Define_using_bind
    | `Custom(array(t('a)) => t(array('a)))
  ];
  let bind: (t('a), ~f: 'a => t('b)) => t('b);
};

module type Basic2 = {
  type t(+'a, 'b);

  let return: 'a => t('a, 'c);
  let map: [
    | `Define_using_bind
    | `Custom((t('a, 'c), ~f: 'a => 'b) => t('b, 'c))
  ];
  let bind: (t('a, 'c), ~f: 'a => t('b, 'c)) => t('b, 'c);
};

module type S = {
  type t(+'a);

  let return: 'a => t('a);
  let map: (t('a), ~f: 'a => 'b) => t('b);
  let bind: (t('a), ~f: 'a => t('b)) => t('b);

  let unit: t(unit);
  let ignore: t('a) => t(unit);
  /// Warning: This is O(n^2) if it's defined using bind
  let all_array: array(t('a)) => t(array('a));
  let all: list(t('a)) => t(list('a));
  let join: t(t('a)) => t('a);

  module Infix: {
    let (>>=): (t('a), 'a => t('b)) => t('b);
    let (>>|): (t('a), 'a => 'b) => t('b);
  };
};

module type S2 = {
  type t(+'a, 'c);

  let return: 'a => t('a, 'c);
  let map: (t('a, 'c), ~f: 'a => 'b) => t('b, 'c);
  let bind: (t('a, 'c), ~f: 'a => t('b, 'c)) => t('b, 'c);

  let ignore: t('a, 'c) => t(unit, 'c);
  /// Warning: This is O(n^2) if it's defined using bind
  let all_array: array(t('a, 'c)) => t(array('a), 'c);
  let all: list(t('a, 'c)) => t(list('a), 'c);
  let join: t(t('a, 'c), 'c) => t('a, 'c);

  module Infix: {
    let (>>=): (t('a, 'c), 'a => t('b, 'c)) => t('b, 'c);
    let (>>|): (t('a, 'c), 'a => 'b) => t('b, 'c);
  };
};

module Make = (M: Basic) : (S with type t('a) = M.t('a)) => {
  type t(+'a) = M.t('a);
  let return = M.return;
  let bind = M.bind;

  let map =
    switch (M.map) {
    | `Custom(f) => f
    | `Define_using_bind => ((t, ~f) => bind(t, ~f=x => return(f(x))))
    };

  let unit = return();
  let ignore = t => map(t, ~f=ignore);
  let all_array =
    switch (M.all_array) {
    | `Custom(f) => f
    | `Define_using_bind => (
        ts => {
          Array.fold_left(
            (tarr, t) =>
              bind(tarr, ~f=arr => map(t, ~f=x => Array.append(arr, [|x|]))),
            return([||]),
            ts,
          );
        }
      )
    };

  let all = ts => {
    List.fold_left(
      (tarr, t) => bind(tarr, ~f=arr => map(t, ~f=x => [x, ...arr])),
      return([]),
      List.rev(ts),
    );
  };

  let join = tt => bind(tt, ~f=x => x);

  module Infix = {
    let (>>=) = (t, f) => M.bind(t, ~f);
    let (>>|) = (t, f) => map(t, ~f);
  };
};

module Make2 = (M: Basic2) : (S2 with type t('a, 'b) = M.t('a, 'b)) => {
  type t(+'a, 'b) = M.t('a, 'b);
  let return = M.return;
  let bind = M.bind;

  let map =
    switch (M.map) {
    | `Custom(f) => f
    | `Define_using_bind => ((t, ~f) => bind(t, ~f=x => return(f(x))))
    };

  let unit = return();
  let ignore = t => map(t, ~f=ignore);
  let all_array = ts => {
    Array.fold_left(
      (tarr, t) =>
        bind(tarr, ~f=arr => map(t, ~f=x => Array.append(arr, [|x|]))),
      return([||]),
      ts,
    );
  };

  let all = ts => {
    List.fold_left(
      (tarr, t) => bind(tarr, ~f=arr => map(t, ~f=x => [x, ...arr])),
      return([]),
      List.rev(ts),
    );
  };

  let join = tt => bind(tt, ~f=x => x);

  module Infix = {
    let (>>=) = (t, f) => M.bind(t, ~f);
    let (>>|) = (t, f) => map(t, ~f);
  };
};
