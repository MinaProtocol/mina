open Tc;

module Make:
  (
    Typ: {
      type t('a);
      let if_eq:
        (t('a), t('b), 'b, ~is_equal: 'a => unit, ~not_equal: 'b => unit) =>
        unit;
    },
  ) =>
   {
    module Ident: {
      type t('a);

      module Encode: {
        type t0('a) = t('a);
        type t;
        let t: t0('a) => t;
      };

      module Decode: {let t: (Encode.t, Typ.t('a)) => t('a);};
    };

    module Pending: {
      type t('x, 'a) = {
        ident: Ident.t('a),
        task: Task.t('x, 'a),
      };
    };

    type t;

    let make: unit => t;
    let nextPending: (t, Typ.t('a), ~loc: string) => Pending.t('x, 'a);
    let resolve: (t, Ident.t('a), 'a) => unit;
  };
