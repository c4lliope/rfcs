BRANCH=$(shell git rev-parse --abbrev-ref HEAD)

all: .git/HEAD

.git/HEAD: */proposal.md
	git add $?
	git commit -m "wip"
	git push origin HEAD:${BRANCH}-wip
