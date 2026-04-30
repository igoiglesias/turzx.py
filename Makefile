.PHONY: install run clean config

SHELL := /bin/bash


install:
	bash install-deps.sh
	virtualenv --system-site-packages -p /usr/bin/python3.12 .venv && \
	source .venv/bin/activate && \
	pip install -r requirements.txt

config: install
	.venv/bin/python config_gui.py

run: install
	.venv/bin/python main.py

clean:
	rm -rf .venv
