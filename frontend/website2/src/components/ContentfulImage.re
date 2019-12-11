[@react.component]
let make = (~src, ~className=?, ~alt) =>
  <img
    ?className
    alt
    src={
      "http://images.ctfassets.net/"
      ++ Contentful.spaceID
      ++ "/"
      ++ Next.Config.contentful_image_token
      ++ "/"
      ++ src
      ++ "?fm=jpg&fl=progressive"
    }
  />;
