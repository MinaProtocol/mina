open BsElectron;

include Single.Make({
  // Since we don't care about input our row constraint here,
  type input('a) = unit constraint 'a = [> ];
  type t = Tray.t;

  let make: (~drop: unit => unit, unit) => t =
    (~drop as _, ()) => {
      Tray.make(Filename.concat(ProjectRoot.resource, "public/icon.png"));
    };
});
