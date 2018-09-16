all: test
.PHONY: test start stress

start:
	@zsh -f tests/start.sh

test:
	@zsh -f tests/integration/test.sh -l test.log -t srv

stress:
	@zsh -f tests/stress/stress.sh -l stress.log
