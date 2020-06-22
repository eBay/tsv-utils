#!/usr/bin/env bash

## Most tsv-sample testing is done as unit tests. Tests executed by this script are run
## against the final executable. This provides a sanity check that the final executable
## is good. Tests are easy to run in this format, so there is overlap. However, these
## tests do not test edge cases as rigorously as unit tests. Instead, these tests focus
## on areas that are hard to test in unit tests.
##
## Portability note: Many of the tests here rely on generating consistent random numbers
## across different platforms when using the same random seed. So far this has succeeded
## on several different platorm, compiler, and library versions. However, it is certainly
## possible this condition will not hold on other platforms.
##
## For tsv-sample, this portability implies generating the same results on different
## platforms when using the same random seed. This is NOT part of tsv-sample guarantees,
## but it is convenient for testing. If platforms are identified that do not generate
## the same results these tests will need to be adjusted.

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
    echo "====[tsv-sample $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

## A special version used by some of the error handling tests. It is used to
## filter out lines other than error lines. See the calls for examples.
runtest_filter () {
    echo "" >> $3
    echo "====[tsv-sample $2]====" >> $3
    $1 $2 2>&1 | grep -v $4 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

runtest ${prog} "--header --static-seed --compatibility-mode input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --print-random input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --print-random --weight-field 3 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --print-random -w 3 --num 15 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --print-random -w weight --num 15 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --print-random -n 15 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -n 100  --compatibility-mode input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --gen-random-inorder --weight-field 3 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --gen-random-inorder -n 15 --weight-field 3 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --gen-random-inorder input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --gen-random-inorder -n 15 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --inorder -n 15 --compatibility-mode input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --inorder -n 15 --prefer-algorithm-r input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --inorder -n 15 --weight-field 3 input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --inorder -n 15 --weight-field weight input3x10.tsv input3x25.tsv" ${basic_tests_1}

# Bernoulli sampling
runtest ${prog} "-H -s --prob 1.0 --print-random input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p 0.25 --compatibility-mode input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p 0.75 -n 5 --compatibility-mode input3x10.tsv input3x25.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p 0.02 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p 0.02 --inorder input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-s -p 0.02 input4x50.tsv input4x15.tsv" ${basic_tests_1}

# Simple random sampling with replacement
runtest ${prog} "-H -s --replace --compatibility-mode input3x3.tsv --num 5" ${basic_tests_1}
runtest ${prog} "-s --r input2x5_noheader.tsv --num 7 --compatibility-mode" ${basic_tests_1}

# Distinct Sampling
runtest ${prog} "-H -s --prob .25 -k 3,1 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --prob .25 -k c\-3,c\-1 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --prob .25 -k 3,1 --inorder input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s --prob .25 -k c\-3,c\-1 --inorder input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .25 -k 1,3 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .25 -k 1,1 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .25 --key-fields 1 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .25 -k 1 -n 5 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-s -p .25 -k 1,3 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-s -p .25 -k 3,1 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-s -p 1 -k 3,1 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .2 -k 3 --print-random input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .2 -k 3 --print-random -n 5 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .2 -k 3 --gen-random-inorder -n 10 input4x50.tsv input4x15.tsv" ${basic_tests_1}
runtest ${prog} "-H -s -p .2 -k c\-3 --gen-random-inorder -n 10 input4x50.tsv input4x15.tsv" ${basic_tests_1}

runtest ${prog} "--static-seed --compatibility-mode input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s --print-random input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s --print-random --weight-field 1 input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s --print-random -w 1 --num 15 input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s --print-random -n 5 input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s -n 100 --compatibility-mode input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}

runtest ${prog} "-s --prob 1 --print-random input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s -p .25 --compatibility-mode input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-s -p .75 -n 5 --compatibility-mode input2x10_noheader.tsv input2x5_noheader.tsv" ${basic_tests_1}

runtest ${prog} "--delimiter @ -H --static-seed --compatibility-mode input2x7_atsign.tsv" ${basic_tests_1}
runtest ${prog} "-d @ -H -s --print-random input2x7_atsign.tsv" ${basic_tests_1}
runtest ${prog} "-d @ -H -s --print-random -w 2 input2x7_atsign.tsv" ${basic_tests_1}
runtest ${prog} "-d @ -H -s --print-random -w 2 -n 3 input2x7_atsign.tsv" ${basic_tests_1}
runtest ${prog} "-d @ -H -s --print-random -w weight -n 3 input2x7_atsign.tsv" ${basic_tests_1}
runtest ${prog} "-d @ -H -s --print-random -n 20 input2x7_atsign.tsv" ${basic_tests_1}
runtest ${prog} "-d @ -H -s --print-random --prob 1.0 input2x7_atsign.tsv" ${basic_tests_1}

## Tests with a negative weight. Negative weight entry should be last.
runtest ${prog} "-H -w 3 -v 777 --compatibility-mode input3x25_negative_wt.tsv" ${basic_tests_1}
runtest ${prog} "-H -w 3 -v 888 --compatibility-mode input3x25_negative_wt.tsv" ${basic_tests_1}
runtest ${prog} "-H -w 3 -v 777 -n 24 --compatibility-mode input3x25_negative_wt.tsv" ${basic_tests_1}
runtest ${prog} "-H -w 3 -v 888 -n 24 --compatibility-mode input3x25_negative_wt.tsv" ${basic_tests_1}
runtest ${prog} "-H --gen-random-inorder -w 3 -v 777 --compatibility-mode input3x25_negative_wt.tsv" ${basic_tests_1}
runtest ${prog} "-H --gen-random-inorder -w 3 -v 888 --compatibility-mode input3x25_negative_wt.tsv" ${basic_tests_1}

## Line order randomization with standard input and multiple files. These deserve specific tests
## due to special handling of these in the code. runtest cannot do these, so write out by hand.
echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -v 99 --compatibility-mode]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -v 99 --compatibility-mode >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -v 99 --compatibility-mode]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -v 99 --compatibility-mode >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -v 99 --print-random]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -v 99 --print-random >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s --compatibility-mode -- - input3x3.tsv input3x4.tsv]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s --compatibility-mode -- - input3x3.tsv input3x4.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s --compatibility-mode -- input3x3.tsv - input3x4.tsv]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s --compatibility-mode -- input3x3.tsv - input3x4.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -s --compatibility-mode -- input3x3.tsv input3x4.tsv -]====" >> ${basic_tests_1}
cat input3x3.tsv | ${prog} -s --compatibility-mode -- input3x4.tsv - >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s -w 3 --compatibility-mode -- input3x3.tsv - input3x4.tsv]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s -w 3 --compatibility-mode -- input3x3.tsv - input3x4.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s -w weight --compatibility-mode -- input3x3.tsv - input3x4.tsv]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s -w weight --compatibility-mode -- input3x3.tsv - input3x4.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s --replace --num 10 --compatibility-mode]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s --replace --num 10 --compatibility-mode >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s --replace --num 10 --compatibility-mode -- input3x3.tsv - input3x4.tsv]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s --replace --num 10 --compatibility-mode -- input3x3.tsv - input3x4.tsv >> ${basic_tests_1} 2>&1

## Random sample with infinite output - control with head.
echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H -s --replace --compatibility-mode | head -n 1000 | tail]====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H -s --replace --compatibility-mode | head -n 1000 | tail >> ${basic_tests_1} 2>&1

## Need to run a few tests with the unpredictable seed. Can't compare the results
## so check the number of lines returned. Some standard input tests are also in
## this section. runtest can't do these, write these out by hand.
## Note: The "tr -d ' '" construct strips whitespace, which differs between 'wc -l' implementations.
echo "" >> ${basic_tests_1}; echo "====[tsv-sample -H input3x10.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H input3x10.tsv | wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-sample -H -n 9 input3x25.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -n 9 input3x25.tsv | wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-sample -H -n 25 input3x25.tsv input3x10.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -n 25 input3x25.tsv input3x10.tsv| wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tsv-sample -H -n 9 -w 3 input3x25.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
${prog} -H -n 9 -w 3 input3x25.tsv | wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H --print-random | wc -l | tr -d ' ']====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H --print-random | wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H --print-random -w 3 -- - input3x25.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H --print-random -w 3 -- - input3x25.tsv | wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x10.tsv tsv-sample -H --print-random -w 3 -n 10 -- - input3x25.tsv | wc -l | tr -d ' ']====" >> ${basic_tests_1}
cat input3x10.tsv | ${prog} -H --print-random -w 3 -n 10 -- - input3x25.tsv | wc -l | tr -d ' ' >> ${basic_tests_1} 2>&1

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[tsv-sample --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-sample --help-fields | head -n 1]====" >> ${basic_tests_1}
${prog} --help-fields 2>&1 | head -n 1 >> ${basic_tests_1} 2>&1

echo "====[tsv-sample --help-verbose | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help-verbose 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-sample --version | grep -c 'tsv-sample (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'tsv-sample (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

echo "====[tsv-sample -V | grep -c 'tsv-sample (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'tsv-sample (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

## Error cases

error_tests=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests}
echo "----------------" >> ${error_tests}

runtest ${prog} "no_such_file.tsv" ${error_tests}
runtest ${prog} "--no-such-param input3x25.tsv" ${error_tests}
runtest ${prog} "-d ß input3x25.tsv" ${error_tests}
runtest ${prog} "-H -w 11 input3x25.tsv" ${error_tests}
runtest ${prog} "-H -w 0 input3x25.tsv" ${error_tests}
runtest ${prog} "-H -w no_such_field input3x25.tsv" ${error_tests}
runtest ${prog} "-w weight input3x25.tsv" ${error_tests}
runtest ${prog} "-H -w weight,line input3x25.tsv" ${error_tests}
runtest ${prog} "-H -w line,weight input3x25.tsv" ${error_tests}
runtest ${prog} "-w 1,3 input3x25.tsv" ${error_tests}
runtest ${prog} "--prob 0.5 --weight-field 3 input3x25.tsv" ${error_tests}
runtest ${prog} "--prob 0.5 --weight-field 0 input3x25.tsv" ${error_tests}
runtest ${prog} "--prob 0 input3x25.tsv" ${error_tests}
runtest ${prog} "--prob 1.00001 input3x25.tsv" ${error_tests}
runtest ${prog} "-p .1 -k 0,1 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p .1 -k 1,2,0 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p .1 -k -1 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p 0 -k 1 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p -0.5 -k 1 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p 0.5 -v -10 -k 1 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-k 1 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p 0.5 -k 5 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-H -p 0.5 -k 5 input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-H -p 0.5 -k no_such_field input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-p 0.05 -k 1 --compatibility-mode input3x25.tsv" ${error_tests}
runtest ${prog} "-H -p 0.5 --gen-random-inorder input4x50.tsv input4x15.tsv" ${error_tests}
runtest ${prog} "-H --gen-random-inorder -d , --random-value-header abc,def input3x25.tsv" ${error_tests}
runtest ${prog} "--replace -n 5 --weight-field 2 input3x25.tsv" ${error_tests}
runtest ${prog} "--replace -n 5 --prob 0.5 input3x25.tsv" ${error_tests}
runtest ${prog} "--replace -n 5 --key-fields 2 input3x25.tsv" ${error_tests}
runtest ${prog} "--replace -n 5 --print-random input3x25.tsv" ${error_tests}
runtest ${prog} "--replace -n 5 --gen-random-inorder input3x25.tsv" ${error_tests}
runtest ${prog} "--inorder --replace -n 5 input3x25.tsv" ${error_tests}
runtest ${prog} "--inorder input3x25.tsv" ${error_tests}
runtest ${prog} "--inorder -n 0 input3x25.tsv" ${error_tests}

# Windows line endings. The tests where the windows line ending is in the second
# file use a single line first file that is filtered out of the output.

header_line_3x0='line[[:blank:]]title[[:blank:]]weight'
line1_2x1='0.157876295	Jacques le fataliste et son maître'

runtest ${prog} "-H input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-H input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}

runtest ${prog} "-n 2 -H input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-n 2 -H input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-n 2 input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-n 2 input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}

runtest ${prog} "-H -w 3 input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-H -w 3 input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-H -w weight input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-H -w weight input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-w 1 input2x5_noheader_dos.tsv" ${error_tests}
runtest_filter ${prog} "-w 1 input2x1_noheader.tsv input2x5_noheader_dos.tsv" ${error_tests} ${line1_2x1}

runtest ${prog} "-n 2 -H -w 3 input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-n 2 -H -w 3 input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-n 2 -H -w weight input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-n 2 -H -w weight input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-n 2 -w 1 input2x5_noheader_dos.tsv" ${error_tests}
runtest_filter ${prog} "-n 2 -w 1 input2x1_noheader.tsv input2x5_noheader_dos.tsv" ${error_tests} ${line1_2x1}

runtest ${prog} "-r -n 2 -H input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-r -n 2 -H input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-r -n 2 input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-r -n 2 input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}

runtest ${prog} "-p .2 -H input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-p .2 -H input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-p .2 input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-p .2 input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}

runtest ${prog} "-H -p .2 -k 2 input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-H -p .2 -k 2 input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-H -p .2 -k title input3x25_dos.tsv" ${error_tests}
runtest_filter ${prog} "-H -p .2 -k title input3x0.tsv input3x25_dos.tsv" ${error_tests} ${header_line_3x0}
runtest ${prog} "-p .2 -k 2 input2x5_noheader_dos.tsv" ${error_tests}
runtest_filter ${prog} "-p .2 -k 2 input2x1_noheader.tsv input2x5_noheader_dos.tsv" ${error_tests} ${line1_2x1}

# Error tests 2 are tests that are compiler version dependent. There are multiple
# version files in test-config.json.

error_tests=${odir}/error_tests_2.txt

echo "Error test set 2" > ${error_tests}
echo "----------------" >> ${error_tests}

runtest ${prog} "-H -w 2 input3x25.tsv" ${error_tests}
runtest ${prog} "-w 3 input3x25.tsv" ${error_tests}
runtest ${prog} "-p -v 10 -k 1 input4x50.tsv input4x15.tsv" ${error_tests}
