#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

##apt install -y autopoint

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
#unyp install

#pip3_bin=(/uny/pkg/python/*/bin/pip3)
#"${pip3_bin[0]}" install --upgrade pip
#"${pip3_bin[0]}" install docutils pygments

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="ncurses"
pkggit="https://github.com/ThomasDickey/ncurses-snapshots.git refs/tags/*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --sort="v:refname" $pkggit | grep -E "v[0-9]_[0-9]+$" | tail -n 1)"
latest_ver="$(echo "$latest_head" | cut --delimiter='/' --fields=3 | sed -e "s|v||" -e "s|_|.|")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

#cd "$pkgname" || exit
#./autogen.sh
#cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="ncurses"

dont_clean=yes
version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

unset LD_RUN_PATH

./configure --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --with-shared \
    --without-debug \
    --without-normal \
    --with-cxx-shared \
    --enable-pc-files \
    --enable-widec \
    --with-pkg-config-libdir=/uny/pkg/"$pkgname"/"$pkgver"/lib/pkgconfig

make -j"$(nproc)"
make install

cur_path="$(pwd)"
cd /uny/pkg/"$pkgname"/"$pkgver"/lib || exit
for lib in ncurses form panel menu; do
    ln -sfv lib${lib}w.so lib${lib}.so
    ln -sfv pkgconfig/${lib}w.pc pkgconfig/${lib}.pc
done
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i ../include/curses.h
cd ../include || exit
ln -s ncursesw ncurses
cd "$cur_path" || exit

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
