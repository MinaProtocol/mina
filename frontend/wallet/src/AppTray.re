open BsElectron;

include Single.Make({
  type input = unit;
  type t = Tray.t;

  let make: (~drop: unit => unit, unit) => t =
    (~drop as _, ()) => {
      Tray.make(ProjectRoot.path ++ "public/icon.png");
    };
});
