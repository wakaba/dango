#!/bin/sh
echo "1..1"
rootdir=`dirname $0`/../..
tempdir=`perl -MFile::Temp=tempdir -e 'print tempdir("TEST-XX"."XX"."XX", TMPDIR => 1)'`
mkdir -p "$tempdir"

"$rootdir/perl" "$rootdir/bin/dango.pl" "$rootdir/sketch/define-storage-2.txt" \
    --fill-instance-prop=name,table_stem,timeline_type \
    --write-preparation-text "$tempdir/preparation.txt" 2> /dev/null

(diff -u "$tempdir/preparation.txt" "$rootdir/sketch/define-storage-2-preparation.txt" && echo "ok 1") || echo "not ok 1"
rm -fr "$tempdir"
