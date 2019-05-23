open Tc;

let message = __MODULE__;

module ControlCodaResponse = {
  // Ok(true) = started
  // Ok(false) = stopped
  // Error = Failed to perform action
  type t = Result.t(string, bool);
};

module Typ = {
  type t('a) =
    | ControlCodaResponse: t(ControlCodaResponse.t)
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
    | (ControlCodaResponse, ControlCodaResponse) => is_equal(v)
    | (_, ControlCodaResponse) => not_equal(v)
    | (Unit, Unit) => is_equal(v)
    | (_, Unit) => not_equal(v)
    };
  };
};
module CallTable = CallTable.Make(Typ);

type mainToRendererMessages = [
  | `Respond_new_settings(CallTable.Ident.Encode.t, unit)
  | `Deep_link(/*Route.t*/ string)
  | `Respond_control_coda(CallTable.Ident.Encode.t, ControlCodaResponse.t)
];

type rendererToMainMessages = [
  | `Set_name(PublicKey.t, string, CallTable.Ident.Encode.t)
    // None = stop
    // Some(args) = spawn args
  | `Control_coda_daemon(option(list(string)), CallTable.Ident.Encode.t)
];
