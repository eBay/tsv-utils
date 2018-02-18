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

$prog profile_data_1.tsv -H --min 3,8,16 --max 3,8,16 --range 3,8,16 --sum 3,8,16 --mean 4,9,17 > /dev/null
$prog profile_data_1.tsv -H --median 19,5,11 --quantile 19,5:0.25,0.9 --mad 11,5 --var 8,9 --stdev 14,15 > /dev/null
$prog profile_data_2.tsv --group-by 1 --max 3,4 --median 3,4 --sum 3,4 > /dev/null
$prog profile_data_2.tsv --group-by 2 --mean 3,4 --median 3,4 --mad 3,4> /dev/null
$prog profile_data_3.tsv -H --unique-count 1,3 --missing-count 5 --not-missing-count 5 --unique-values 4 > /dev/null
$prog profile_data_3.tsv -H --group-by 1,3 --count --range 6-8 --median 6-8 > /dev/null
$prog profile_data_3.tsv -H --group-by 1 --count --retain 2 --first 6 --last 7 --mode 5 --mode-count 5 --values 3 > /dev/null

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
