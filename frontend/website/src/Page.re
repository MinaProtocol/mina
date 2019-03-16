// TODO: Improve this later
module Header = LegacyPage.Header;
module Footer = LegacyPage.Footer;

module Wrapped = {
  module Style = {
    open Css;
    open Style;

    let s =
      style(
        paddingX(`rem(1.25))
        @ [
          margin(`auto),
          media(
            MediaQuery.full,
            [
              maxWidth(`rem(84.0)),
              margin(`auto),
              ...paddingX(`rem(2.0)),
            ],
          ),
        ],
      );
  };

  let component = ReasonReact.statelessComponent("Page.Wrapped");
  let make = children => {
    ...component,
    render: _ => {
      <div className=Style.s> ...children </div>;
    },
  };
};

let component = ReasonReact.statelessComponent("Page");
let make = (~name, ~extraHeaders=ReasonReact.null, ~footerColor="", children) => {
  ...component,
  render: _ =>
    <html>
      <Header filename=name extra=extraHeaders />
      <body>
        <Wrapped>
          <Nav>
            <a> {ReasonReact.string("Blog")} </a>
            <a> {ReasonReact.string("Testnet")} </a>
            <a> {ReasonReact.string("Github")} </a>
            <a> {ReasonReact.string("Careers")} </a>
            <a> {ReasonReact.string("Sign Up")} </a>
          </Nav>
          <div> ...children </div>
          <Footer color=footerColor />
        </Wrapped>
      </body>
    </html>,
};
