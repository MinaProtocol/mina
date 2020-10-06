[@react.component]
let make = (~statusCode="404") => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      header={statusCode ++ " error"}
      copy={
        Some(
          "This page is so decentralized, it doesn't exist. Let's bring you back to the world's lightest blockchain.",
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/404page.png",
        Theme.tablet: "/static/img/backgrounds/404page.png",
        Theme.mobile: "/static/img/backgrounds/404page.png",
      }>
      <Spacer height=1. />
      <Button
        href={`Internal("/")}
        width={`rem(6.9)}
        bgColor=Theme.Colors.mint
        borderColor=Theme.Colors.mint
        textColor=Theme.Colors.digitalBlack>
        {React.string("Home")}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
    </Hero>
  </Page>;
};
