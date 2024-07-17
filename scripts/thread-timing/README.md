# Thread Timing

Thread execution timing is provided by the [O1trace module](../../src/lib/o1trace). With it, the Mina daemon is instrumented in a hierarchical fashion, where there is one root through (called "Mina") under which there is a tree of descendant threads. As opposed to naive timing techniques which time the delay it takes for a thread to execute, this timing technique times the amount of time spent actually executing the thread in a way that allows us to generate dashboards showing the amount of time spent per second in various threads of the daemon.

Thread timings are inclusive of descendants. This means that, for a given thread A that has children B and C, the amount of time that is reported for the execution of A includes the exection time of B and C. Therefore, when reasoning about the actual time spent in A, but not in B or C, we need to subtract the execution of B and C to find the leftover time spent in A that wasn't in a child thread. This makes writing Grafana charts for thread timing annoying and brittle. Luckily, there are scripts which can be used to automate the generation of the Grafana charts.

## Generating Charts

Generating charts boils down to 3 steps.

1. Acquire a snapshot of thread hierarchy from a running daemon.
2. Execute the chart generating script, passing in the thread hierarchy captured in step 1, and specifying the options for the chart you want to generate.
3. Import the scripts JSON output into a Grafana chart.

### Acquiring thread heiarchy snapshots

Because O1trace does not have a PPX, the hierarchy of all the threads in the daemon are not known at compile time. Furthermore, different classes of daemons may have slightly different hierarchies of threads (eg. block producers and snark coordinators run additional subsystems that other nodes do not). Because of this, it is important to consider what node you actually want to take a thread snapshot from. In general, it usually works well to take thread hierarchy snapshots from block production nodes and generate dashboards from that for usage when investigating seeds and block producer nodes. For snark coordinators and archive nodes, it may be best to generate separate dashboards from their hierarchies in order to include their special subsystems in the charts.

The thread hierarchy can be dumped from a running daemon using the command `mina advanced thread-graph`. It is important to check that the node has finished bootstrap before dumping the thread hierarchy, as some threads will be missing until bootstrap has completed and we enter the participation phase.

### Executing chart scripts

TODO: The current chart generating scripts need to be merged together and updated to take in cli parameters in order to be more usable. For now, I've been modifying the last line of each script in order to configure the chart I want to generate. I also need to edit the call to `pydot.graph_from_dot_file` to load the correct thread hierarchy graph I'm generating the chart for. In the future, there will be only one script with a nice CLI interface for configuring these options.

There are 2 scripts for generating charts: `aggregate-thread-graph.py` and `single-thread-graph.py`. The `aggregate-thread-graph.py` generates a chart which averages all thread timing metrics across nodes in a testnet. The `single-thread-graph.py` sums all of the thread timing metrics across nodes in a testnet (this was originally used mainly when there was only one node running thread timing metrics, and is not as useful outside of that context). The missing feature from the chart generating scripts at the moment is generating charts for a dashboard where we can select a specific node to see the metrics for (this is easy to add though).

### Importing charts to Grafana

The charts rely on a couple of dashboard variables in order to work properly. You need to have a `testnet` variable, to configure the network the chart will query, and a `sample_range` variable to configure the range aggregation range for the metric. `sample_range` is necessary to configure because different prometheus instances have different scraping intervals. The goal is to choose the smallest `sample_range` possible that works with the query. For our prometheus instances, this is usually `2m`, `3m`, or `5m`. The `sample_range` has to be large enough to include enough samples for the `rate` operator to actually determine the per-second rate of change of the thread timing metrics. This can incur some small delay in chart, but should not be significant.

To import a chart to Grafana:

1. Add a new panel to the dashboard you want to import to.
2. On the dashboard view, when you open the dropdown for the panel (by clicking on the panel title), select "Inspect > Panel JSON".
3. In the righthand view that pops up, take note of the value set in the `id` field (we will need it in a second). Select and delete all of the JSON data for the panel.
4. Paste in the JSON output from the script you ran to generate the chart.
5. Now the annoying part: look for the `id` field of the JSON object you just pasted. Update the `id` field to match `id` of the JSON object you deleted in step 3. Failing to do this can screw up your dashboard in weird ways because Grafana ends up overwriting other charts with the same id in a weird and buggy way. I hope to find a slightly better workflow for importing charts in the future that circumvents this weird chart id behavior that Grafana has.
6. Click "Apply".
