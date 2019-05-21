open BsElectron;
open Tc;

include BrowserWindow.MakeBrowserWindow(Messages);

module Input = {
  type t = {
    path: Route.t,
    dispatch: Application.Action.t => unit,
  };
};

include Single.Make({
  type input = Input.t;

  type t = BrowserWindow.t;

  let listen = (t, dispatch) => {
    let cb =
      (. _event, message) =>
        switch (message) {
        | `Set_name(key, name, pendingIdent) =>
          dispatch(Application.Action.SettingsUpdate((key, name)));
          send(t, `Respond_new_settings((pendingIdent, ())));
        };
    RendererCommunication.on(cb);
    cb;
  };

  let make: (~drop: unit => unit, input) => t =
    (~drop, input) => {
      let window =
        make(
          makeWindowConfig(
            ~width=960,
            ~height=610,
            ~minWidth=800,
            ~minHeight=500,
            ~frame=false,
            ~fullscreenable=false,
            ~resizeable=false,
            ~title="Coda Wallet",
            ~titleBarStyle=`Hidden,
            ~backgroundColor=Theme.Colors.bgColorElectronWindow,
            ~webPreferences=
              makeWebPreferences(
                ~preload=
                  Filename.concat(
                    [%bs.node __dirname] |> Option.getExn |> Filename.dirname,
                    "render/Preload.js",
                  ),
                ~nodeIntegration=true,
                (),
              ),
            (),
          ),
        );

      let indexURL =
        "file://"
        ++ Filename.concat(ProjectRoot.resource, "public/index.html")
        ++ "?settingsPath="
        ++ Js.Global.encodeURI(ProjectRoot.settings)
        ++ "#"
        ++ Route.print(input.path);
      loadURL(window, indexURL);

      let listener = listen(window, input.dispatch);
      on(
        window,
        `Closed,
        () => {
          RendererCommunication.removeListener(listener);
          drop();
        },
      );

      // Watches the bundle to reload the window on changes
      Bindings.Fs.watchFile(
        Filename.concat(ProjectRoot.resource, "bundle/index.js"), () =>
        loadURL(window, indexURL)
      );

      window;
    };
});

let deepLink = input => {
  let w = get(input);
  // route handling is idempotent so doesn't matter if we also send the message
  // if window already exists
  send(w, `Deep_link(Route.print(input.path)));
  ();
};
