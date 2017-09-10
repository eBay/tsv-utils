#! /bin/sh

## Command line tests of the build executable

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
    echo "====[tsv-pretty $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

## Two args: cmd, output file
runcmd() {
    echo "" >> $2
    echo "===[$1]===" >> $2
    $1 >> $2 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Numeric file tests: With header" > ${basic_tests_1}
echo "-------------------------------" >> ${basic_tests_1}

runcmd "cat input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "--no-header input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "--header input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H --lookahead 0 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 2 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 5 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 6 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 7 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H --format-floats input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -f -l 0 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -f -l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H --precision 0 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 -l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 -l 1 input_numbers_1.tsv" ${basic_tests_1}

runcmd "cat input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-x input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 0 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 2 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 5 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 6 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 7 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -f input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -f -l 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 -l 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 -l 1 input_numbers_2.tsv" ${basic_tests_1}

runcmd "cat input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "--no-header input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 2 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 5 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 6 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 7 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -f input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -f -l 1 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 input_numbers_3.tsv" ${basic_tests_1}

runcmd "cat input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-x input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 0 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 2 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 4 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 5 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 6 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -f input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 input_numbers_4.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}
echo "Numeric file tests: Auto-detect header" >> ${basic_tests_1}
echo "--------------------------------------" >> ${basic_tests_1}

runcmd "cat input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "--format-floats input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "--precision 0 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 -l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 -l 1 input_numbers_1.tsv" ${basic_tests_1}

runcmd "cat input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-f input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 -l 1 input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 -l 1 input_numbers_2.tsv" ${basic_tests_1}

runcmd "cat input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-f input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 input_numbers_3.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_3.tsv" ${basic_tests_1}

runcmd "cat input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 4 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-f input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 input_numbers_4.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_4.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}
echo "Numeric file tests: With no header" >> ${basic_tests_1}
echo "----------------------------------" >> ${basic_tests_1}

runcmd "cat input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--no-header input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--no-header --lookahead 0 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 2 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 5 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 6 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 7 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x --format-floats input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -f -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x --precision 0 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 0 -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 1 -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}

runcmd "cat input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 2 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 5 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 6 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 7 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -f input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -f -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 0 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 0 -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 1 -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}

runcmd "cat input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 0 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 1 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 2 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 5 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 6 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 7 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -f input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -f -l 1 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 0 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 1 input_numbers_noheader_3.tsv" ${basic_tests_1}

runcmd "cat input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 1 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 2 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 5 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 6 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -l 7 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -f input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -f -l 1 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 0 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-x -p 1 input_numbers_noheader_4.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}
echo "Numeric file tests: Auto-detect with no header" >> ${basic_tests_1}
echo "----------------------------------------------" >> ${basic_tests_1}

runcmd "cat input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--format-floats input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--precision 0 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}

runcmd "cat input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-f input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 -l 1 input_numbers_noheader_2.tsv" ${basic_tests_1}

runcmd "cat input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-f input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 input_numbers_noheader_3.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_noheader_3.tsv" ${basic_tests_1}

runcmd "cat input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-f input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-p 0 input_numbers_noheader_4.tsv" ${basic_tests_1}
runtest ${prog} "-p 1 input_numbers_noheader_4.tsv" ${basic_tests_1}

###
### Use file ${basic_tests_2}
###
basic_tests_2=${odir}/basic_tests_2.txt

echo "Text file tests" > ${basic_tests_2}
echo "---------------" >> ${basic_tests_2}

runcmd "cat input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 7 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 8 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 9 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -l 7 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -l 8 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "-x --max-text-width 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -m 2 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -m 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 0 -m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -l 1 -m 2 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "-x --space-between-fields 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -s 2 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -s 3 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 2 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 3 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 1 -m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 1 -m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 1 -m 1 -l 1 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "-x --replace-empty input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -e input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -e -l 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -e -l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -e -l 1 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "-x --empty-replacement ^ input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -E ^^^ input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -E ^^^ -l 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-x -E ^ -l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -E ^ -l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-H -E ^^^ -l 1 input_text_1.tsv" ${basic_tests_2}

runcmd "cat input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-x input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-H input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-H -l 1 input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-H -m 10 input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-H -s 3 input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-H -p 2 input_unicode.tsv" ${basic_tests_2}

echo "" >> ${basic_tests_2}
echo "Text file tests: Auto-detect header" >> ${basic_tests_2}
echo "-----------------------------------" >> ${basic_tests_2}

runcmd "cat input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 7 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 8 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 9 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 7 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 8 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "--max-text-width 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-m 2 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-m 0 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-l 1 -m 2 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "--space-between-fields 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 2 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 3 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 2 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 3 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 1 -m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 1 -m 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-s 1 -m 1 -l 1 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "--replace-empty input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-e input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-e -l 1 input_text_1.tsv" ${basic_tests_2}

runtest ${prog} "--empty-replacement ^ input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-E ^^^ input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-E ^ -l 1 input_text_1.tsv" ${basic_tests_2}
runtest ${prog} "-E ^^^ -l 1 input_text_1.tsv" ${basic_tests_2}

runcmd "cat input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-l 1 input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-m 10 input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-s 3 input_unicode.tsv" ${basic_tests_2}
runtest ${prog} "-p 2 input_unicode.tsv" ${basic_tests_2}

###
### Use file ${basic_tests_3}
###
basic_tests_3=${odir}/basic_tests_3.txt

echo "Mixed type file tests" > ${basic_tests_3}
echo "---------------------" >> ${basic_tests_3}

runcmd "cat input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-x input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -l 1 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -l 2 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -l 3 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -l 4 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -f input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -p 0 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -p 1 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-H -p 2 input_mixed_1.tsv" ${basic_tests_3}

echo "" >> ${basic_tests_3}
echo "Mixed type file tests: Auto-detect header" >> ${basic_tests_3}
echo "-----------------------------------------" >> ${basic_tests_3}

runcmd "cat input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-l 1 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-l 2 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-l 3 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-l 4 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-f input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-p 0 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-p 1 input_mixed_1.tsv" ${basic_tests_3}
runtest ${prog} "-p 2 input_mixed_1.tsv" ${basic_tests_3}

###
### Use file ${basic_tests_4}
###
basic_tests_4=${odir}/basic_tests_4.txt

echo "Header operations" > ${basic_tests_4}
echo "-----------------" >> ${basic_tests_4}

runtest ${prog} "--underline-header -H input_mixed_1.tsv" ${basic_tests_4}
runtest ${prog} "--header --underline-header --lookahead 0 input_mixed_1.tsv" ${basic_tests_4}
runtest ${prog} "--underline-header input_mixed_1.tsv" ${basic_tests_4}
runtest ${prog} "-u --lookahead 1 input_mixed_1.tsv" ${basic_tests_4}
runtest ${prog} "-H -u input_unicode.tsv" ${basic_tests_4}
runtest ${prog} "-u input_unicode.tsv" ${basic_tests_4}

echo "" >>  ${basic_tests_4}
echo "Multiple files" >> ${basic_tests_4}
echo "--------------" >> ${basic_tests_4}

runcmd "cat input_5x1.tsv" ${basic_tests_4}

runtest ${prog} "input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "input_5x1.tsv input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "-u input_5x1.tsv input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "-u input_5x1.tsv input_5x1.tsv input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "-u --header input_5x1.tsv input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "-u --no-header input_5x1.tsv input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "-u --header input_5x1.tsv input_5x1.tsv input_5x1.tsv" ${basic_tests_4}
runtest ${prog} "-u --no-header input_5x1.tsv input_5x1.tsv input_5x1.tsv" ${basic_tests_4}

runcmd "cat input_5x2.tsv" ${basic_tests_4}

runtest ${prog} "input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "input_5x2.tsv input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "-u input_5x2.tsv input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "-u input_5x2.tsv input_5x2.tsv input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "-u --header input_5x2.tsv input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "-u --no-header input_5x2.tsv input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "-u --header input_5x2.tsv input_5x2.tsv input_5x2.tsv" ${basic_tests_4}
runtest ${prog} "-u --no-header input_5x2.tsv input_5x2.tsv input_5x2.tsv" ${basic_tests_4}

runcmd "cat input_5x3.tsv" ${basic_tests_4}
runcmd "cat input_5x5.tsv" ${basic_tests_4}

runtest ${prog} "-u input_5x2.tsv input_5x3.tsv" ${basic_tests_4}
runtest ${prog} "-u input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u input_5x1.tsv input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 1 input_5x1.tsv input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 2 input_5x1.tsv input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 1 input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 2 input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 3 input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 4 input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 6 input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}
runtest ${prog} "-u -l 7 input_5x2.tsv input_5x3.tsv input_5x5.tsv" ${basic_tests_4}

###
### Use file ${basic_tests_5}
###
basic_tests_5=${odir}/basic_tests_5.txt

echo "Alternate delimiters" > ${basic_tests_5}
echo "--------------------" >> ${basic_tests_5}

runcmd "cat input_comma_delim.tsv" ${basic_tests_5}
runtest ${prog} "input_comma_delim.tsv" ${basic_tests_5}
runtest ${prog} "--delimiter , input_comma_delim.tsv" ${basic_tests_5}
runtest ${prog} "--header -d , input_comma_delim.tsv" ${basic_tests_5}
runtest ${prog} "--no-header -d , input_comma_delim.tsv" ${basic_tests_5}

echo "" >> ${basic_tests_5}
echo "Help and version options" >> ${basic_tests_5}
echo "------------------------" >> ${basic_tests_5}
echo "" >> ${basic_tests_5}

echo "====[tsv-pretty --help | grep -c Synopsis]====" >> ${basic_tests_5}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_5} 2>&1

echo "====[tsv-pretty -h | grep -c Synopsis]====" >> ${basic_tests_5}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_5} 2>&1

echo "====[tsv-pretty --help-verbose | grep -c Synopsis]====" >> ${basic_tests_5}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_5} 2>&1

echo "====[tsv-pretty --version | grep -c 'tsv-pretty (eBay/tsv-utils-dlang)']====" >> ${basic_tests_5}
${prog} --version 2>&1 | grep -c 'tsv-pretty (eBay/tsv-utils-dlang)' >> ${basic_tests_5} 2>&1

echo "====[tsv-pretty -V | grep -c 'tsv-pretty (eBay/tsv-utils-dlang)']====" >> ${basic_tests_5}
${prog} -V 2>&1 | grep -c 'tsv-pretty (eBay/tsv-utils-dlang)' >> ${basic_tests_5} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "no_such_file.tsv" ${error_tests_1}
runtest ${prog} "--no-such-param input_unicode.tsv" ${error_tests_1}
runtest ${prog} "-d ß input_unicode.tsv" ${error_tests_1}
runtest ${prog} "--precision -1 input_unicode.tsv" ${error_tests_1}
runtest ${prog} "--lookahead -1 input_unicode.tsv" ${error_tests_1}
runtest ${prog} "--lookahead 1.5 input_unicode.tsv" ${error_tests_1}
runtest ${prog} "--space-between-fields 1.5 input_unicode.tsv" ${error_tests_1}
runtest ${prog} "--max-text-width -1 input_unicode.tsv" ${error_tests_1}
runtest ${prog} "--lookahead 0 input_unicode.tsv" ${error_tests_1}
