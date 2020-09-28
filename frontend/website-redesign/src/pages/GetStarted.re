[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title="Get Started"
      header="Mina makes it simple."
      copy={
        Some(
          "Interested and ready to take the next step? You're in the right place.",
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/04_GetStarted_1_2880x1504.jpg",
        Theme.tablet: "/static/img/backgrounds/04_GetStarted_1_1536x1504_tablet.jpg",
        Theme.mobile: "/static/img/backgrounds04_GetStarted_1_750x1056_mobile.jpg",
      }
    />
  </Page>;
};
