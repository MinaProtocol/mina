[@react.component]
let make = (~src, ~className=?, ~alt) =>
  <img
    ?className
    alt
    src={
      "http://images.ctfassets.net/"
      ++ Contentful.spaceID
      ++ "/"
      ++ Contentful.imageAPIToken
      ++ "/"
      ++ src
      ++ "?fm=jpg&fl=progressive"
    }
  />;
