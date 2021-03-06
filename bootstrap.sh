#!/bin/bash
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# //FIXME: error checking, proper on configure or half downloaded archives
set -u
set -e

DIR=`pwd`
UNAME=`uname -s | grep -m1 -ioE '[a-z]+' | awk 'NR==1{print $0}'` # detection of OS
CROSSDIR="$DIR/cc/$UNAME" # crosstools dir

WIN=0
BUILDARCHS="x86_64-pc-elf" # x86_64-pc-elf, "x86_64-pc-elf i686-pc-elf aarch64-none-elf"
BUILDBACKENDS="gdc" # gdc, "gdc ldc dmd"

while getopts "ckva:b:" opt; do
	case "$opt" in
		a) # select architectures to build
			BUILDARCHS=${OPTARG,,}
		;;
		c) # clean build tools dir
			rm -rf $CROSSDIR/binutils-*
			rm -rf $CROSSDIR/gcc-*
			rm -rf $CROSSDIR/gdc
			rm -rf $CROSSDIR/gdb-*
			rm -rf $CROSSDIR/ldc
			rm -rf $CROSSDIR/bochs-*
			rm -rf $CROSSDIR/mtools-*
			rm -rf $CROSSDIR/llvm*
			rm -rf $CROSSDIR/dmd
			exit 0
		;;
		b) # compiler backend to build
			BUILDBACKENDS=${OPTARG,,}
		;;
		v) # set verbosity
			set -x
		;;
	esac
done

if [[ "$UNAME" == "CYGWIN" || "$UNAME" == "MINGW" ]]; then
	WIN=1
fi


# mingw will fail
if [ "$UNAME" == "MINGW" ]; then
	echo "mingw not supported; exiting"
	exit 0;
fi

# check for tools
TOOLS="curl git svn bison flex make gcc gdb texindex tar xzcat python patch"
for TOOL in $TOOLS; do
	if ! which "$TOOL"; then
		echo "$TOOL not found; exiting"
		exit 0;
	fi
done

if [[ $BUILDBACKENDS =~ "ldc" ]]; then
	if ! which "cmake"; then
		echo "cmake not found; exiting"
		exit 0;
	fi
fi



if [ ! -f "$CROSSDIR/bin/" ]; then
	mkdir -p "$CROSSDIR"
	mkdir -p "$CROSSDIR/bin/"
fi


# build cross compile tools
for BUILDARCH in $BUILDARCHS; do
	LD="$CROSSDIR/bin/$BUILDARCH-ld"
	GCC="$CROSSDIR/bin/$BUILDARCH-gcc"
	LDC="$CROSSDIR/bin/ldc2"
	DMD="$CROSSDIR/bin/dmd"
	BOCHS="$CROSSDIR/bin/bochs"

	if [ ! -f "$LD" ]; then
		BINSRCDIR="$CROSSDIR/binutils-2.24"
		BINARCHIVE="$CROSSDIR/binutils-2.24.tar.bz2"
		BINBUILD="$CROSSDIR/binutils-2.24-$BUILDARCH"

		# fetch binutils
		if [ ! -d "$BINSRCDIR" ]; then
			test -f "$BINARCHIVE" || curl -v -o "$BINARCHIVE" "http://ftp.gnu.org/gnu/binutils/binutils-2.24.tar.bz2"
			tar -xjf "$BINARCHIVE" -C "$CROSSDIR"
		fi

		mkdir -p "$BINBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		cd "$BINBUILD"
		../binutils-2.24/configure --target="$BUILDARCH" --prefix="$CROSSDIR" --disable-nls --enable-64-bit-bfd --disable-werror

		make all
		make install
	fi

	if [ ! -f "$GCC" ]; then
		GCCSRCDIR="$CROSSDIR/gcc-4.8.2"
		GCCARCHIVE="$CROSSDIR/gcc-4.8.2.tar.bz2"
		GCCBUILD="$CROSSDIR/gcc-4.8.2-$BUILDARCH"

		# fetch gcc
		if [ ! -d "$GCCSRCDIR" ]; then
			test -f "$GCCARCHIVE" || curl -v -o "$GCCARCHIVE" "http://ftp.gnu.org/gnu/gcc/gcc-4.8.2/gcc-4.8.2.tar.bz2"
			tar -xjf "$GCCARCHIVE" -C "$CROSSDIR"
		fi

		# fetch iconv
		if [ ! -d "$GCCSRCDIR/iconv" ]; then
			curl -v -o "$GCCSRCDIR/libiconv-1.14.tar.gz" "http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz"
			tar -xzf "$GCCSRCDIR/libiconv-1.14.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/libiconv-1.14" "$GCCSRCDIR/iconv"
			rm "$GCCSRCDIR/libiconv-1.14.tar.gz"
		fi

		# fetch gmp
		if [ ! -d "$GCCSRCDIR/gmp" ]; then
			curl -v -o "$GCCSRCDIR/gmp-5.1.3.tar.bz2" "https://gmplib.org/download/gmp/gmp-5.1.3.tar.bz2"
			tar -xjf "$GCCSRCDIR/gmp-5.1.3.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/gmp-5.1.3" "$GCCSRCDIR/gmp"
			rm "$GCCSRCDIR/gmp-5.1.3.tar.bz2"
		fi
	
		# fetch mpfr
		if [ ! -d "$GCCSRCDIR/mpfr" ]; then
			curl -v -o "$GCCSRCDIR/mpfr-3.1.2.tar.bz2" "http://www.mpfr.org/mpfr-current/mpfr-3.1.2.tar.bz2"
			tar -xjf "$GCCSRCDIR/mpfr-3.1.2.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/mpfr-3.1.2" "$GCCSRCDIR/mpfr"
			rm "$GCCSRCDIR/mpfr-3.1.2.tar.bz2"
		fi

		# fetch mpc
		if [ ! -d "$GCCSRCDIR/mpc" ]; then
			curl -v -o "$GCCSRCDIR/mpc-1.0.2.tar.gz" "http://ftp.gnu.org/gnu/mpc/mpc-1.0.2.tar.gz"
			tar -xzf "$GCCSRCDIR/mpc-1.0.2.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/mpc-1.0.2" "$GCCSRCDIR/mpc"
			rm "$GCCSRCDIR/mpc-1.0.2.tar.gz"
		fi

		# fetch gdc
		if [[ ! -d "$CROSSDIR/gdc/dev" && $BUILDBACKENDS =~ "gdc" ]]; then
			mkdir -p "$CROSSDIR/gdc"
			cd "$CROSSDIR"
			git clone https://github.com/D-Programming-GDC/GDC.git "$CROSSDIR/gdc/dev"
			cd "$CROSSDIR/gdc/dev"
			git checkout gdc-4.8
			$CROSSDIR/gdc/dev/setup-gcc.sh "$GCCSRCDIR"
		fi


		mkdir -p "$GCCBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		cd "$GCCBUILD"
		../gcc-4.8.2/configure --target="$BUILDARCH" --prefix="$CROSSDIR" --disable-nls --enable-languages=c,c++,d --without-headers --disable-libphobos --disable-werror

		make all-gcc
		make install-gcc
	fi


	if [[ ! -f "$LDC" && $BUILDBACKENDS =~ "ldc" && $WIN -eq 0 ]]; then
		cd "$CROSSDIR"

		# build llvm/clang first if needed
		if ! which "clang"; then
			cd "$CROSSDIR"
			test -d "$CROSSDIR/llvm" || svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
			cd "$CROSSDIR/llvm/tools"
			test -d "$CROSSDIR/llvm/tools/clang" || svn co http://llvm.org/svn/llvm-project/cfe/trunk clang
			cd "$CROSSDIR/llvm/tools/clang/tools"
			test -d "$CROSSDIR/llvm/tools/clang/tools/extra" || svn co http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra
			cd "$CROSSDIR/llvm/projects" 
			test -d "$CROSSDIR/llvm/projects/compiler-rt" || svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt

			mkdir -p "$CROSSDIR/llvm-build"
			../llvm/configure --enable-optimized

			make
			make install

			cd "$CROSSDIR"
		fi

		LDCBUILD="$CROSSDIR/ldc/build-$BUILDARCH"

		test -d "$CROSSDIR/ldc" || git clone --recursive https://github.com/ldc-developers/ldc.git

		mkdir -p "$LDCBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		cd "$LDCBUILD"

		cmake .. -DCMAKE_INSTALL_PREFIX="$CROSSDIR" -DINCLUDE_INSTALL_DIR="$CROSSDIR/include"
		make
		make install
	fi


	if [[ ! -f "$DMD" && $BUILDBACKENDS =~ "dmd" && $WIN -eq 0 ]]; then
		cd "$CROSSDIR"
		test -d "$CROSSDIR/dmd" || git clone --recursive https://github.com/D-Programming-Language/dmd.git

		cd "$CROSSDIR/dmd"
		make -f posix.mak MODEL=64 TARGET_CPU=X86
		cp src/dmd "$CROSSDIR/bin/dmd"
		cp src/dmd.conf.default "$CROSSDIR/bin/dmd.conf"
	fi


	if [[ ! -f "$BOCHS"  && $WIN -eq 0 ]]; then
		cd "$CROSSDIR"
		test -f "$CROSSDIR/bochs-2.6.2.tar.gz" || curl -v -o "$CROSSDIR/bochs-2.6.2.tar.gz" -L http://downloads.sourceforge.net/project/bochs/bochs/2.6.2/bochs-2.6.2.tar.gz

		if [ ! -d "$CROSSDIR/bochs-2.6.2" ]; then
			tar -xzf "$CROSSDIR/bochs-2.6.2.tar.gz" -C "$CROSSDIR"
			cd "$CROSSDIR/bochs-2.6.2"
			patch -p1 < ../../../support/bochs.patch
		fi

		cd "$CROSSDIR/bochs-2.6.2"
		./configure --disable-plugins --enable-x86-64 --enable-smp --enable-cpu-level=6 --enable-large-ramfile --enable-ne2000 --enable-pci --enable-usb --enable-usb-ohci --enable-e1000 --enable-debugger --enable-disasm --enable-debugger-gui --enable-iodebug --enable-all-optimizations --enable-logging --enable-fpu --enable-vmx --enable-svm --enable-avx --enable-x86-debugger --enable-cdrom --enable-sb16=dummy --disable-docbook --with-x --with-x11 --with-term --prefix="$CROSSDIR"
		sed -i 's/BX_NETMOD_FBSD 1/BX_NETWORK_FBSD 0/g' config.h
		make
		make install
	fi
done

MTOOLS="$CROSSDIR/bin/mtools"
if [[ ! -f "$MTOOLS"  && $WIN -eq 1 ]]; then
	test -f "$CROSSDIR/mtools-4.0.18.tar.bz2" || curl -v -o "$CROSSDIR/mtools-4.0.18.tar.bz2" ftp://ftp.gnu.org/gnu/mtools/mtools-4.0.18.tar.bz2

	if [ ! -d "$CROSSDIR/mtools-4.0.18" ]; then
		tar -xjf "$CROSSDIR/mtools-4.0.18.tar.bz2" -C "$CROSSDIR"
		cd "$CROSSDIR/mtools-4.0.18"
		patch -p1 < ../../../support/mtools.patch
	fi

	cd "$CROSSDIR/mtools-4.0.18"

	export PREFIX="$CROSSDIR"
	export TARGET="$BUILDARCH"

	./configure --prefix="$CROSSDIR"

	make
	make install
fi

# done
cd "$DIR"

# fetch waf
if [ ! -f "waf" ]; then
	curl -v -o "$DIR/waf" "https://waf.googlecode.com/files/waf-1.7.15"
	chmod a+rx "$DIR/waf"
fi
