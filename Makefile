SRC = $(shell find . -name *.chpl)
OBJ = $(SRC:%.chpl=%.o)
BIN = bin/main.exe

all:
	chpl --fast $(SRC) -o $(BIN) --main-module benchmark

clean:
	rm $(BIN) $(BIN)_real
