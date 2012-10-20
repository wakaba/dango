#!/bin/sh
echo "1..1"
rootdir=`dirname $0`/../..
tempdir=`perl -MFile::Temp=tempdir -e 'print tempdir("TEST-XX"."XX"."XX", TMPDIR => 1)'`
mkdir -p "$tempdir"

"$rootdir/perl" "$rootdir/bin/dango.pl" --help > "$tempdir/help.txt"

(grep OPTIONS "$tempdir/help.txt" > /dev/null && echo "ok 1") || echo "not ok 1"

rm -fr "$tempdir"
