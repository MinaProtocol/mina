module Hero = {
  module Styles = {
    open Css;
  };
  [@react.component]
  let make = () => {
    <div>
      <h4> {React.string("Page Label")} </h4>
      <h1> {React.string("Page Title")} </h1>
      <p>
        {React.string(
           "Lorem ipsum dolor sit amet, consec tetur adipiscing elit, sed do eiusmod tempor incididunt ut labore.",
         )}
      </p>
      <Button bgColor=Theme.Colors.black>
        {React.string("Button label")}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
      <PromoButton bgColor=Theme.Colors.orange>
        <Icon kind=Icon.Documentation size=2.5 />
        <span className=Demo.Styles.documentationButton>
          {React.string("Go To Documentation")}
        </span>
      </PromoButton>
    </div>;
  };
};

// TODO: Change title
[@react.component]
let make = () => {
  <Page title="Coda Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <Hero />
  </Page>;
};
