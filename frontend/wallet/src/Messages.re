let message = __MODULE__;

type mainToRendererMessages = [
  | `Respond(CallTable.Ident.t)
  | `Deep_link(/*Route.t*/ string)
];

type rendererToMainMessages = [
  | `Set_name(PublicKey.t, string, CallTable.Ident.t)
];
