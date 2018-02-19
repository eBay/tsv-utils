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

$prog profile_data_1a.csv > /dev/null
$prog profile_data_1b.csv > /dev/null
$prog profile_data_3a.csv > /dev/null
$prog profile_data_3b.csv > /dev/null
$prog profile_data_5.csv > /dev/null

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
