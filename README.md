# Distributed Queue

This repository features two work-in-progress queues that scale under certain
workloads, both with varying traits and practical use-cases. One queue provides
a strict FIFO ordering across clusters (FIFO), and the other has more loose
guarantees for ordering that employs work stealing (MPMC). Neither queues are
NUMA-aware.

## Queue Descriptions

All performance testing is done on a 44 core Intel Haswell machine (w/ 24 processors per node).

## FIFO

* Ensures FIFO ordering across multiple clusters
* Enqueue operations scale well
  * Bad under heavy contention due to Network Atomics
* Dequeue operations do not scale
  * Migrate to owning locale due to excess communication and synchronization

### Performance

#### Enqueue

![](Results/EnqueueFIFO.png)

#### Dequeue

**Work In Progress**

## MPMC

* Enqueue is communication free and scales very well
* Dequeue is mostly communication free and scales very well
  * Dequeue communications occur during work stealing
* Employs Work Stealing algorithm to ensure that majority of operations may remain local
* Does not ensure a global FIFO ordering, nor local due to work stealing.
  * Possible to have FIFO ordering under certain circumstances...

### Features

#### Bulk Insertion and Removal (WIP)

### Performance

#### Enqueue

![](Results/EnqueueMPMC.png)

#### Dequeue

**Work In Progress**
