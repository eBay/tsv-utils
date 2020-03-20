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

mkdir -p odir

$prog --dir odir profile_data_1.tsv --lines-per-file 10        ; rm odir/*
$prog --dir odir profile_data_1.tsv --lines-per-file 100       ; rm odir/*
$prog --dir odir profile_data_1.tsv --num-files 5              ; rm odir/*
$prog --dir odir profile_data_1.tsv --num-files 50             ; rm odir/*
$prog --dir odir profile_data_1.tsv --num-files 5 -k 1         ; rm odir/*
$prog --dir odir profile_data_1.tsv --num-files 50 -k 1        ; rm odir/*

$prog --dir odir profile_data_2.tsv --lines-per-file 500       ; rm odir/*
$prog --dir odir profile_data_2.tsv --lines-per-file 20 -H     ; rm odir/*
$prog --dir odir profile_data_2.tsv --num-files 100 -H         ; rm odir/*
$prog --dir odir profile_data_2.tsv --num-files 100 -I         ; rm odir/*
$prog --dir odir profile_data_2.tsv --num-files 5 -k 1         ; rm odir/*
cat profile_data_2.tsv | $prog --dir odir --lines-per-file 100 -I    ; rm odir/*
cat profile_data_2.tsv | $prog --dir odir --num-files 100 -I         ; rm odir/*
cat profile_data_2.tsv | $prog --dir odir --num-files 100 -k 2,4 -I  ; rm odir/*
cat profile_data_2.tsv | $prog --dir odir --num-files 100 -k 1,3 -H  ; rm odir/*

$prog --dir odir profile_data_3.tsv --lines-per-file 300       ; rm odir/*
$prog --dir odir profile_data_3.tsv --num-files 200 --max-open-files 20          ; rm odir/*
$prog --dir odir profile_data_3.tsv --num-files 200 -k 4 --max-open-files 20     ; rm odir/*
$prog --dir odir profile_data_3.tsv --num-files 200 -k 2,3 --max-open-files 100  ; rm odir/*

$prog --dir odir --lines-per-file 1000 profile_data_1.tsv profile_data_2.tsv profile_data_3.tsv ; rm odir/*
$prog --dir odir --num-files 100 profile_data_1.tsv profile_data_2.tsv profile_data_3.tsv ; rm odir/*
$prog --dir odir --num-files 100 -k 1,2 profile_data_1.tsv profile_data_2.tsv profile_data_3.tsv ; rm odir/*

rmdir odir

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
