PID := $(shell cat .czhttpd-pid 2>/dev/null)

all: test
.PHONY: start debug reload test stress clean

start:
	@zsh -f test/start.sh

debug:
	@zsh -f test/start.sh --full-debug

reload:
	@kill -0 $(PID) && kill -HUP $(PID)

test:
	@zsh -f test/integration/test.sh -l test.log $(CLI_ARGS)

stress:
	@zsh -f test/stress/stress.sh -l stress.log $(CLI_ARGS)

clean:
	rm -rf {test,stress}.log test/stress/{html,report}
