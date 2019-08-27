[@react.component]
let make = (~className, ~name, ~alt) => {
  <img
    className
    src={Links.Cdn.url(name ++ ".png")}
    srcSet={
      Links.Cdn.url(name ++ ".png")
      ++ " 1x, "
      ++ Links.Cdn.url(name ++ "@2x.png")
      ++ " 2x, "
      ++ Links.Cdn.url(name ++ "@3x.png")
      ++ " 3x"
    }
    alt
  />;
};
