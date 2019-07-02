open BsElectron;

include IpcRenderer.MakeIpcRenderer(Messages);

let controlCodaDaemon = maybeArgs => {
  send(`Control_coda_daemon(maybeArgs));
};

module ListenToken = {
  type t = messageCallback(Messages.mainToRendererMessages);
};

let listen = () => {
  let cb =
    (. _event, message: Messages.mainToRendererMessages) =>
      switch (message) {
      | `Coda_crashed(_error) => ()
      // TODO: Push the error into some sort of context/model that triggers a re-render as necessary
      | `Deep_link(routeString) => ReasonReact.Router.push(routeString)
      };
  on(cb);
  cb;
};

let stopListening: ListenToken.t => unit = removeListener;
