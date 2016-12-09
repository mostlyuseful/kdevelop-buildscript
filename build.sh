#!/bin/bash

# Based on http://files.svenbrauch.de/kdevelop-linux/kdevelop-recipe-centos6.sh

# On Amazon AWS start an Amazon Linux instance (I used c4.2xlarge) and run:
# sudo yum -y install docker
# sudo service docker start
# sudo docker run -i -t scummos/centos6.8-qt5.7
# wget -c https://github.com/probonopd/AppImages/raw/master/recipes/kdevelop/Recipe
# bash -ex Recipe

# Halt on errors
set -e

# Be verbose
set -x

# Get helper functions
. ./functions.sh

git_pull_rebase_helper()
{
    #git fetch --tags
    #git stash || true
    #git pull --rebase
    #git stash pop || true

    git fetch --tags
    git reset --hard
}

export TOPDIR=$(pwd)
# Amount of parallelism in make, i.e. the -j parameter
export PARALLEL_JOBS=4
export CMAKE_GENERATOR=-GNinja

KDEVELOP_VERSION=v5.0.3
KDEV_PG_QT_VERSION=v2.0.0
KF5_VERSION=v5.28.0
KDE_APPLICATION_VERSION=v16.08.0
GRANTLEE_VERSION=v5.1.0

# QT version to use
#QTDIR=~/Qt/5.7/gcc_64/
#QT_CMAKE_DIR=$QTDIR/lib/cmake/
#QT_QMAKE_CMD=$QTDIR/bin/qmake
#export QT_QMAKE_EXECUTABLE=QT_QMAKE_CMD

# qjsonparser, used to add metadata to the plugins needs to work in a en_US.UTF-8 environment. That's
# not always set correctly in CentOS 6.7
#FIXME
export LC_ALL=en_US.UTF-8
export LANG=en_us.UTF-8

# Determine which architecture should be built
if [[ "$(arch)" = "i686" || "$(arch)" = "x86_64" ]] ; then
  ARCH=$(arch)
else
  echo "Architecture could not be determined"
  exit 1
fi

#FIXME
#export PATH=/opt/rh/python27/root/usr/bin/:$PATH
#export LD_LIBRARY_PATH=/opt/rh/python27/root/usr/lib64:$LD_LIBRARY_PATH

# Make sure we build from the /, parts of this script depends on that. We also need to run as root...
#FIXME
#cd  /

#FIXME
export CMAKE_PREFIX_PATH=$QT_CMAKE_DIR:$TOPDIR/app/share/llvm/:$TOPDIR/app/usr/lib/x86_64-linux-gnu/cmake/
export CMAKE_MODULE_PATH=$TOPDIR/app/usr/lib/x86_64-linux-gnu/cmake/

# if the library path doesn't point to our usr/lib, linking will be broken and we won't find all deps either
export LD_LIBRARY_PATH=/usr/lib64/:/usr/lib:$TOPDIR/app/usr/lib
export C_INCLUDE_PATH=""
export CPLUS_INCLUDE_PATH=""
export LIBRARY_PATH=""
export PKG_CONFIG_PATH=""

# Workaround for: On CentOS 6, .pc files in /usr/lib/pkgconfig are not recognized
# However, this is where .pc files get installed when bulding libraries... (FIXME)
# I found this by comparing the output of librevenge's "make install" command
# between Ubuntu and CentOS 6
#FIXME
#ln -sf /usr/share/pkgconfig /usr/lib/pkgconfig

# Get kdevplatform
if [ ! -d "$TOPDIR/kdevplatform" ] ; then
	git clone --depth 1 http://anongit.kde.org/kdevplatform.git $TOPDIR/kdevplatform
fi
cd $TOPDIR/kdevplatform/
git_pull_rebase_helper
git checkout $KDEVELOP_VERSION

# Get kdevelop
if [ ! -d $TOPDIR/kdevelop ] ; then
	git clone --depth 1 http://anongit.kde.org/kdevelop.git $TOPDIR/kdevelop
fi
cd $TOPDIR/kdevelop
git_pull_rebase_helper
git checkout $KDEVELOP_VERSION

# Get kdev-python
if [ ! -d $TOPDIR/kdev-python ] ; then
    git clone --depth 1 http://anongit.kde.org/kdev-python.git $TOPDIR/kdev-python
fi
cd $TOPDIR/kdev-python/
git_pull_rebase_helper
git checkout $KDEVELOP_VERSION

# Get kdev-pg-qt
if [ ! -d $TOPDIR/kdevelop-pg-qt ] ; then
    git clone --depth 1 http://anongit.kde.org/kdevelop-pg-qt $TOPDIR/kdevelop-pg-qt
fi
cd $TOPDIR/kdevelop-pg-qt
git_pull_rebase_helper
git checkout $KDEV_PG_QT_VERSION

# Get kdev-php
if [ ! -d $TOPDIR/kdev-php ] ; then
    git clone --depth 1 http://anongit.kde.org/kdev-php $TOPDIR/kdev-php
fi
cd $TOPDIR/kdev-php
git_pull_rebase_helper
git checkout $KDEVELOP_VERSION

# Get Grantlee
if [ ! -d $TOPDIR/grantlee ]; then
    git clone --depth=1 https://github.com/steveire/grantlee.git $TOPDIR/grantlee
fi
cd $TOPDIR/grantlee
git checkout master
git_pull_rebase_helper
git checkout $GRANTLEE_VERSION

# Prepare the install location
rm -rf $TOPDIR/app || true
mkdir -p $TOPDIR/app/usr

#FIXME
#export LLVM_ROOT=/opt/llvm/

# make sure lib and lib64 are the same thing
mkdir -p $TOPDIR/app/usr/lib
cd  $TOPDIR/app/usr
ln -s lib lib64

# start building the deps

function build_framework
{ (
    # errors fatal
    echo "Compiler version:" $(g++ --version)
    set -e

    SRC=$TOPDIR/kf5
    BUILD=$TOPDIR/kf5/build
    PREFIX=$TOPDIR/app/usr/

    # framework
    FRAMEWORK=$1

    # clone if not there
    mkdir -p $SRC
    cd $SRC
    if ( test -d $FRAMEWORK )
    then
        echo "$FRAMEWORK already cloned"
        cd $FRAMEWORK
        git reset --hard
        git checkout master
        git pull --rebase
        git fetch --tags
        cd ..
    else
        git clone git://anongit.kde.org/$FRAMEWORK
    fi

    cd $FRAMEWORK
    git checkout $KF5_VERSION || git checkout $KDE_APPLICATION_VERSION
    cd ..

    if [ "$FRAMEWORK" = "knotifications" ]; then
	cd $FRAMEWORK
        echo "patching knotifications"
	git reset --hard
	cat > no_phonon.patch << EOF
diff --git a/CMakeLists.txt b/CMakeLists.txt
index b97425f..8f15f08 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -59,10 +59,10 @@ find_package(KF5Config ${KF5_DEP_VERSION} REQUIRED)
 find_package(KF5Codecs ${KF5_DEP_VERSION} REQUIRED)
 find_package(KF5CoreAddons ${KF5_DEP_VERSION} REQUIRED)

-find_package(Phonon4Qt5 4.6.60 REQUIRED NO_MODULE)
+find_package(Phonon4Qt5 4.6.60 NO_MODULE)
 set_package_properties(Phonon4Qt5 PROPERTIES
    DESCRIPTION "Qt-based audio library"
-   TYPE REQUIRED
+   TYPE OPTIONAL
    PURPOSE "Required to build audio notification support")
 if (Phonon4Qt5_FOUND)
   add_definitions(-DHAVE_PHONON4QT5)
EOF
	cat no_phonon.patch |patch -p1
	cd ..
    fi

    # create build dir
    mkdir -p $BUILD/$FRAMEWORK

    # go there
    cd $BUILD/$FRAMEWORK

    # cmake it
    cmake $SRC/$FRAMEWORK $CMAKE_GENERATOR \
          -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX \
          -DBUILD_TESTING=FALSE \
          -DCMAKE_BUILD_TYPE=RelWithDebInfo \
          $2

    # make
    #make -j$PARALLEL_JOBS
    ninja

    # install
    #make install
    ninja install
) }

build_framework extra-cmake-modules
build_framework kconfig
build_framework kguiaddons
build_framework ki18n
build_framework kitemviews
build_framework sonnet
build_framework kwindowsystem
build_framework kwidgetsaddons
build_framework kcompletion
build_framework kdbusaddons
build_framework karchive
build_framework kcoreaddons
build_framework kjobwidgets
build_framework kcrash
build_framework kservice
build_framework kcodecs
build_framework kauth
build_framework kconfigwidgets
build_framework kiconthemes
build_framework ktextwidgets
build_framework kglobalaccel
build_framework kxmlgui
build_framework kbookmarks
build_framework solid
build_framework kio
build_framework kparts
build_framework kitemmodels
build_framework threadweaver
build_framework attica
build_framework knewstuff
build_framework ktexteditor
build_framework kpackage
build_framework kdeclarative
build_framework kcmutils
build_framework knotifications
build_framework knotifyconfig
build_framework libkomparediff2
build_framework kdoctools
build_framework breeze-icons -DBINARY_ICONS_RESOURCE=1
build_framework kpty
build_framework kinit
build_framework konsole

cd $TOPDIR/grantlee
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$TOPDIR/app/usr/ $CMAKE_GENERATOR
ninja
ninja install

# Build kdev-pg-qt
mkdir -p $TOPDIR/kdevelop-pg-qt_build
cd $TOPDIR/kdevelop-pg-qt_build
cmake ../kdevelop-pg-qt \
    -DCMAKE_INSTALL_PREFIX:PATH=$TOPDIR/app/usr \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    $CMAKE_GENERATOR
ninja
ninja install

# Build KDevPlatform
mkdir -p $TOPDIR/kdevplatform_build
cd $TOPDIR/kdevplatform_build
cmake ../kdevplatform \
    -DCMAKE_INSTALL_PREFIX:PATH=$TOPDIR/app/usr/ \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_TESTING=FALSE \
    $CMAKE_GENERATOR
#make -j$PARALLEL_JOBS
#make install
ninja
ninja install
# no idea why this is required but otherwise kdevelop picks it up and fails
rm -f $TOPDIR/kdevplatform_build/KDevPlatformConfig.cmake

# Build KDevelop
mkdir -p $TOPDIR/kdevelop_build
cd $TOPDIR/kdevelop_build
cmake ../kdevelop \
    -DCMAKE_INSTALL_PREFIX:PATH=$TOPDIR/app/usr/ \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_TESTING=FALSE \
    $CMAKE_GENERATOR
#make -j$PARALLEL_JOBS
#make install
ninja
ninja install
rm -f $TOPDIR/kdevelop_build/KDevelopConfig.cmake

# for python
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TOPDIR/app/usr/lib/
# Build kdev-python
mkdir -p $TOPDIR/kdev-python_build
cd $TOPDIR/kdev-python_build
cmake ../kdev-python \
    -DCMAKE_INSTALL_PREFIX:PATH=$TOPDIR/app/usr/ \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_TESTING=FALSE \
    $CMAKE_GENERATOR
#make -j$PARALLEL_JOBS
#make install
ninja
ninja install

# Build kdev-php
mkdir -p $TOPDIR/kdev-php_build
cd $TOPDIR/kdev-php_build
cmake ../kdev-php \
    -DCMAKE_INSTALL_PREFIX:PATH=$TOPDIR/app/usr/ \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    $CMAKE_GENERATOR
ninja
ninja install

exit 0
