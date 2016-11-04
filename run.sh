#!/usr/bin/env bash
TOPDIR=$(pwd)
export QML2_IMPORT_PATH=$TOPDIR/usr/lib/x86_64-linux-gnu/qml:$QML2_IMPORT_PATH
export LD_LIBRARY_PATH=$TOPDIR/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export QT_PLUGIN_PATH=$TOPDIR/app/usr/lib/x86_64-linux-gnu/plugins/
export XDG_DATA_DIRS=$TOPDIR/app/usr/share/:$XDG_DATA_DIRS
export PATH=$TOPDIR/app/usr/bin:$PATH
export KDE_FORK_SLAVES=1
kdevelop
#qtcreator -debug $(which kdevelop)
