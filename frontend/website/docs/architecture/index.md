# Coda Protocol Architecture

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
