SRC = $(shell find . -name *.chpl)
OUT = bin/main.exe
CHPLFLAGS = --fast --devel
EXTRAFLAGS =

# CHPLFLAGS can be used to add additional compiler flags to Chapel

CollectionAdd-Benchmark:
	chpl testing/Benchmark.chpl collections/DistributedQueue.chpl \
	collections/Collection.chpl testing/collections/AddBenchmark.chpl testing/Plot.chpl collections/SynchronizedList.chpl \
	misc/LocalAtomicObject.chpl misc/GlobalAtomicObject.chpl \
	$(CHPLFLAGS) $(EXTRAFLAGS) --main-module AddBenchmark -o $(OUT)

CollectionRemove-Benchmark:
	chpl testing/Benchmark.chpl collections/DistributedQueue.chpl \
	collections/DistributedBag.chpl \
	collections/Collection.chpl testing/collections/RemoveBenchmark.chpl testing/Plot.chpl collections/SynchronizedList.chpl \
	misc/LocalAtomicObject.chpl misc/GlobalAtomicObject.chpl \
	$(CHPLFLAGS) $(EXTRAFLAGS) --main-module RemoveBenchmark -o $(OUT)

DistributedDeque-UnitTest:
	chpl collections/DistributedDeque.chpl testing/unit/CollectionsTest.chpl \
	collections/Collection.chpl benchmark/NQueens.chpl \
	$(CHPLFLAGS) --no-loop-invariant-code-motion --main-module DistributedDeque -o $(OUT)

DistributedBag-UnitTest:
	chpl collections/DistributedBag.chpl testing/unit/CollectionsTest.chpl \
	collections/Collection.chpl benchmark/NQueens.chpl \
	$(CHPLFLAGS) --no-loop-invariant-code-motion --main-module DistributedBag -o $(OUT)

clean:
	rm $(OUT) $(OUT)_real
