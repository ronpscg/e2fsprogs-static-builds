#!/bin/bash
#
# An example of how to create e2fsprogs statically for different architectures
#
# Used to accompany The PSCG's training/Ron Munitz's talks
#
: ${SRC_PROJECT=$(readlink -f ./e2fsprogs)}

# ./configure vs. make:
# Could use --prefix in configure, but it's working with another folder, and we don't really want the entire set of tools here.
# In addition the install-strip target does not seem to be implemented, and even with --prefix it tries to do some udev stuff which is wrong
# so there is no point in it
#
# Instead, in this particular case,  # make -j16 DESTDIR=... install-strip does the job, without the --prefix in configure.
# It does suffer from the same errors, but at least you don't need to go thorugh an additional stripping phase
# We present two versions for you to experiment with. The one with the find could be more accurate, as some of the executables are
# shell script, so obviously they are not to be stripped.
#

#
# $1: build directory
#
build_without_installing() (
	mkdir $1
	cd $1
	$SRC_PROJECT/configure LDFLAGS=-static  --host=${CROSS_COMPILE%-} || exit 1
	make -j$(nproc)
	find . -executable -not -type d | xargs ${CROSS_COMPILE}strip -s
)


#
# $1: build directory
# $2: install directory
#
build_with_installing() (
	installdir=$(readlink -f $2)
	mkdir $1 # You must create the build and install directories. make will not do that for you
	cd $1
	$SRC_PROJECT/configure LDFLAGS=--static  --host=${CROSS_COMPILE%-} || exit 1
	make -j$(nproc) DESTDIR=$installdir install-strip 
)


# This example builds for several tuples
# The function above can be used from outside a script, assuming that the CROSS_COMPILE variable is set
# It may however need more configuration if you do not build for gnulibc
build_for_several_tuples() {
	for tuple in x86_64-linux-gnu aarch64-linux-gnu riscv64-linux-gnu arm-linux-gnueabi ; do	
		export CROSS_COMPILE=${tuple}- # we'll later strip it but CROSS_COMPILE is super standard, and autotools is "a little less standard"
		build_with_installing $tuple-build $tuple-install 2> err.$tuple
	done

}

fetch() {
	git clone https://github.com/tytso/e2fsprogs.git -b v1.47.0
}

main() {
	fetch || exit 1
	build_for_several_tuples
}

main $@
