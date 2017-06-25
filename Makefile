SRC = $(shell find . -name *.chpl)
OBJ = $(SRC:%.chpl=%.o)
BIN = bin/main.exe

Benchmark:
	chpl --devel --fast queues/Queue.chpl queues/local/SyncQueue.chpl queues/local/CCQueue.chpl \
	benchmark/cclock.chpl queues/distributed/DistributedFIFOQueue.chpl queues/distributed/DistributedQueue.chpl \
	benchmark/benchmark.chpl misc/LocalAtomicObject.chpl \
	-o $(BIN) --main-module benchmark

NQueens:
	chpl --devel --fast queues/distributed/DistributedFIFOQueue.chpl misc/LocalAtomicObject.chpl \
	benchmark/NQueens.chpl queues/Queue.chpl queues/local/SyncQueue.chpl \
	-o $(BIN) --main-module NQueens

clean:
	rm $(BIN) $(BIN)_real
