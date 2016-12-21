#! /bin/sh

# Note: Majority of testing for this app is in the unit tests built into the code.
# These tests do some basic, plus file handling and error cases.

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
    echo "====[csv2tsv $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

runtest ${prog} "input1_format1.csv" ${basic_tests_1}
runtest ${prog} "input1_format2.csv" ${basic_tests_1}
runtest ${prog} "input1_format3.csv" ${basic_tests_1}
runtest ${prog} "--quote # --csv-delim | --tsv-delim $ --replacement <==> input2.csv" ${basic_tests_1}
runtest ${prog} "-q # -c | -t @ -r <--> input2.csv" ${basic_tests_1}
runtest ${prog} "header1.csv header2.csv header3.csv header4.csv header5.csv" ${basic_tests_1}
runtest ${prog} "--header header1.csv header2.csv header3.csv header4.csv header5.csv" ${basic_tests_1}
runtest ${prog} "-H header1.csv header2.csv header3.csv header4.csv header5.csv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[cat header3.csv | csv2tsv --header -- header1.csv header2.csv - header4.csv header5.csv]====" >> ${basic_tests_1}
cat header3.csv | ${prog} --header -- header1.csv header2.csv - header4.csv header5.csv >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "nosuchfile.txt" ${error_tests_1}
runtest ${prog} "--nosuchparam input1.txt" ${error_tests_1}
runtest ${prog} "-q x -c x input2.csv" ${error_tests_1}
runtest ${prog} "-q x -t x input2.csv" ${error_tests_1}
runtest ${prog} "-t x -r wxyz input2.csv" ${error_tests_1}
