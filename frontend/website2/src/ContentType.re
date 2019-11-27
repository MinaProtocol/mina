// IDs
let post = "test";

type sys = {
  id: string,
  createdAt: string,
  updatedAt: string,
};

type entry('a) = {
  sys,
  fields: 'a,
};
type entries('a) = {items: array(entry('a))};

type post = {
  title: string,
  slug: string,
  subtitle: Js.Undefined.t(string),
  author: string,
  authorWebsite: Js.Undefined.t(string),
  date: string,
  text: string,
};
