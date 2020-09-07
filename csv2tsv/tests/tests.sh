#!/usr/bin/env bash

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
runtest ${prog} "input_unicode.csv" ${basic_tests_1}
runtest ${prog} "input_bom.csv" ${basic_tests_1}
runtest ${prog} "input_bom.csv input_bom.csv" ${basic_tests_1}
runtest ${prog} "-H input_bom.csv input_bom.csv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[cat header3.csv | csv2tsv --header -- header1.csv header2.csv - header4.csv header5.csv]====" >> ${basic_tests_1}
cat header3.csv | ${prog} --header -- header1.csv header2.csv - header4.csv header5.csv >> ${basic_tests_1} 2>&1

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[csv2tsv --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[csv2tsv --help-verbose | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help-verbose 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[csv2tsv --version | grep -c 'csv2tsv (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'csv2tsv (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

echo "====[csv2tsv -V | grep -c 'csv2tsv (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'csv2tsv (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "nosuchfile.txt" ${error_tests_1}
runtest ${prog} "--nosuchparam input1.txt" ${error_tests_1}

## The newline character doesn't pass through the runtest function
## correctly, so the next couple tests write directly to the output file.
##
echo ""  >> ${error_tests_1}; echo "====[csv2tsv --quote $'\n' input2.csv]====" >> ${error_tests_1}
${prog} --quote $'\n' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --quote $'\r' input2.csv]====" >> ${error_tests_1}
${prog} --quote $'\r' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --csv-delim $'\n' input2.csv]====" >> ${error_tests_1}
${prog} --csv-delim $'\n' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --csv-delim $'\r' input2.csv]====" >> ${error_tests_1}
${prog} --csv-delim $'\r' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --tsv-delim $'\n' input2.csv]====" >> ${error_tests_1}
${prog} --tsv-delim $'\n' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --tsv-delim $'\r' input2.csv]====" >> ${error_tests_1}
${prog} --tsv-delim $'\r' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --replacement $'\n' input2.csv]====" >> ${error_tests_1}
${prog} --replacement $'\n' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv --replacement $'\r' input2.csv]====" >> ${error_tests_1}
${prog} --replacement $'\r' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv -r $'__\n__' input2.csv]====" >> ${error_tests_1}
${prog} -r $'__\n__' input2.csv >> ${error_tests_1} 2>&1

echo ""  >> ${error_tests_1}; echo "====[csv2tsv -r $'__\r__' input2.csv]====" >> ${error_tests_1}
${prog} -r $'__\r__' input2.csv >> ${error_tests_1} 2>&1


runtest ${prog} "-q x -c x input2.csv" ${error_tests_1}
runtest ${prog} "-q x -t x input2.csv" ${error_tests_1}
runtest ${prog} "-t x -r wxyz input2.csv" ${error_tests_1}
runtest ${prog} "invalid1.csv" ${error_tests_1}
runtest ${prog} "invalid2.csv" ${error_tests_1}
