type state = {press: array(ContentType.Press.entries)};

let fetchPress = () => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 0,
      "content_type": ContentType.Press.id,
      "order": "-fields.date",
    },
  )
  |> Promise.map((entries: ContentType.Press.entries) => {
       Array.map((e: ContentType.Press.entry) => e.fields, entries.items)
     });
};

module Styles = {
  open Css;

  let container = style([margin2(~v=`rem(7.), ~h=`zero)]);

  let header =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
      marginBottom(`rem(3.)),
    ]);
};

module Title = {
  [@react.component]
  let make = (~copy, ~buttonCopy, ~buttonHref) => {
    <div className=Styles.header>
      <h2 className=Theme.Type.h2> {React.string(copy)} </h2>
      <Button bgColor=Theme.Colors.digitalBlack href=buttonHref>
        {React.string(buttonCopy)}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
    </div>;
  };
};

[@react.component]
let make = () => {
  let (press, setPress) = React.useState(_ => [||]);

  React.useEffect0(() => {
    fetchPress() |> Promise.iter(blogs => setPress(_ => blogs));
    None;
  });

  <div className=Styles.container>
    <Wrapped>
      <Title
        copy="In the News"
        buttonCopy="See All Press"
        buttonHref="/blog"
      />
    </Wrapped>
    <PressListModule press mainImg="/static/img/ArticleImage.png" />
  </div>;
};
