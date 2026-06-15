Conference DC Index Propagation Recovery

If full site indexing in Conference DC fails, do not restart the indexing process immediately. First, open the indexing status endpoint below to verify the state of all indexing stages.

In a 5-node cluster, only one node performs index generation. After index and optic completion, the index files are propagated to the remaining cluster nodes.

Review the propagation status table. If propagation failed only on specific secondary nodes, restart only those nodes. During startup, they will automatically synchronize the latest index from the cluster.