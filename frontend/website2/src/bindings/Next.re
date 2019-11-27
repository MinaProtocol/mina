module Link = {
  [@bs.module "next/link"] [@react.component]
  external make:
    (
      ~href: string=?,
      ~_as: string=?,
      ~prefetch: option(bool)=?,
      ~replace: option(bool)=?,
      ~shallow: option(bool)=?,
      ~passHref: option(bool)=?,
      ~children: React.element
    ) =>
    React.element =
    "default";
};

module Head = {
  [@bs.module "next/head"] [@react.component]
  external make: (~children: React.element) => React.element = "default";
};

module Router = {
  type t('a) = {query: Js.Dict.t('a)};

  [@bs.module "next/router"] [@bs.val]
  external useRouter: unit => t('a) = "useRouter";
};

type config = {
  publicRuntimeConfig: Js.Dict.t(string),
  serverRuntimeConfig: Js.Dict.t(string),
};

[@bs.module "next/config"] [@bs.val]
external getConfig: unit => config = "default";

type getInitialPropsArgs = {
  pathname: string,
  query: Js.Dict.t(string),
  asPath: string,
};

let injectGetInitialProps:
  (
    Js.t('props) => React.element,
    getInitialPropsArgs => Js.Promise.t(Js.t('props))
  ) =>
  unit =
  (element, getInitialProps) => {
    Obj.magic(element)##getInitialProps #= getInitialProps;
  };
