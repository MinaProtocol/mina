[@react.component]
let make = (~className, ~name, ~alt) => {
  <img
    className
    src={name ++ ".png"}
    srcSet={
      (name ++ ".png")
      ++ " 1x, "
      ++ (name ++ "@2x.png")
      ++ " 2x, "
      ++ (name ++ "@3x.png")
      ++ " 3x"
    }
    alt
  />;
};
