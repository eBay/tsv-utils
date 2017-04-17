#! /bin/sh

if [ $# -le 1 ]; then
    echo "Insufficient arguments. A program name and output director are required."
    exit 1
fi

prog=$1
shift
odir=$1
echo "Testing ${prog}, output to ${odir}"

## Three args: program, args, output file
runtest () {
    echo "" >> $3
    echo "====[tsv-filter $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

# Numeric field tests
echo "" >> ${basic_tests_1}; echo "====Numeric tests===" >> ${basic_tests_1}

runtest ${prog} "--header --eq 2:1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-H --eq 2:1 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 2:1. input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 2:1.0 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 2:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 2:-100 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 1:0 --eq 2:100 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 1:0 --ne 2:100 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --le 2:101 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --lt 2:101 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ge 2:101 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --gt 2:101 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ne 2:101 input1.tsv" ${basic_tests_1}

# Empty and blank field tests
echo "" >> ${basic_tests_1}; echo "====Empty and blank field tests===" >> ${basic_tests_1}

runtest ${prog} "--header --empty 3 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 1:100 --empty 3 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 1:100 --empty 4 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 1:100 --not-empty 3 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --eq 1:100 --not-empty 4 input1.tsv" ${basic_tests_1}

runtest ${prog} "--header --empty 3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --not-empty 3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --blank 3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --not-blank 3 input2.tsv" ${basic_tests_1}

runtest ${prog} "--not-blank 1 input_onefield.txt" ${basic_tests_1}
runtest ${prog} "--not-empty 1 input_onefield.txt" ${basic_tests_1}
runtest ${prog} "--blank 1 input_onefield.txt" ${basic_tests_1}
runtest ${prog} "--empty 1 input_onefield.txt" ${basic_tests_1}

# Short circuit by order. Ensure not blank or "none" before numeric test.
echo "" >> ${basic_tests_1}; echo "====Short circuit tests===" >> ${basic_tests_1}
runtest ${prog} "--header --not-blank 1 --str-ne 1:none --eq 1:100 input_num_or_empty.tsv" ${basic_tests_1}
runtest ${prog} "--header --or --blank 1 --str-eq 1:none --eq 1:100 input_num_or_empty.tsv" ${basic_tests_1}
runtest ${prog} "--header --invert --not-blank 1 --str-ne 1:none --eq 1:100 input_num_or_empty.tsv" ${basic_tests_1}
runtest ${prog} "--header --invert --or --blank 1 --str-eq 1:none --eq 1:100 input_num_or_empty.tsv" ${basic_tests_1}

# Numeric type recognition and short circuiting.
runtest ${prog} "-H --is-numeric 2 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-finite 2 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-nan 2 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-infinity 2 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-numeric 2 --gt 2:10 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-numeric 2 --le 2:10 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-finite 2 --gt 2:10 input_numeric_tests.tsv" ${basic_tests_1}
runtest ${prog} "-H --is-finite 2 --le 2:10 input_numeric_tests.tsv" ${basic_tests_1}

# String field tests
echo "" >> ${basic_tests_1}; echo "====String tests===" >> ${basic_tests_1}

runtest ${prog} "--header --str-eq 3:a input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-eq 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-eq 3:abc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-eq 4:ABC input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-eq 3:ß input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-eq 3:àßc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-ne 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-le 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-lt 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-ge 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-gt 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-in-fld 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-in-fld 3:b --str-in-fld 4:b input1.tsv" ${basic_tests_1}

runtest ${prog} "--header --istr-eq 4:ABC input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-eq 4:aBc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-eq 4:ÀSSC input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-eq 4:àssc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-eq 3:ß input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-eq 3:ẞ input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-eq 3:ÀßC input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-ne 4:ABC input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-ne 4:ÀSSC input1.tsv" ${basic_tests_1}

runtest ${prog} "--header --istr-in-fld 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-in-fld 3:B input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-in-fld 4:Sc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-in-fld 4:àsSC input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-in-fld 3:ẞ input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-not-in-fld 3:B input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-not-in-fld 4:Sc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --istr-not-in-fld 4:àsSC input1.tsv" ${basic_tests_1}

## Can't pass single quotes to runtest
echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --str-in-fld '3: ' input1.tsv]====" >> ${basic_tests_1}
${prog} --header --str-in-fld '3: ' input1.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --str-in-fld '4:abc def' input1.tsv]====" >> ${basic_tests_1}
${prog} --header --str-in-fld '4:abc def' input1.tsv >> ${basic_tests_1} 2>&1

runtest ${prog} "--header --str-in-fld 3:ß input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-not-in-fld 3:b input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --str-not-in-fld 3:b --str-not-in-fld 4:b input1.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --str-not-in-fld '3: ' input1.tsv]====" >> ${basic_tests_1}
${prog} --header --str-not-in-fld '3: ' input1.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --str-not-in-fld '4:abc def' input1.tsv]====" >> ${basic_tests_1}
${prog} --header --str-not-in-fld '4:abc def' input1.tsv >> ${basic_tests_1} 2>&1

runtest ${prog} "--header --str-not-in-fld 3:ß input1.tsv" ${basic_tests_1}

# Regular expression tests
echo "" >> ${basic_tests_1}; echo "====Regular expressions===" >> ${basic_tests_1}

runtest ${prog} "--header --regex 4:Às*C input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --regex 4:^A[b|B]C$ input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --iregex 4:abc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --iregex 3:ß input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --regex 3:ß input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --iregex 4:ß input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --regex 1:^\-[0-9]+ input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --not-iregex 4:abc input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --not-regex 4:z|d input1.tsv" ${basic_tests_1}

# Field vs Field tests
echo "" >> ${basic_tests_1}; echo "====Field vs Field===" >> ${basic_tests_1}

runtest ${prog} "--header --ff-eq 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-ne 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-le 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-lt 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-ge 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-gt 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-str-eq 3:4 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-str-ne 3:4 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-istr-eq 3:4 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-istr-ne 3:4 input1.tsv" ${basic_tests_1}

runtest ${prog} "--header --ff-absdiff-le 1:2:0.01 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-absdiff-le 2:1:0.01 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-absdiff-le 1:2:0.02 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-absdiff-gt 1:2:0.01 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-absdiff-gt 1:2:0.02 input2.tsv" ${basic_tests_1}

runtest ${prog} "--header --ff-reldiff-le 1:2:1e-5 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-reldiff-le 1:2:1e-6 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-reldiff-le 1:2:1e-7 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-reldiff-gt 1:2:1e-5 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-reldiff-gt 1:2:1e-6 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header --ff-reldiff-gt 1:2:1e-7 input2.tsv" ${basic_tests_1}

# No Header tests
echo "" >> ${basic_tests_1}; echo "====No header===" >> ${basic_tests_1}
runtest ${prog} "--str-in-fld 2:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--str-eq 3:a input1.tsv" ${basic_tests_1}

# OR clause tests
echo "" >> ${basic_tests_1}; echo "====OR clause tests===" >> ${basic_tests_1}
runtest ${prog} "--header --or --eq 1:0 --eq 2:101 --str-in-fld 4:def input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --or --le 1:-0.5 --ge 2:101.5 input1.tsv" ${basic_tests_1}

# Invert tests
echo "" >> ${basic_tests_1}; echo "====Invert tests===" >> ${basic_tests_1}
runtest ${prog} "--header --invert --ff-ne 1:2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --invert --eq 1:0 --eq 2:100 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --invert --or --eq 1:0 --eq 2:101 --str-in-fld 4:def input1.tsv" ${basic_tests_1}
runtest ${prog} "--header --invert --or --le 1:-0.5 --ge 2:101.5 input1.tsv" ${basic_tests_1}

# Alternate delimiter tests
echo "" >> ${basic_tests_1}; echo "====Alternate delimiter===" >> ${basic_tests_1}
runtest ${prog} "--header --delimiter | --eq 2:1 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --eq 2:-100 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --eq 1:0 --eq 2:100 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --empty 3 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --eq 1:100 --empty 3 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --eq 1:100 --empty 4 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --eq 1:100 --not-empty 4 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --gt 2:101 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --ne 2:101 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --str-eq 3:a input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --str-eq 3:ß input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --str-eq 3:àßc input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --str-ne 3:b input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --str-lt 3:b input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --str-in-fld 3:b input2_pipe-sep.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --delimiter | --str-in-fld '3: ' input2_pipe-sep.tsv]====" >> ${basic_tests_1}
${prog} --header --delimiter '|' --str-in-fld '3: ' input2_pipe-sep.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --delimiter | --str-in-fld '4:abc def' input2_pipe-sep.tsv]====" >> ${basic_tests_1}
${prog} --header --delimiter '|' --str-in-fld '4:abc def' input2_pipe-sep.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-filter --header --delimiter | --str-not-in-fld '3: ' input2_pipe-sep.tsv]====" >> ${basic_tests_1}
${prog} --header --delimiter '|' --str-not-in-fld '3: ' input2_pipe-sep.tsv >> ${basic_tests_1} 2>&1

runtest ${prog} "--header --delimiter | --ff-eq 1:2 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --ff-ne 1:2 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --ff-le 1:2 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --ff-str-eq 3:4 input2_pipe-sep.tsv" ${basic_tests_1}
runtest ${prog} "--header --delimiter | --ff-str-ne 3:4 input2_pipe-sep.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====Multi-file & stdin Tests===" >> ${basic_tests_1}
runtest ${prog} "--header --ge 2:23 input_3x2.tsv input_emptyfile.tsv input_3x1.tsv input_3x0.tsv input_3x3.tsv" ${basic_tests_1}

## runtest can't do these. Generate them directly.
echo "" >> ${basic_tests_1}; echo "====[cat input_3x2.tsv | tsv-filter --header --ge 2:23]====" >> ${basic_tests_1}
cat input_3x2.tsv | ${prog} --header --ge 2:23 >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input_3x2.tsv | tsv-filter --header --ge 2:23 -- input_3x3.tsv - input_3x1.tsv]====" >> ${basic_tests_1}
cat input_3x2.tsv | ${prog} --header --ge 2:23 -- input_3x3.tsv - input_3x1.tsv >> ${basic_tests_1} 2>&1

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[tsv-filter --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-filter --version | grep -c 'tsv-filter (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'tsv-filter (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1

echo "====[tsv-filter -V | grep -c 'tsv-filter (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'tsv-filter (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1


## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "--header --le 2:10 nosuchfile.tsv" ${error_tests_1}
runtest ${prog} "--header --gt 0:10 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --lt -1:10 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ne abc:15 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --eq 2:def input1.tsv" ${error_tests_1}
runtest ${prog} "--header --le 1000:10 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --empty 23g input1.tsv" ${error_tests_1}
runtest ${prog} "--header --str-gt 0:abc input1.tsv" ${error_tests_1}
runtest ${prog} "--header --str-lt -1:ABC input1.tsv" ${error_tests_1}
runtest ${prog} "--header --str-ne abc:a22 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --str-eq 2.2:def input1.tsv" ${error_tests_1}
runtest ${prog} "--header --regex z:^A[b|B]C$ input1.tsv" ${error_tests_1}
runtest ${prog} "--header --iregex a:^A[b|B]C$ input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-gt 0:1 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-lt -1:2 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-ne abc:3 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-eq 2.2:4 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-le 2:3.1 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-str-ne abc:3 input1.tsv" ${error_tests_1}
runtest ${prog} "--header --ff-str-eq 2.2:4 input1.tsv" ${error_tests_1}

exit $?
