let component = ReasonReact.statelessComponent("RawHtml");

let make = (~path, _) => {
  let html = Node.Fs.readFileAsUtf8Sync(path);
  Css.(global("strong", [fontWeight(`num(800)), color(black)]));
  {
    ...component,
    render: _self =>
      <div
        className="section-wrapper ibmplex blueblack lh-copy mw7-ns center f5 mt4 tl"
        dangerouslySetInnerHTML={"__html": html}
      />,
  };
};
