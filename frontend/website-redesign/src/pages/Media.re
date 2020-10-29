[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title=""
      header={Some("Press & Media")}
      copy={
        Some(
          "Light. Accessible. Decentralized. SNARKy. Mina is a whole new kind of blockchain.",
        )
      }
      background={
        Theme.desktop: "/static/img/backgrounds/15_PressAndMedia_1_2880x1504.jpg",
        Theme.tablet: "/static/img/backgrounds/15_PressAndMedia_1_1536x1504_tablet.jpg",
        Theme.mobile: "/static/img/backgrounds/15_PressandMedia_1_750x1056_mobile.jpg",
      }>
      <Spacer height=1.5 />
      <Button
        href={
               `External(
                 "https://drive.google.com/file/d/177Xzj6Rqd9UnYwzRzMRLPKoyows-iwKx/view?usp=sharing",
               )
             }
        bgColor=Theme.Colors.black
        width={`rem(14.)}>
        {React.string("Download Media Kit")}
        <Icon kind=Icon.ArrowRightMedium size=1. />
      </Button>
    </Hero>
    <BlogModule source=`Press title="Featured Press" />
    <BlogModule
      source=`Announcement
      title="Mina Announcements"
      itemKind=ListModule.Announcement
      buttonHref={`Internal("/announcements")}
    />
  </Page>;
};
