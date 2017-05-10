dirs := $(sort $(dir $(wildcard */)))

create_configmap = kubectl create configmap $(d:/=) --from-file=$(d)
delete_configmap = kubectl delete configmap $(d:/=)

all:
	@$(foreach d,$(dirs),$(call create_configmap,$(d));)

cleanup:
	@$(foreach d,$(dirs),$(call create_configmap,$(d));)
