#!/bin/sh
echo "1..1"
rootdir=`dirname $0`/../..
tempdir=`perl -MFile::Temp=tempdir -e 'print tempdir("TEST-XX"."XX"."XX", TMPDIR => 1)'`
mkdir -p "$tempdir"

echo "
storage_set abc
  .hoge -- hoge.fuga.11
  .fuga -- aa.bb.cc
" > "$tempdir/hoge.txt"

echo '
{
  "hoge.fuga.11": 33113,
  "fuga": "aa bb",
  "aa.bb.cc": "aa   vv"
}
' > "$tempdir/fuga2.json"

echo "storage_set abc
  .fuga = aa   vv
  .hoge = 33113" > "$tempdir/expected.txt"

"$rootdir/perl" "$rootdir/bin/dango.pl" "$tempdir/hoge.txt" \
    --config-json-file-name "$tempdir/fuga2.json" \
    --print-as-testable > "$tempdir/parsed.txt" #2> /dev/null

(diff -u "$tempdir/parsed.txt" "$tempdir/expected.txt" && echo "ok 1") || echo "not ok 1"

rm -fr "$tempdir"
