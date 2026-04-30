.PHONY: install run clean

SHELL := /bin/bash


install:
	bash install-deps.sh
	virtualenv --system-site-packages -p /usr/bin/python3.12 .venv && \
	source .venv/bin/activate && \
	pip install -r requirements.txt

run: install
	.venv/bin/python main.py

clean:
	rm -rf .venv
