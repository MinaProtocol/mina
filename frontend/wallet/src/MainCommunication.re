open BsElectron;
open Tc;

include IpcRenderer.MakeIpcRenderer(Messages);

module CallTable = Messages.CallTable;

let callTable = CallTable.make();

let setName = (key, name) => {
  let pending =
    CallTable.nextPending(
      callTable,
      Messages.Typ.SettingsOrError,
      ~loc=__LOC__,
    );
  send(`Set_name((key, name, CallTable.Ident.Encode.t(pending.ident))));
  pending.task;
};

module ListenToken = {
  type t = messageCallback(Messages.mainToRendererMessages);
};

let listen = () => {
  let cb =
    (. _event, message: Messages.mainToRendererMessages) =>
      switch (message) {
      | `Respond_new_settings(ident, settingsOrErrorJson) =>
        let settingsOrError =
          Route.SettingsOrError.Decode.t(
            Js.Json.parseExn(settingsOrErrorJson),
          );
        CallTable.resolve(
          callTable,
          CallTable.Ident.Decode.t(ident, Messages.Typ.SettingsOrError),
          settingsOrError,
        );
      | `Deep_link(routeString) =>
        Router.navigate(Route.parse(routeString) |> Option.getExn)
      };
  on(cb);
  cb;
};

let stopListening: ListenToken.t => unit = removeListener;
