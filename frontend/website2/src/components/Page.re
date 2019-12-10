[@react.component]
let make = (~children) => {
  <>
    <Nav />
    <Next.Head>
      <link
        href="https://fonts.googleapis.com/css?family=IBM+Plex+Sans:300,400,500,700&display=swap"
        rel="stylesheet"
      />
    </Next.Head>
    <div className="body"> children </div>
  </>;
};
