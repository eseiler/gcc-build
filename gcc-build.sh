# ----------------------------------------------------------------------------------------------------
# Copyright (c) 2023, Enrico Seiler
# This file may be used, modified and/or redistributed under the terms of the 3-clause BSD-License
# shipped with this file and also available at: https://github.com/eseiler/gcc-build/blob/main/LICENSE
# ----------------------------------------------------------------------------------------------------

#!/usr/bin/env bash
set -eEuo pipefail

if [ "$#" -ne 1 ]; then
    echo -e "Usage: build.sh <version>\nFor example, build.sh 13.2"
    exit -1
fi

if ! [[ $1 =~ ^[0-9]+\.[0-9]$ ]]; then
    echo -e "Version must match [0-9]+.[0-9]\nFor example, 13.2"
    exit -1
fi

# Checkout of https://github.com/gcc-mirror/gcc
GITDIR=/some/gcc
# Directory where gcc should be made available
BINARYDIR=/some/path/bin

VERSION="$1"
ALLTHREADS=$(grep -c processor /proc/cpuinfo)
NUMTHREADS=$((ALLTHREADS / 2))
BUILDDIR=${GITDIR}-${VERSION}-build
INSTALLDIR=${GITDIR}-${VERSION}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}
mkdir -p ${BINARYDIR}
trap 'echo; echo "[$(date +"%Y-%m-%d %T")] ERROR: Check ${BUILDDIR}/*.log"' INT TERM ERR

cd ${GITDIR}

echo -n "[$(date +"%Y-%m-%d %T")] Fetching upstream repository..."
git fetch -u > ${BUILDDIR}/fetch.log 2>&1
echo "done!"

echo -n "[$(date +"%Y-%m-%d %T")] Checking out branch..."
if git tag -l | grep --quiet "releases/gcc-${VERSION}.0"; then
    BRANCH="releases/gcc-${VERSION}.0"
    echo -n -e "\033[2K\r[$(date +"%Y-%m-%d %T")] Checking out branch ${BRANCH}..."
else
    BRANCH="master"
    read -p " gcc-${VERSION} does not exist. Use the ${BRANCH} branch instead? [y/N] " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    echo -n -e "\033[2K\r[$(date +"%Y-%m-%d %T")] Checking out branch ${BRANCH}..."
fi

git checkout --force ${BRANCH} > ${BUILDDIR}/checkout.log 2>&1
echo "done!"

echo -n "[$(date +"%Y-%m-%d %T")] Downloading prerequisites..."
rm -fdr ${GITDIR}/mpc* ${GITDIR}/mpfr* ${GITDIR}/gmp* ${GITDIR}/isl*
./contrib/download_prerequisites > ${BUILDDIR}/download.log 2>&1
echo "done!"

cd ${BUILDDIR}

echo -n "[$(date +"%Y-%m-%d %T")] Configuring build..."
# https://gcc.gnu.org/install/configure.html
${GITDIR}/configure --build=x86_64-linux-gnu \
                    --disable-bootstrap \
                    --disable-libssp \
                    --disable-libstdcxx-pch \
                    --disable-libunwind-exceptions \
                    --disable-multilib \
                    --disable-werror \
                    --enable-cet=auto \
                    --enable-clocale=gnu \
                    --enable-__cxa_atexit \
                    --enable-default-pie \
                    --enable-default-ssp \
                    --enable-gnu-indirect-function \
                    --enable-gnu-unique-object \
                    --enable-install-libiberty \
                    --enable-languages=c,c++,lto \
                    --enable-linker-build-id \
                    --enable-lto \
                    --enable-objc-gc=auto \
                    --enable-plugin \
                    --enable-shared \
                    --enable-threads=posix \
                    --host=x86_64-linux-gnu \
                    --no-create \
                    --no-recursion \
                    --prefix=${INSTALLDIR} \
                    --program-suffix=-${VERSION} \
                    --target=x86_64-linux-gnu \
                    --with-abi=m64 \
                    --with-arch-32=i686 \
                    --with-bugurl=https://gcc.gnu.org/bugzilla/ \
                    --with-gcc-major-version-only \
                    --with-linker-hash-style=gnu \
                    --without-cuda-driver \
                    --with-system-zlib \
                    --with-tune=generic >  ${BUILDDIR}/configure.log 2>&1
./config.status >> ${BUILDDIR}/configure.log 2>&1
echo "done!"

echo -n "[$(date +"%Y-%m-%d %T")] Building compiler..."
make -j${NUMTHREADS} > ${BUILDDIR}/build.log 2>&1
echo "done!"

echo -n "[$(date +"%Y-%m-%d %T")] Installing compiler..."
make -j${NUMTHREADS} install > ${BUILDDIR}/install.log 2>&1

# E.g., remove old gcc-ar-14
# E.g., new link: ${BINARYDIR}/gcc-ar-14 -> ${INSTALLDIR}/bin/gcc-ar-14.0
for BINARY in "gcc-ar" "gcc-nm" "gcc-ranlib" "gcov" "gcov-dump" "gcov-tool" "lto-dump"; do
    rm -f ${BINARYDIR}/${BINARY}-${VERSION::-2}
    ln -f -s ${INSTALLDIR}/bin/${BINARY}-${VERSION} ${BINARYDIR}/${BINARY}-${VERSION::-2}
done
echo "done!"

echo_wrapper() {
echo '#!/usr/bin/env bash

SYSROOT="INSTALLDIR"
GCC=$SYSROOT/bin/TYPE-VERSION

export LD_LIBRARY_PATH=$SYSROOT/lib64:$LD_LIBRARY_PATH
if [[ "$@" = "-v" ]] || [[ "$@" = "--version" ]]; then
    exec "$GCC" "$@"
    exit 0
fi
rpathflags="-Wl,-rpath -Wl,$SYSROOT/lib64"
exec "$GCC" $rpathflags "$@"' | \
sed "s@TYPE@${TYPE}@g" | \
sed "s@VERSION@${VERSION}@g" | \
sed "s@INSTALLDIR@${INSTALLDIR}@g"
}

echo -n "[$(date +"%Y-%m-%d %T")] Creating wrapper..."
for TYPE in "gcc" "g++" "c++" "cpp"; do
    FILE="${BINARYDIR}/${TYPE}-${VERSION::-2}"
    echo_wrapper > ${FILE}
    chmod 0755 ${FILE}
done
echo "done!"

echo -n "[$(date +"%Y-%m-%d %T")] Removing build directory..."
rm -fdr ${BUILDDIR}
echo "done!"

