module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      display(`flex),
      width(`rem(50.)),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignContent(`spaceAround),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(68.))]),
    ]);
};

[@react.component]
let make = () => {
  <Page title="Demo page of components">
    <div className=Styles.page>
      <Button bgColor=Theme.Colors.orange>
        {React.string("Button orange on light background")}
        <svg
          width="16"
          height="16"
          viewBox="0 0 16 16"
          fill="none"
          xmlns="http://www.w3.org/2000/svg">
          <rect x="3" y="7" width="10" height="1" fill="white" />
          <rect x="11" y="6" width="1" height="1" fill="white" />
          <rect x="10" y="5" width="1" height="1" fill="white" />
          <rect x="9" y="4" width="1" height="1" fill="white" />
          <rect x="10" y="9" width="1" height="1" fill="white" />
          <rect x="9" y="10" width="1" height="1" fill="white" />
          <rect x="11" y="8" width="1" height="1" fill="white" />
        </svg>
      </Button>
      <Button bgColor=Theme.Colors.mint>
        {React.string("Button mint on light background")}
      </Button>
      <Button bgColor=Theme.Colors.black>
        {React.string("Button black on light background")}
      </Button>
      <Button bgColor=Theme.Colors.white>
        {React.string("Button white on light background")}
      </Button>
      <h1 className=Theme.Type.h1jumbo> {React.string("H1 Jumbo")} </h1>
      <h1 className=Theme.Type.h1> {React.string("H1")} </h1>
      <h2 className=Theme.Type.h2> {React.string("H2")} </h2>
      <h3 className=Theme.Type.h3> {React.string("H3")} </h3>
      <h4 className=Theme.Type.h4> {React.string("H4")} </h4>
      <h5 className=Theme.Type.h4> {React.string("H5")} </h5>
      <h6 className=Theme.Type.h4> {React.string("H6")} </h6>
      <div className=Theme.Type.pageLabel> {React.string("Page label")} </div>
      <div className=Theme.Type.label> {React.string("Label")} </div>
      <div className=Theme.Type.buttonLabel>
        {React.string("Button label")}
      </div>
      <a className=Theme.Type.link> {React.string("Link")} </a>
      <a className=Theme.Type.navLink> {React.string("Nav Link")} </a>
      <a className=Theme.Type.sidebarLink> {React.string("Sidebar Link")} </a>
      <div className=Theme.Type.tooltip> {React.string("Tooltip")} </div>
      <div className=Theme.Type.creditName>
        {React.string("Credit name")}
      </div>
      <div className=Theme.Type.metadata> {React.string("Metadata")} </div>
      <div className=Theme.Type.announcement>
        {React.string("Announcement")}
      </div>
      <div className=Theme.Type.errorMessage>
        {React.string("Error message")}
      </div>
      <div className=Theme.Type.pageSubhead>
        {React.string(
           "Page subhead / Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod temporus incididunt ut labore et dolore.",
         )}
      </div>
      <div className=Theme.Type.sectionSubhead>
        {React.string(
           "Section Subhead / Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod temporus incididunt ut labore et.",
         )}
      </div>
      <p className=Theme.Type.paragraph>
        {React.string(
           "Paragraph (Grotesk) / Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
         )}
      </p>
      <p className=Theme.Type.paragraphSmall>
        {React.string(
           "Paragraph Small (Grotesk) / Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
         )}
      </p>
      <p className=Theme.Type.paragraphMono>
        {React.string(
           "Paragraph (Mono) / Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmodorus temporus incididunt ut labore et dolore.",
         )}
      </p>
      <p className=Theme.Type.quote>
        {React.string(
           "Quote / Lorem ipsum dolor sit amet, consectetur amet adipiscing elit, sed do eiusmod tempor.",
         )}
      </p>
    </div>
  </Page>;
};
