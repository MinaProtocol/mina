const path = require('path');

const { createClient } = require('contentful');
const withTM = require('next-transpile-modules')
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
})

const SPACE = process.env.CONTENTFUL_SPACE || '37811siqosrn';
const TOKEN = process.env.CONTENTFUL_TOKEN || 'gONaARVCc0G5FLIkoJ2m4qi9yTpT8oi7u-C6VYxQ6UQ';
const IMAGE_TOKEN = process.env.CONTENTFUL_IMAGE_TOKEN || "3B4LS4VD0c4RCsUl1rxmmX/d8ba4bd5295e3b65569cbda1329e90a6";

const blogType = 'test';
const client = createClient({accessToken: TOKEN, space: SPACE});

module.exports = withTM(withBundleAnalyzer({
  async exportPathMap() {
    let blogPosts = await client.getEntries({ include: 0, content_type: blogType});

    let pages = {
      '/': { page: '/' },
      '/about': { page: '/about' },
      '/blog': { page: '/blog' },
      '/blog/': { page: '/blog' },
    };

    blogPosts.items.forEach(
      ({fields: {slug}}) => {
        pages['/blog/' + slug] = {page: '/blog/[slug]', query: {slug: slug}}
      });

    return pages;
  },
  pageExtensions: ['jsx', 'js'],
  transpileModules: ['bs-platform', 'bs-css', 'bsc-stdlib-polyfill'],
  webpack (config, options) {
    config.resolve.alias['@reason'] = path.join(__dirname, 'lib', 'es6', 'src');
    config.resolve.alias['@contentful'] = path.join(__dirname, 'contentfulData');
    config.resolve.extensions.push('.bs.js');
    return config
  },
  publicRuntimeConfig: {
    CONTENTFUL_TOKEN: TOKEN,
    CONTENTFUL_IMAGE_TOKEN: IMAGE_TOKEN,
    CONTENTFUL_SPACE: SPACE,
  }
}))
