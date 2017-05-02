dockers := $(basename $(wildcard *.Dockerfile))

build_docker = docker build -t lyanchih/$(1) -f $(1).Dockerfile .
push_docker = docker push lyanchih/$(1)

all: build push

build:
	@$(foreach docker,$(dockers),$(call build_docker,$(docker));)

push:
	@$(foreach docker,$(dockers),$(call push_docker,$(docker));)
