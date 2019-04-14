open BsElectron;
open Tc;

include IpcRenderer.MakeIpcRenderer(Messages);

let callTable = CallTable.make();

let setName = (key, name) => {
  let pending = CallTable.nextPending(callTable);
  send(`Set_name((key, name, pending.ident)));
  pending.task;
};

let listen = () =>
  on((. _event, message) =>
    switch (message) {
    | `Respond(ident) => CallTable.resolve(callTable, ident)
    | `Deep_link(routeString) =>
      Router.navigate(Route.parse(routeString) |> Option.getExn)
    }
  );
