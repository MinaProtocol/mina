[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title=""
      header="Press & Media."
      copy={
        Some(
          "Light. Accessible. Decentralized. SNARKy. Mina is a whole new kind of blockchain.",
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/15_PressAndMedia_1_2880x1504.jpg",
        Theme.tablet: "/static/img/backgrounds/15_PressAndMedia_1_1536x1504_tablet.jpg",
        Theme.mobile: "/static/img/backgrounds/15_PressandMedia_1_750x1056_mobile.jpg",
      }
    />
  </Page>;
};
