# Overview

## What is Coda?

Coda is the first cryptocurrency protocol with a succinct blockchain. Current cryptocurrencies like Bitcoin and Ethereum store hundreds of gigabytes of data, and as time goes on, their blockchains will only increase in size. With Coda however, no matter how much the usage grows, the blockchain always stays the same size - about ~20 kilobytes (the size of a few tweets).

This breakthrough is made possible due to zk-SNARKs - a type of succinct cryptographic proof. Each time a Coda node produces a new block, it also generates a SNARK proof verifying that the block was valid. All nodes in the network can then store just this proof moving forward, and don't need to worry about the raw block data. By not having to worry about block sizes, the Coda protocol enables vastly higher throughput in the network, and enables a blockchain that is decentralized at scale.

## How Does it Work?

Check out this short video explaining how the Coda protocol works in detail:

<iframe id="youtube-iframe" width="560" height="315" src="https://www.youtube-nocookie.com/embed/eWVGATxEB6M?start=100&enablejsapi=1&rel=0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

### Timestamps

- <a onClick="seekTo(110)">1:50 - What is Coda?</a>
- <a onClick="seekTo(160)">2:40 - Current cryptocurrency landscape</a>
- <a onClick="seekTo(233)">3:53 - The life of a full node</a>
- <a onClick="seekTo(369)">6:09 - The root problem - the verification mechanism</a>
- <a onClick="seekTo(448)">7:28 - Toward a solution</a>
- <a onClick="seekTo(525)">8:45 - zk-SNARks: Unforgeable certificates</a>
- <a onClick="seekTo(931)">15:31 - Recursive composition of SNARKs</a>
- <a onClick="seekTo(1130)">18:50 - Upshots: decentralization & scalability</a>
- <a onClick="seekTo(1245)">20:45 - Conclusion</a>
- <a onClick="seekTo(1280)">21:20 - Q&A</a>

## Try Coda

Trying out Coda is simple - head over to the [Getting Started page](/docs/getting-started/) to install the Coda client and join the network.

You can also sign up for the public testnet [here](https://bit.ly/TestnetForm).

<script>
      var player;
      function onYouTubeIframeAPIReady() {
        player = new YT.Player('youtube-iframe', {
          events: {
            'onError': onPlayerError,
          }
        });
      }
      
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

      function onPlayerError(event) {
        console.error("Error with Youtube player");
      }
      function seekTo(seconds) {
        player.seekTo(seconds);
      }
</script>
