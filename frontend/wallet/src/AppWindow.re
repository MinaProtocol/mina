open BsElectron;

include BrowserWindow.MakeBrowserWindow(Messages);

include Single.Make({
  type input = Route.t;
  type t = BrowserWindow.t;

  let make: (~drop: unit => unit, input) => t =
    (~drop, route) => {
      let window =
        make(
          makeWindowConfig(
            ~transparent=true,
            ~width=880,
            ~height=500,
            ~frame=false,
            ~fullscreenable=false,
            ~resizeable=false,
            ~title="Coda Wallet",
            ~backgroundColor=
              "#DD" ++ StyleGuide.Colors.(hexToString(bgColor)),
            (),
          ),
        );
      loadURL(
        window,
        "file://"
        ++ ProjectRoot.path
        ++ "public/index.html#"
        ++ Route.print(route),
      );
      on(window, `Closed, drop);
      window;
    };
});

let deepLink = route => {
  let w = get(route);
  // route handling is idempotent so doesn't matter if we also send the message
  // if window already exists
  send(w, `Deep_link(route));
  ();
};
