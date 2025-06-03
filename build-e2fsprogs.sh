#!/bin/bash
#
# An example of how to create e2fsprogs statically for different architectures
#
# Used to accompany The PSCG's training/Ron Munitz's talks
#
: ${SRC_PROJECT=$(readlink -f ./e2fsprogs)}
: ${USE_MULTILIB_FOR_32BIT_X86=false}	# if true - use -m32. This conflicts with all cross-compilers. A better alternative for 2025 is to use native toolchain distro, i686-linux-gnu-...

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
	for tuple in x86_64-linux-gnu aarch64-linux-gnu riscv64-linux-gnu arm-linux-gnueabi i686-linux-gnu ; do	
		export CROSS_COMPILE=${tuple}- # we'll later strip it but CROSS_COMPILE is super standard, and autotools is "a little less standard"
		build_with_installing $tuple-build $tuple-install 2> err.$tuple
	done

}

fetch() {
	git clone https://github.com/tytso/e2fsprogs.git -b v1.47.0
}

#
# Build 32 bit x86 on x86_64 hosts. This is not cross compilation, but rather requires some make flags and the installation of multilib
#
build_and_install_32bitx86_on_x86_64() {
	export CROSS_COMPILE=""
	local tuple=i386-linux-gnu # pretty much arbitrary
	local builddir=$PWD/$tuple-build
	local installdir=$PWD/$tuple-install
	mkdir $builddir
	cd $builddir || exit 1
	$SRC_PROJECT/configure LDFLAGS="--static -m32" CFLAGS=-m32 || exit 1
	make -j$(nproc) DESTDIR=$installdir install-strip 2>err.$tuple

}

main() {
	fetch || exit 1
	build_for_several_tuples
	if [ "$(uname -m)" = "x86_64" ] ; then
		if [ "$USE_MULTILIB_FOR_32BIT_X86" = "true" ] ; then
			build_and_install_32bitx86_on_x86_64
		fi
	fi
}

main $@
