let component = ReasonReact.statelessComponent("CryptoAppsSection");
let make = (~className, ~name, _children) => {
  ...component,
  render: _self => {
    <img
      className
      src={name ++ ".png"}
      srcSet={
        name ++ ".png 1x, " ++ name ++ "@2x.png 2x, " ++ name ++ "@3x.png 3x"
      }
    />;
  },
};
