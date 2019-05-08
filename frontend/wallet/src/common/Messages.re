let message = __MODULE__;

module Typ = {
  type t('a) =
    | Unit: t(unit);

  let if_eq =
      (
        type a,
        type b,
        ta: t(a),
        tb: t(b),
        v: b,
        ~is_equal: a => unit,
        ~not_equal as _: b => unit,
      ) => {
    switch (ta, tb) {
    | (Unit, Unit) => is_equal(v)
    };
  };
};
module CallTable = CallTable.Make(Typ);

type mainToRendererMessages = [
  | `Respond_new_settings(CallTable.Ident.Encode.t, unit)
  | `Deep_link(/*Route.t*/ string)
];

type rendererToMainMessages = [
  | `Set_name(PublicKey.t, string, CallTable.Ident.Encode.t)
];
