# Replayer CronJobs
This Helm Chart aims to ease the process of scripting the replayers mainly by isolating the script from the Kubernetes manifests.

Currently, Helm will navigate over all files in [`files/`](.files/) and create a CronJob from it based on the provided [template](.templates/)

**NOTES:** all CronJobs are created with the same schedule, image and resources. If required this limitation can be easily removed in the future by looping over a new `.Values.replayers` object.