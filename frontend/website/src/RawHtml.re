let component = ReasonReact.statelessComponent("RawHtml");

let make = (~path, _) => {
  let html = Node.Fs.readFileAsUtf8Sync(path);
  {
    ...component,
    render: _self => {
      Css.(global("strong", [fontWeight(`num(800)), color(black)]));
      <Wrapped>
        <div
          className=Css.(
            style([
              Style.Typeface.ibmplexsans,
              color(Style.Colors.metallicBlue),
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
    },
  };
};