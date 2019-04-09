open BsElectron;

include BrowserWindow.MakeBrowserWindow(Messages);

include Single.Make({
  type input = unit;
  type t = BrowserWindow.t;

  let make: (~drop: unit => unit, input) => t =
    (~drop, ()) => {
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
      loadURL(window, "file://" ++ ProjectRoot.path ++ "public/index.html");
      on(window, `Closed, drop);
      window;
    };
});
