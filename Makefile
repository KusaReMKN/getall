PROGRAM = getall
VPATH   = src/

.PHONY: all
all: ${PROGRAM}

.PHONY: clean
clean:
	${RM} ${PROGRAM}
