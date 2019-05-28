let message = __MODULE__;

module Typ = {
  type t('a) =
    | String: t(string)
    | Unit: t(unit);

  let if_eq =
      (
        type a,
        type b,
        ta: t(a),
        tb: t(b),
        v: b,
        ~is_equal: a => unit,
        ~not_equal: b => unit,
      ) => {
    switch (ta, tb) {
    | (String, String) => is_equal(v)
    | (_, String) => not_equal(v)
    | (Unit, Unit) => is_equal(v)
    | (_, Unit) => not_equal(v)
    };
  };
};
module CallTable = CallTable.Make(Typ);

type mainToRendererMessages = [
  | `Deep_link(/*Route.t*/ string)
  | `Coda_crashed(/* error message */ string)
];

type rendererToMainMessages = [
  | `Control_coda_daemon // None = stop
                         // Some(args) = spawn args
(
      option(list(string)),
    )
];
