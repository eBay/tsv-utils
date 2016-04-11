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
    echo "====[tsv-select $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

## Note: input1.tsv has duplicate values in fields 2 & 3. Tests with those fields
## as keys that have append values need to use --allow-duplicate-keys (unless
## testing error handling).

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

# --rest first
runtest ${prog} "--fields 1 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 3 --rest first input1.tsv" ${basic_tests_1}
runtest ${prog} "-f 2,3 --rest first input1.tsv" ${basic_tests_1}
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

# 1 field file
runtest ${prog} "-f 1 input_1field.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest first input_1field.tsv" ${basic_tests_1}
runtest ${prog} "-f 1 --rest last input_1field.tsv" ${basic_tests_1}

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

echo "" >> ${basic_tests_1}; echo "====Multi-file & stdin Tests===" >> ${basic_tests_1}
runtest ${prog} "-f 2,1 input_3x2.tsv input_emptyfile.tsv input_3x1.tsv input_3x0.tsv input_3x3.tsv" ${basic_tests_1}

## runtest can't do these. Generate them directly.
echo "" >> ${basic_tests_1}; echo "====[cat input_3x2.tsv input_3x0.tsv | tsv-select -f 2,1]====" >> ${basic_tests_1}
cat input_3x2.tsv input_3x0.tsv | ${prog} -f 2,1 >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input_3x2.tsv | tsv-select -f 2,1 -- input_3x3.tsv - input_3x1.tsv]====" >> ${basic_tests_1}
cat input_3x2.tsv | ${prog} -f 2,1 -- input_3x3.tsv - input_3x1.tsv >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "input1.tsv" ${error_tests_1}
runtest ${prog} "input1.tsv --rest last" ${error_tests_1}
runtest ${prog} "input1.tsv --fields last" ${error_tests_1}
runtest ${prog} "-f 0 input1.tsv" ${error_tests_1}
runtest ${prog} "input1.tsv -f 2 --rest elsewhere" ${error_tests_1}
runtest ${prog} "-f 1 nosuchfile.tsv" ${error_tests_1}
runtest ${prog} "-f 1,4 input_3plus_fields.tsv" ${error_tests_1}
runtest ${prog} "-d ß -f 1 input1.tsv" ${error_tests_1}
runtest ${prog} "-f 1 --nosuchparam input1.tsv" ${error_tests_1}

exit $?
