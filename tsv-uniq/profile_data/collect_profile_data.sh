#! /bin/sh

if [ $# -eq 0 ]; then
    echo "Insufficient arguments. The path of the instrumented program is required."
    exit 1
fi

prog=$1
shift

ldc_profdata_tool_name=ldc-profdata
ldc_profdata_tool=${ldc_profdata_tool_name}

if [ $# -ne 0 ]; then
   ldc_profdata_tool=${1}/bin/${ldc_profdata_tool_name}
fi

for f in profile.*.raw; do
    if [ -e $f ]; then
        rm $f
    fi
done

if [ -e app.profdata ]; then
   rm -f app.profdata
fi

$prog profile_data_1.tsv  > /dev/null
$prog profile_data_1.tsv -H > /dev/null
$prog profile_data_1.tsv -i > /dev/null
$prog profile_data_1.tsv -f 1 > /dev/null
$prog profile_data_1.tsv -f 3 > /dev/null
$prog profile_data_1.tsv -H -f 1,3 > /dev/null
$prog profile_data_1.tsv -H -i -f 2,3,4 > /dev/null

$prog profile_data_2.tsv  > /dev/null
$prog profile_data_2.tsv -f 1 > /dev/null
$prog profile_data_2.tsv -f 2 > /dev/null
$prog profile_data_2.tsv  > /dev/null
$prog profile_data_2.tsv -H -i > /dev/null
$prog profile_data_2.tsv  > /dev/null

$prog profile_data_3.tsv  > /dev/null
$prog profile_data_3.tsv -f 1 > /dev/null
$prog profile_data_3.tsv -H -f 3 > /dev/null
$prog profile_data_3.tsv  > /dev/null
$prog profile_data_3.tsv -i > /dev/null
$prog profile_data_3.tsv -f 2 > /dev/null
$prog profile_data_3.tsv -i -f 3 > /dev/null

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
