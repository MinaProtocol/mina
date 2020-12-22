fetch("graph.json")
  .then(response => response.json())
  .then(json => {
    /*
    <script type='text/javascript' src='https://cytoscape.org/cytoscape.js-spread/cytoscape-spread.js'></script>
    const nodes = new vis.DataSet(json.nodes);
    const edges = new vis.DataSet(json.edges);
    const data = {
      nodes: nodes,
      edges: edges,
    };
    const options = {};
    const network = new vis.Network(container, data, options);
    window.obj = json;
    window.network = network; */

    const nodes = json.nodes.map(x => {
      return { data: { id: x.id, label: x.id } };
    });

    let i = 0;

    const stateEdges = json.edges;
    const edges = stateEdges.map(e => {
      return {
        data: { id: i++, source: e.from, target: e.to }
      };
    });

    const container = document.getElementById("network");
    const cy = cytoscape({
      container: container,
      elements: {
        nodes: nodes,
        edges: edges,
      },
      layout: {
        name: 'euler',
        randomize: true,
        animate: true 
        /*
        layout: 'random'
        */
      },
      style: [
        /*
        {
          selector: 'node',
          style: {
            // 'content': 'data(name)',
            'background-color': '#126814'
          }
        }, */
        {
          'selector': 'node',
          'style': {
            'label': 'data(label)',
            'text-valign': 'bottom',
            'text-halign': 'center'
          }
        },
        {
          selector: 'edge',
          style: {
            'line-color': '#126814',
            'opacity': 0.5
          }
        },
      ],
    });

    const stateHashes = Object.keys(json.edges_by_state_hash);

    window.setGraph = (stateHash) => {
      let i = 0;

      const nodes = json.nodes.map(x => {
        return { data: { id: x.id, label: x.id } };
      });
      const stateEdges = json.edges_by_state_hash[stateHash];
      const edges = stateEdges.map(e => {
        return {
          data: { id: i++, source: e.from, target: e.to }
        };
      });
      container.innerHTML = '';
      const cy = cytoscape({
        container: container,
        elements: {
          nodes: nodes,
          edges: edges,
        },
        layout: {
          name: 'euler',
          randomize: true,
          animate: true 
          /*
          layout: 'random'
          */
        },
        style: [
          /*
          {
            selector: 'node',
            style: {
              // 'content': 'data(name)',
              'background-color': '#126814'
            }
          }, */
          {
            'selector': 'node',
            'style': {
              'label': 'data(label)',
              'text-valign': 'bottom',
              'text-halign': 'center'
            }
          },
          {
            selector: 'edge',
            style: {
              'line-color': '#126814',
              'opacity': 0.5
            }
          },
        ],
      });
    };

    let nextIdx = 0; 
    window.advanceGraph = () => {
      console.log("displaying for " + stateHashes[nextIdx]);
      setGraph(stateHashes[nextIdx]);
      nextIdx = (nextIdx + 1) % stateHashes.length;
    };
  });
