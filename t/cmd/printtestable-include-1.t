#!/bin/sh
echo "1..1"
rootdir=`dirname $0`/../..
tempdir=`perl -MFile::Temp=tempdir -e 'print tempdir("TEST-XX"."XX"."XX", TMPDIR => 1)'`
mkdir -p "$tempdir/hoge"

echo "
include ./hoge/fuga.txt
include ./hoge/../fuga2.txt
" > "$tempdir/hoge.txt"

echo "
storage_set abc
" > "$tempdir/hoge/fuga.txt"
echo "
  db_set xyz
" > "$tempdir/fuga2.txt"

echo "storage_set abc
db_set xyz" > "$tempdir/expected.txt"

"$rootdir/perl" "$rootdir/bin/dango.pl" "$tempdir/hoge.txt" \
    --print-as-testable > "$tempdir/parsed.txt" 2> /dev/null

(diff -u "$tempdir/parsed.txt" "$tempdir/expected.txt" && echo "ok 1") || echo "not ok 1"

rm -fr "$tempdir"
