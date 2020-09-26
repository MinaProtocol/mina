[@react.component]
let make = () => {
  <Page title="Genesis Page">
    <Wrapped>
      <Hero
        title="Community"
        header="Genesis Program"
        background={Theme.desktop: "", Theme.tablet: "", Theme.mobile: ""}
        copy=Some("We're looking for community members to join the Genesis Token Grant Program and form the backbone of Mina's robust decentralized network.")>
        <Spacer height=2. />
        <Button bgColor=Theme.Colors.black>
          {React.string("Apply Now")}
          <Icon kind=Icon.ArrowRightMedium />
        </Button>
      </Hero>
    </Wrapped>
  </Page>;
};
