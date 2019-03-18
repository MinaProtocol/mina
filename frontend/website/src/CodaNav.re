module SimpleButton = {
  open Style;

  let component = ReasonReact.statelessComponent("CodaNav.SimpleButton");
  let make = (~name, ~link, _children) => {
    ...component,
    render: _self => {
      <a
        href=link
        className=Css.(
          merge([
            Body.style,
            style([textDecoration(`none), whiteSpace(`nowrap)]),
          ])
        )>
        {ReasonReact.string(name)}
      </a>;
    },
  };
};

let component = ReasonReact.statelessComponent("CodaNav");
let make = _children => {
  ...component,
  render: _self => {
    <Nav>
      <SimpleButton name="Blog" link="/blog.html" />
      <SimpleButton name="Testnet" link="/testnet.html" />
      <SimpleButton name="GitHub" link="/code.html" />
      <SimpleButton name="Careers" link="/jobs.html" />
      <SimpleButton
        name="Sign up"
        link="https://goo.gl/forms/PTusW11oYpLKJrZH3"
      />
    </Nav>;
  },
};
