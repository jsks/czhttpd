PID := $(shell cat .czhttpd-pid)

all: test
.PHONY: start debug reload test stress

start:
	@zsh -f test/start.sh

debug:
	@zsh -f test/start.sh --full-debug

reload:
	@kill -0 $(PID) && kill -HUP $(PID)

test:
	@zsh -f test/integration/test.sh -l test.log

stress:
	@zsh -f test/stress/stress.sh -l stress.log
