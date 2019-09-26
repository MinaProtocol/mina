[@react.component]
let make = (~path) => {
  let html = Node.Fs.readFileAsUtf8Sync(path);
  Css.(global("strong", [fontWeight(`num(800)), color(black)]));
  <Wrapped>
    <div
      className=Css.(
        style([
          Style.Typeface.ibmplexsans,
          color(Style.Colors.saville),
          lineHeight(`em(1.5)),
          maxWidth(`rem(48.0)),
          marginLeft(`auto),
          marginRight(`auto),
          marginTop(`rem(2.0)),
        ])
      )
      dangerouslySetInnerHTML={"__html": html}
    />
  </Wrapped>;
};
