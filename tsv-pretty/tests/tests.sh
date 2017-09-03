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

echo "Numeric file tests (with header)" > ${basic_tests_1}
echo "--------------------------------" >> ${basic_tests_1}

runcmd "cat input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_1.tsv" ${basic_tests_1}
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
runtest ${prog} "-H --float-precision 0 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 -l 1 input_numbers_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 -l 1 input_numbers_1.tsv" ${basic_tests_1}

runcmd "cat input_numbers_2.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_2.tsv" ${basic_tests_1}
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
runtest ${prog} "input_numbers_3.tsv" ${basic_tests_1}
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
runtest ${prog} "input_numbers_4.tsv" ${basic_tests_1}
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
echo "Numeric file tests (with no header)" >> ${basic_tests_1}
echo "-----------------------------------" >> ${basic_tests_1}

runcmd "cat input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--lookahead 0 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 2 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 5 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 6 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--format-floats input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "-f -l 1 input_numbers_noheader_1.tsv" ${basic_tests_1}
runtest ${prog} "--float-precision 0 input_numbers_noheader_1.tsv" ${basic_tests_1}
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
runtest ${prog} "-l 0 input_numbers_noheader_3.tsv" ${basic_tests_1}
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

echo "" >> ${basic_tests_1}
echo "Text file tests" >> ${basic_tests_1}
echo "---------------" >> ${basic_tests_1}

runcmd "cat input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 0 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 7 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 8 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 9 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 7 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 8 input_text_1.tsv" ${basic_tests_1}

runtest ${prog} "--max-text-width 0 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-m 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-m 2 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -m 0 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 0 -m 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-l 1 -m 2 input_text_1.tsv" ${basic_tests_1}

runtest ${prog} "--space-between-fields 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-s 2 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-s 3 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 2 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 3 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 1 -m 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 1 -m 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 1 -m 1 -l 1 input_text_1.tsv" ${basic_tests_1}

runtest ${prog} "--replace-empty input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -e input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-e -l 0 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-e -l 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -e -l 1 input_text_1.tsv" ${basic_tests_1}

runtest ${prog} "--empty-replacement ^ input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -E ^^^ input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-E ^^^ -l 0 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-E ^ -l 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -E ^ -l 1 input_text_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -E ^^^ -l 1 input_text_1.tsv" ${basic_tests_1}

runcmd "cat input_unicode.tsv" ${basic_tests_1}
runtest ${prog} "input_unicode.tsv" ${basic_tests_1}
runtest ${prog} "-H input_unicode.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_unicode.tsv" ${basic_tests_1}
runtest ${prog} "-H -m 10 input_unicode.tsv" ${basic_tests_1}
runtest ${prog} "-H -s 3 input_unicode.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 2 input_unicode.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}
echo "Mixed type file tests" >> ${basic_tests_1}
echo "---------------" >> ${basic_tests_1}

runcmd "cat input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 1 input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 2 input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 3 input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -l 4 input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -f input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 0 input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 1 input_mixed_1.tsv" ${basic_tests_1}
runtest ${prog} "-H -p 2 input_mixed_1.tsv" ${basic_tests_1}
