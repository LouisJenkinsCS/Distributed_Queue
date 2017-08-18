# Distributed Data Structures

This repository hosts the first framework for distributed data structures for the
Chapel programming language. Here we introduce a 'Collections API', based on Java's
Collections framework, as well as some data structures, some distributed, others
local.

## Performance Testing

All benchmarks performed on a Cray-XC40 cluster.

## Deque

Provides a strict ordering without sacrificing too much performance. Supports insertion
and removal from both ends, allowing FIFO, LIFO, and a Total ordering, which is
preserved across all nodes in a cluster, and employs a wait-free round-robin approach
to load distribution that ensures fairness in memory, bandwidth, and computation.

**Disclaimer:** The deque provided, while scalable, rely heavily on network atomics.
The benchmark results are produced using said network atomic operations.

## MultiSet

With performance that scales both in the number of nodes in a cluster and the
number of cores per node, we offer a multiset implementation, called a 'Bag',
which is a medium that allows storing and retrieving data in any arbitrary order.
This type of data structure is ideal for work queues as it employs it's own load
balancing, and offers unparalleled performance.

**Disclaimer:** A node can request a 'privatized' copy, which retrieves a clone
that is allocated on the node requesting it, reducing any excess communication.
Usage of `getPrivatizedInstance()` is highly advised for performance-critical
sections.

### Performance

TODO: Update with new results

We compare our data structures to a naive synchronized list implementation
as that is all that is available. In all cases, the data structures scale and
outperform the naive implementation by far.

#### Insert

Implementation | Performance over Naive
-------------- | :-----------:
SynchronizedList | 100%
DistributedBoundedQueue | 6233.1%
DistributedQueue | 3638%
DistributedBag | 40323%

![](Results/Collections_Add.png)

#### Remove

In this benchmark, we test raw removal time. In the case of DistributedBag, we have
two variants; one which tests remove when it is already load balanced (as in we
fill the bag ahead of time in a fairly distributed manner), given a `(Balanced)` suffix,
and one which is not all too uncommon, where we add all elements to a single node
causing an artificial imbalance, which tests how the bag performs in the worst case.

Implementation | Performance over Naive
-------------- | :-----------:
SynchronizedList | 100%
DistributedBoundedQueue | 9345.4%
DistributedQueue | 6225.1%
DistributedBag (Imbalanced) | 18853%
DistributedBag (Balanced) | 50330%

![](Results/Collections_Remove.png)
