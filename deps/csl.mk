ifneq ($(USE_BINARYBUILDER_CSL),1)

# If we're not using BB-vendored CompilerSupportLibraries, then we must
# build our own by stealing the libraries from the currently-running system.
# While at first it seemed a grand idea to use `g++` and `clang++`'s built-in
# facilities for locating compiler support libraries (`--print-file-name $lib`)
# it turns out this is quite unreliable, so we fall back to what we know best:
# just compile the blasted thing then analyze the output after.  We'll compile
# test programs, then analyze the linkage in order to discover the location of
# the relevant compiler support libraries.

$(BUILDDIR)/csl:
	mkdir -p "$@"

$(BUILDDIR)/csl/cxx_finder.cc: | $(BUILDDIR)/csl
	@echo "#include <iostream>\n#include <omp.h>\nint main(void) { return omp_get_thread_num(); }" > "$@"
$(BUILDDIR)/csl/fortran_finder.f95: | $(BUILDDIR)/csl
	@echo "program julia\nend program julia" > "$@"

$(BUILDDIR)/csl/cxx_finder$(EXE): $(BUILDDIR)/csl/cxx_finder.cc
	@$(call PRINT_CC,$(CXX) -x c++ -o "$@" -fopenmp "$<")

$(BUILDDIR)/csl/fortran_finder$(EXE): $(BUILDDIR)/csl/fortran_finder.f95
	@$(call PRINT_CC,$(FC) -ffree-form -x f95 -o "$@" "$<")

# We're going to capture things we directly depend on:
CSL_LIBS := libgcc_s libstdc++ libc++ libpthread libgfortran libquadmath
# And also things that dependencies may depend on
CSL_LIBS += libgcc_ext libgomp libiomp libasan libatomic libcilkrts libitm liblsan libmpx libmpxwrappers libssp libtsan libubsan
# Things that I don't think anything in the Julia ecosystem uses, but are still included in the real CSL_jll
CSL_LIBS += libobjc libobjc-gnu

$(BUILDDIR)/csl/libraries.list: $(BUILDDIR)/csl/cxx_finder$(EXE) $(BUILDDIR)/csl/fortran_finder$(EXE) | $(build_prefix)/manifest/libwhich
	@rm -f "$@" "$@.preuniq"
	@$(call spawn,$(build_depsbindir)/libwhich) -a $(BUILDDIR)/csl/cxx_finder$(EXE) | tr '\0' '\n' | grep $(foreach lib,$(CSL_LIBS),-e $(lib)) >> "$@.preuniq"
	@$(call spawn,$(build_depsbindir)/libwhich) -a $(BUILDDIR)/csl/fortran_finder$(EXE) | tr '\0' '\n' | grep $(foreach lib,$(CSL_LIBS),-e $(lib)) >> "$@.preuniq"
	@cat "$@.preuniq" | sort | uniq > "$@"
	@rm -f "$@.preuniq"

UNINSTALL_compilersupportlibraries = delete-uninstaller "$(foreach lib,$(shell cat $(BUILDDIR)/csl/libraries.list),$(build_shlibdir)/$(shell basename $(lib)))"
$(build_prefix)/manifest/compilersupportlibraries: $(BUILDDIR)/csl/libraries.list | $(build_shlibdir) $(build_prefix)/manifest
	@cp -v $$(cat "$<") $(build_shlibdir)/
	echo '$(UNINSTALL_compilersupportlibraries)' > "$@"

get-compilersupportlibraries:
extract-compilersupportlibraries:
configure-compilersupportlibraries:
compile-compilersupportlibraries:
install-compilersupportlibraries: $(build_prefix)/manifest/compilersupportlibraries

$(eval $(call jll-generate,CompilerSupportLibraries_jll, \
                           libgcc_s=\"libgcc_s\" \
						   libgomp=\"libgomp\" \
						   libgfortran=\"libgfortran\" \
						   libstdcxx=\"libstdc++\" \
                           ,,e66e0078-7015-5450-92f7-15fbd957f2ae,))
else # USE_BINARYBUILDER_CSL

# Install CompilerSupportLibraries_jll into our stdlib folder
$(eval $(call install-jll-and-artifact,CompilerSupportLibraries_jll))

endif