let legacyStylesheets =
  <>
    <link
      rel="stylesheet"
      type_="text/css"
      href="https://fonts.googleapis.com/css?family=Rubik:500"
    />
    <link
      rel="stylesheet"
      type_="text/css"
      href="https://fonts.googleapis.com/css?family=Alegreya+Sans:300,300i,400,400i,500,500i,700,700i,800,800i,900,900i"
    />
    <link
      rel="stylesheet"
      href="https://use.fontawesome.com/releases/v5.0.12/css/all.css"
      integrity="sha384-G0fIWCsCzJIMAVNQPfjH08cyYaUtMwjJwqiRKxxE/rx96Uroj1BtIQ6MLJuheaO9"
      crossOrigin="anonymous"
    />
    <link rel="stylesheet" type_="text/css" href="/static/css/common.css" />
  </>;

let component = ReasonReact.statelessComponent("Header");
let make = (~extra, ~filename, _children) => {
  ...component,
  render: _self =>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta
        property="og:image"
        content="https://codaprotocol.com/static/img/compare-outlined-png.png"
      />
      <meta property="og:updated_time" content="1526001445" />
      <meta property="og:type" content="website" />
      <meta property="og:url" content="https://codaprotocol.com" />
      <meta property="og:title" content="Coda Cryptocurrency Protocol" />
      <meta
        property="og:description"
        content="That means that no matter how many transactions are performed, verifying the blockchain remains inexpensive and accessible to everyone."
      />
      <meta
        name="description"
        content="That means that no matter how many transactions are performed, verifying the blockchain remains inexpensive and accessible to everyone."
      />
      extra
      <title> {ReasonReact.string("Coda Cryptocurrency Protocol")} </title>
      <link
        rel="stylesheet"
        type_="text/css"
        href="/static/css/normalize.css"
      />
      <link rel="stylesheet" type_="text/css" href={filename ++ ".css"} />
      <link
        rel="icon"
        type_="image/png"
        href="/static/favicon-32x32.png"
        sizes="32x32"
      />
      <link
        rel="icon"
        type_="image/png"
        href="/static/favicon-16x16.png"
        sizes="16x16"
      />
      <script
        src="https://www.googletagmanager.com/gtag/js?id=UA-115553548-2"
      />
      <RunScript>
        {|
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'UA-115553548-2');
  var _gaq = document._gaq || [];

  document.addEventListener("DOMContentLoaded", function() {
    Array.from(document.getElementsByTagName('a')).forEach(e => {
      if (e.name != "") e.onclick = (event) => {
          _gaq.push(['_trackEvent', 'coda', 'click', e.name, '0']);
      }
    })
  });
|}
      </RunScript>
      // HACK: Force ibm plex fonts on all the pages
      <style
        dangerouslySetInnerHTML={
          "__html": {|
@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 400;
  src: url("/static/font/IBMPlexSans-Regular-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Regular-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}

@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 500;
  src: url("/static/font/IBMPlexSans-Medium-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Medium-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}

@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 600;
  src: url("/static/font/IBMPlexSans-SemiBold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-SemiBold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}
@font-face {
  font-family: 'IBM Plex Sans';
  font-style: normal;
  font-weight: 700;
  src: url("/static/font/IBMPlexSans-Bold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Bold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02; }

@font-face {
  font-family: 'IBM Plex Mono';
  font-style: normal;
  font-weight: 600;
  src: url("/static/font/IBMPlexMono-SemiBold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexMono-SemiBold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02; }

@font-face {
  font-family: 'IBM Plex Italic';
  font-style: italic;
  font-weight: 400;
  src: url("/static/font/IBMPlexSans-Italic-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexSans-Italic-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02;
}

@font-face {
  font-family: 'IBM Plex Mono';
  font-style: normal;
  font-weight: 600;
  src: url("/static/font/IBMPlexMono-SemiBold-Latin1.woff2") format("woff2"),
    url("/static/font/IBMPlexMono-SemiBold-Latin1.woff") format("woff");
  unicode-range: U+0000, U+000D, U+0020-007E, U+00A0-00A3, U+00A4-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2013-2014, U+2018-201A, U+201C-201E, U+2020-2022, U+2026, U+2030, U+2039-203A, U+2044, U+2074, U+20AC, U+2122, U+2212, U+FB01-FB02; }

|},
        }
      />
    </head>,
};
