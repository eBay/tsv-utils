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
$prog profile_data_1.tsv -H --compatibility-mode > /dev/null
$prog profile_data_1.tsv --compatibility-mode > /dev/null
$prog profile_data_1.tsv -H -n 100 > /dev/null
$prog profile_data_1.tsv -H -n 100 --prefer-algorithm-r > /dev/null
$prog profile_data_1.tsv -H -p 0.05 > /dev/null
$prog profile_data_1.tsv -H -p 0.01 > /dev/null
$prog profile_data_1.tsv -p 0.25 > /dev/null
$prog profile_data_1.tsv -H -p 0.10 -n 50 > /dev/null
$prog profile_data_1.tsv -H -k 1 -p 0.20 > /dev/null
$prog profile_data_1.tsv -H -w 7 > /dev/null
$prog profile_data_1.tsv -H -w 1 -n 200 > /dev/null
$prog profile_data_1.tsv -H --gen-random-inorder > /dev/null
$prog profile_data_1.tsv -H --replace -n 200 > /dev/null
cat profile_data_1.tsv | $prog -H > /dev/null

$prog profile_data_2.tsv > /dev/null
$prog profile_data_2.tsv --compatibility-mode > /dev/null
$prog profile_data_2.tsv -n 200 > /dev/null
$prog profile_data_2.tsv -n 200 --prefer-algorithm-r > /dev/null
$prog profile_data_2.tsv -H -n 300 > /dev/null
$prog profile_data_2.tsv -H -n 300 --prefer-algorithm-r > /dev/null
$prog profile_data_2.tsv -p 0.10 > /dev/null
$prog profile_data_2.tsv -p 0.01 > /dev/null
$prog profile_data_2.tsv -k 1 -p 0.30 > /dev/null
$prog profile_data_2.tsv -w 3 -n 250 > /dev/null
$prog profile_data_2.tsv -w 4 > /dev/null
$prog profile_data_2.tsv -w 2 > /dev/null
$prog profile_data_2.tsv -w 2 -n 400 > /dev/null
$prog profile_data_2.tsv -w 3 --gen-random-inorder > /dev/null
$prog profile_data_2.tsv --gen-random-inorder > /dev/null
$prog profile_data_2.tsv -p 0.25 > /dev/null
$prog profile_data_2.tsv -p 0.75 -n 200 > /dev/null
$prog profile_data_2.tsv -n 250 > /dev/null
$prog profile_data_2.tsv --replace -n 250 > /dev/null
cat profile_data_2.tsv | $prog -H > /dev/null

$prog profile_data_3.tsv -H > /dev/null
$prog profile_data_3.tsv > /dev/null
$prog profile_data_3.tsv --compatibility-mode > /dev/null
$prog profile_data_3.tsv -H -n 500 > /dev/null
$prog profile_data_3.tsv -H -n 500 --prefer-algorithm-r > /dev/null
$prog profile_data_3.tsv -H -p 0.01 > /dev/null
$prog profile_data_3.tsv -H -p 0.001 > /dev/null
$prog profile_data_3.tsv -p 0.5 > /dev/null
$prog profile_data_3.tsv -H -p 0.05 > /dev/null
$prog profile_data_3.tsv -H -k 1,3 -p 0.20 > /dev/null
$prog profile_data_3.tsv -H -k 1 -p 0.25 > /dev/null
$prog profile_data_3.tsv -H -w 2 > /dev/null
$prog profile_data_3.tsv -H -w 8 -n 400 > /dev/null
$prog profile_data_3.tsv -H -k 1 -p 0.75 > /dev/null
$prog profile_data_3.tsv -H -k 3 -p 0.05 --gen-random-inorder > /dev/null
$prog profile_data_3.tsv -H -w 7 > /dev/null
$prog profile_data_3.tsv -H -w 6 -n 900 > /dev/null
$prog profile_data_3.tsv -H --gen-random-inorder > /dev/null
$prog profile_data_3.tsv -H -w 8 --gen-random-inorder > /dev/null
$prog profile_data_3.tsv -H -p 0.2 > /dev/null
$prog profile_data_3.tsv -H -p 0.4 -n 100 > /dev/null
$prog profile_data_3.tsv -H -n 500 > /dev/null
$prog profile_data_3.tsv -n 250 > /dev/null
$prog profile_data_3.tsv -n 750 > /dev/null
$prog profile_data_3.tsv -n 750 --prefer-algorithm-r > /dev/null
$prog profile_data_3.tsv -n 750 --replace > /dev/null
cat profile_data_3.tsv | $prog -H > /dev/null

cat profile_data_1.tsv | $prog -- - profile_data_2.tsv profile_data_3.tsv > /dev/null
cat profile_data_1.tsv | $prog -n 500 --replace -- - profile_data_2.tsv profile_data_3.tsv > /dev/null

$prog profile_data_1.tsv profile_data_2.tsv profile_data_3.tsv > /dev/null
$prog profile_data_2.tsv profile_data_3.tsv profile_data_1.tsv > /dev/null
$prog profile_data_3.tsv -H profile_data_1.tsv profile_data_2.tsv > /dev/null

$prog --prob 0.01 profile_data_3.tsv profile_data_1.tsv profile_data_2.tsv > /dev/null
$prog -H -v 7 --prob 0.02 --num 25 profile_data_2.tsv profile_data_3.tsv profile_data_1.tsv > /dev/null

cat profile_data_1.tsv | $prog -n 500 --prefer-algorithm-r -- - profile_data_2.tsv profile_data_3.tsv > /dev/null

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
