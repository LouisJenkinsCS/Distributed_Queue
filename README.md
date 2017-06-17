# Distributed Queue

This is a Multi-Producer Multi-Consumer queue created to scale across HPC clusters.
The queue is (work-in-progress) to utilize work stealing to ensure that memory consumption
and computation time is evenly balanced across all clusters, although this does not come
without cost, as we lose absolute FIFO ordering in favor of gaining performance. While the
queue is not NUMA-aware, we minimize any and all memory contention to ensure performance
on both UMA and NUMA architectures.

For emphasis, __this queue favors scalability and performance over FIFO-ness__, as communications
between HPC clusters are magnitudes slower and make it impossible to scale.

## Features

### Work Stealing (WIP)

### Bulk Insertion and Removal (WIP)

#### Ranges and Arrays

### FIFO ordering

The queue *can* be FIFO, but only under a few circumstances...

1) Operations that are local are ensured to be FIFO, so long as work stealing is not employed. (MPMC)
2) Operations across locales are FIFO so long as only one locale is a producer and another is a consumer. (MPMC)
