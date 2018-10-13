PID := $(shell cat .czhttpd-pid)

all: test
.PHONY: test start stress

start:
	@zsh -f test/start.sh


reload:
	@kill -0 $(PID) && kill -HUP $(PID)

test:
	@zsh -f test/integration/test.sh -l test.log -t srv,parse_request

stress:
	@zsh -f test/stress/stress.sh -l stress.log
