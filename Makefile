all: test
.PHONY: test start stress

start:
	@zsh -f test/start.sh

test:
	@zsh -f test/integration/test.sh -l test.log -t srv,parse_request

stress:
	@zsh -f test/stress/stress.sh -l stress.log
