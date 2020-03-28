#!/usr/bin/env bash

if [ $# -le 1 ]; then
    echo "Insufficient arguments. A program name and output directory are required."
    exit 1
fi

prog=$1
shift
odir=$1
echo "Testing ${prog}, output to ${odir}"

## Three args: program, args, output file
runtest () {
    echo "" >> $3
    echo "====[tsv-select $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

# Individual fields only
runtest ${prog} "--fields 1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3,1,4 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,3,2,1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,1 --rest none input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3,2 -r none input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,2 -r none input1.tsv" ${basic_tests_1}

# Field ranges
runtest ${prog} "-f 2-3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4-1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2-2 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2-3,1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2-3,1,4-3 input1.tsv" ${basic_tests_1}

# --rest first
runtest ${prog} "--fields 1 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,3 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2-3 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,3 -r first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3,1,4 -r first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,3,2,1 -r first input1.tsv" ${basic_tests_1}

# --rest last
runtest ${prog} "--fields 1 --rest last input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3 --rest last input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,3 --rest last input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,3 -r last input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3,1,4 -r last input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 4,3,2,1 -r last input1.tsv" ${basic_tests_1}

# Exclusions - Individual fields and ranges
runtest ${prog} "--exclude 1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 4 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1,2 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2-1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2,3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 4,3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1,3-4 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1-4 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1-5 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 5-10 input1.tsv" ${basic_tests_1}

# Exclusions - Combined with --fields and --rest
runtest ${prog} "-e 1,2 --rest last input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1,2 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1 -f 3 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1 -f 3 --rest last input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 1 -f 3 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2 -f 4,1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2 -f 4,1 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2,3 -f 4,1 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2,3 -f 4,1 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 2,3,5 -f 4,1 input1.tsv" ${basic_tests_1}

# 1 field file
runtest ${prog} "-f 1 input_1field.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest first input_1field.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest last input_1field.tsv" ${basic_tests_1}
runtest ${prog} "--exclude 1 input_1field.tsv" ${basic_tests_1}

# 2 field file
runtest ${prog} "-f 1 input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest first input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest last input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 --rest first input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 --rest last input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 --rest first input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 --rest last input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1 input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1 --rest first input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1 --rest last input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 1 input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 2 input_2fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 1-2 input_2fields.tsv" ${basic_tests_1}

# 3+ field file
runtest ${prog} "-f 1 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 3 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,3 --rest first input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest first input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 3,1 --rest first input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 3,1,2 --rest first input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest last input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,3 --rest last input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1,3 --rest last input_3plus_fields.tsv" ${basic_tests_1}

runtest ${prog} "--exclude 1 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 3 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 1-3 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 4 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 5 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 4-10 input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 1 -f 3 --rest last input_3plus_fields.tsv" ${basic_tests_1}
runtest ${prog} "-e 1 -f 3 --rest first input_3plus_fields.tsv" ${basic_tests_1}

runtest ${prog} "-e 1048576 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 5-1048576 input1.tsv" ${basic_tests_1}
runtest ${prog} "-e 4-1048576 input1.tsv" ${basic_tests_1}

# Alternate delimiter
runtest ${prog} "-f 1 --delimiter ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 -d ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1 -d ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 -d ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 -d ^ --rest first input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 -d ^ --rest first input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1 -d ^ --rest first input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 -d ^ --rest first input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 -d ^ --rest last input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 2 -d ^ --rest last input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,1 -d ^ --rest last input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "-f 1,2 -d ^ --rest last input_2plus_hat_delim.tsv" ${basic_tests_1}

runtest ${prog} "--exclude 1 --delimiter ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "--exclude 2 --delimiter ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "--exclude 1-2 --delimiter ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "--exclude 3-10 --delimiter ^  input_2plus_hat_delim.tsv" ${basic_tests_1}
runtest ${prog} "--exclude 2 --fields 1 --rest first --delimiter ^  input_2plus_hat_delim.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====Multi-file & stdin Tests===" >> ${basic_tests_1}
runtest ${prog} "-f 2,1 input_3x2.tsv input_emptyfile.tsv input_3x1.tsv input_3x0.tsv input_3x3.tsv" ${basic_tests_1}

## runtest can't do these. Generate them directly.
echo "" >> ${basic_tests_1}; echo "====[cat input_3x2.tsv input_3x0.tsv | tsv-select -f 2,1]====" >> ${basic_tests_1}
cat input_3x2.tsv input_3x0.tsv | ${prog} -f 2,1 >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input_3x2.tsv | tsv-select -f 2,1 -- input_3x3.tsv - input_3x1.tsv]====" >> ${basic_tests_1}
cat input_3x2.tsv | ${prog} -f 2,1 -- input_3x3.tsv - input_3x1.tsv >> ${basic_tests_1} 2>&1

## Header line tests
runtest ${prog} "--header -f 1 input_header1.tsv" ${basic_tests_1}
runtest ${prog} "-H -f 2 input_header1.tsv input_header2.tsv input_header3.tsv input_header4.tsv" ${basic_tests_1}
runtest ${prog} "-H -f 1,2,3 input_header3.tsv input_header3.tsv input_header1.tsv" ${basic_tests_1}

runtest ${prog} "--header --exclude 1 input_header1.tsv" ${basic_tests_1}
runtest ${prog} "-H -e 2 input_header1.tsv input_header2.tsv input_header3.tsv input_header4.tsv" ${basic_tests_1}
runtest ${prog} "-H -e 1,2,3 input_header3.tsv input_header3.tsv input_header1.tsv" ${basic_tests_1}

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[tsv-select --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-select --help-verbose | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help-verbose 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-select --version | grep -c 'tsv-select (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'tsv-select (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

echo "====[tsv-select -V | grep -c 'tsv-select (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'tsv-select (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

## Longer output to trigger buffer flush

echo "" >> ${basic_tests_1}; echo "====[tsv-select -H -f 1,3,5,7,8 input_8xlong.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -f 1,3,5,7,8 input_8xlong.tsv | wc -l | tr -d ' ' >>  ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-select -H -f 1,3,5,7,8 input_8xlong.tsv input_8xlong.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -f 1,3,5,7,8 input_8xlong.tsv input_8xlong.tsv | wc -l | tr -d ' ' >>  ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-select -H -f 1,3,5 input_8xlong.tsv input_8xlong.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -f 1,3,5 input_8xlong.tsv input_8xlong.tsv | wc -l | tr -d ' ' >>  ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-select -H -f 3 input_8xlong.tsv input_8xlong.tsv input_8xlong.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -f 3 input_8xlong.tsv input_8xlong.tsv input_8xlong.tsv | wc -l | tr -d ' ' >>  ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "input1.tsv" ${error_tests_1}
runtest ${prog} "input1.tsv --rest last" ${error_tests_1}

# Disable this test until Phobos 2.071 is available on all compilers
# 2.071 changed the error message in a minor way.
runtest ${prog} "input1.tsv --fields last" ${error_tests_1}

runtest ${prog} "-f 0 input1.tsv" ${error_tests_1}
runtest ${prog} "input1.tsv -f 2 --rest elsewhere" ${error_tests_1}
runtest ${prog} "-f 1 nosuchfile.tsv" ${error_tests_1}
runtest ${prog} "-f 1,4 input_3plus_fields.tsv" ${error_tests_1}
runtest ${prog} "-d ß -f 1 input1.tsv" ${error_tests_1}
runtest ${prog} "-f 1 --nosuchparam input1.tsv" ${error_tests_1}

runtest ${prog} "-f 0-1 input1.tsv" ${error_tests_1}
runtest ${prog} "-f 2- input1.tsv" ${error_tests_1}
runtest ${prog} "-f 1,3- input1.tsv" ${error_tests_1}
runtest ${prog} "-f input1.tsv" ${error_tests_1}
runtest ${prog} "-f 1, input1.tsv" ${error_tests_1}
runtest ${prog} "-f 1.1 input1.tsv" ${error_tests_1}

runtest ${prog} "-e 0 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 1 -f 1 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 1-5 -f 3 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 7,10 -f 1,3,8-14 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 7,10 -f 1,3,8-14 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 1-1000 -f 2000-1000 input1.tsv" ${error_tests_1}

runtest ${prog} "-e 1048577 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 1048578 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 4-1048577 input1.tsv" ${error_tests_1}
runtest ${prog} "-e 4-1048578 input1.tsv" ${error_tests_1}

# Windows line ending detection
runtest ${prog} "-f 1 input1_dos.tsv" ${error_tests_1}
runtest ${prog} "-H -f 1 input1_dos.tsv" ${error_tests_1}

exit $?
