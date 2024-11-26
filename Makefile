pack:
	@echo "Packing..."
	hack/pack.sh

release: pack
	@echo "Releasing..."
	hack/release.sh
