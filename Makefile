all: test
.PHONY: test stress

test:
	@zsh -f tests/integration/test.sh -l test.log

stress:
	@zsh -f tests/stress/stress.sh -l stress.log
