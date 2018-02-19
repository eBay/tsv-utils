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

$prog profile_data_1.tsv -H > /dev/null
$prog profile_data_1.tsv > /dev/null
$prog profile_data_1.tsv -H -n 100 > /dev/null
$prog profile_data_1.tsv -H -r 0.05 > /dev/null
$prog profile_data_1.tsv -r 0.25 > /dev/null
$prog profile_data_1.tsv -H -r 0.10 -n 50 > /dev/null
$prog profile_data_1.tsv -H -k 1 -r 0.20 > /dev/null
$prog profile_data_1.tsv -H -w 7 > /dev/null
$prog profile_data_1.tsv -H -w 1 -n 200 > /dev/null

$prog profile_data_2.tsv > /dev/null
$prog profile_data_2.tsv -n 200 > /dev/null
$prog profile_data_2.tsv -H -n 300 > /dev/null
$prog profile_data_2.tsv -r 0.10 > /dev/null
$prog profile_data_2.tsv -k 1 -r 0.30 > /dev/null
$prog profile_data_2.tsv -w 3 -n 250 > /dev/null

$prog profile_data_3.tsv -H > /dev/null
$prog profile_data_3.tsv > /dev/null
$prog profile_data_3.tsv -H -n 500 > /dev/null
$prog profile_data_3.tsv -H -r 0.01 > /dev/null
$prog profile_data_3.tsv -r 0.5 > /dev/null
$prog profile_data_3.tsv -H -r 0.05 > /dev/null
$prog profile_data_3.tsv -H -k 1,3 -r 0.20 > /dev/null
$prog profile_data_3.tsv -H -k 1 -r 0.25 > /dev/null
$prog profile_data_3.tsv -H -w 2 > /dev/null

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
