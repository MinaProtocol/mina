# Website using NextJS and Contentful

First of all, make sure you have `git lfs` installed. 

On Mac run:

```bash
brew install git-lfs
```

After that you have to install `git-lfs` in the website directory and pull it.
```bash
git lfs install
git lfs pull
```

Install it and run:

```bash
npm install
npm run dev
# or
yarn
yarn dev
```

Build and run:

```bash
npm run build
npm run start
# or
yarn build
yarn start
```

### Recommendation:

Run BuckleScript build system `bsb -w` and `next -w` separately. For the sake
of simple convention, `npm run dev` run both `bsb` and `next` concurrently.
However, this doesn't offer the full [colorful and nice
error
output](https://reasonml.github.io/blog/2017/08/25/way-nicer-error-messages.html)
experience that ReasonML can offer, don't miss it!

There are 2 convenience scripts to facilitate running these separate processes:

1. `npm run dev:reason` - This script will start the ReasonML toolchain in
   watch mode to re-compile whenever you make changes.
2. `npm run dev:next` - This script will start the next.js development server
   so that you will be able to access your site at the location output by the
   script. This will also hot reload as you make changes.

You should start the scripts in the presented order.
