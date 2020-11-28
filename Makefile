PROGRAM = getall
VPATH   = src/
DEST    = ${HOME}/bin


.PHONY: all
all: ${PROGRAM}

.PHONY: clean
clean:
	${RM} ${PROGRAM}

.PHONY: install
install: ${PROGRAM}
	install ${PROGRAM} ${DEST}
