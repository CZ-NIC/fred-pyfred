.PHONY: default isort check-all check-isort

default: check-all

isort:
	isort --recursive .

check-all: check-isort

check-isort:
	isort --recursive --check-only --diff
