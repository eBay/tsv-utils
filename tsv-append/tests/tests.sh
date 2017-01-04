#! /bin/sh

## Most tsv-append testing is done as unit tests. Tests executed by this script are
## run against the final executable. This provides a sanity check that the
## final executable is good. Tests are easy to run in the format, so there is
## overlap. However, these tests do not test edge cases as rigorously as unit tests.
## Instead, these tests focus on areas that are hard to test in unit tests.

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
    echo "====[tsv-append $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

runtest ${prog} "input3x2.tsv input3x5.tsv" ${basic_tests_1}
runtest ${prog} "input1x3.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "input3x2.tsv input1x3.tsv input3x5.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "input3x5.tsv" ${basic_tests_1}

runtest ${prog} "--header input3x2.tsv input3x5.tsv" ${basic_tests_1}
runtest ${prog} "-H input1x3.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-H input3x2.tsv input1x3.tsv input3x5.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-H input3x5.tsv" ${basic_tests_1}

runtest ${prog} "--track-source input3x2.tsv input3x5.tsv" ${basic_tests_1}
runtest ${prog} "-t input1x3.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-t input3x2.tsv input1x3.tsv input3x5.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-t input3x5.tsv" ${basic_tests_1}

runtest ${prog} "--header --track-source input3x2.tsv input3x5.tsv" ${basic_tests_1}
runtest ${prog} "-H -t input1x3.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-H -t input3x2.tsv input1x3.tsv input3x5.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-H -t input3x5.tsv" ${basic_tests_1}

runtest ${prog} "--source-header source input3x2.tsv input3x5.tsv" ${basic_tests_1}
runtest ${prog} "--s source input1x3.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-s source input3x2.tsv input1x3.tsv input3x5.tsv input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-s source input3x5.tsv" ${basic_tests_1}
runtest ${prog} "-H -s source input3x2.tsv input3x5.tsv" ${basic_tests_1}
runtest ${prog} "-H -t -s source input3x2.tsv input3x5.tsv" ${basic_tests_1}

runtest ${prog} "-t --file Input-A=input1x3.tsv --file Input-B=input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-H -t -f Input-A=input1x3.tsv -f Input-B=input1x4.tsv" ${basic_tests_1}
runtest ${prog} "-H -t -s πηγή -f κόκκινος=input1x3.tsv -f άσπρο=input1x4.tsv" ${basic_tests_1}

## runtest can't create a command lines with standard input. Write them out.
echo "" >> ${basic_tests_1}; echo "====[cat input3x2.tsv | tsv-append]====" >> ${basic_tests_1}
cat input3x2.tsv | ${prog} >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x2.tsv | tsv-append -- - input3x5.tsv]====" >> ${basic_tests_1}
cat input3x2.tsv | ${prog} -- - input3x5.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x2.tsv | tsv-append -H -- - input3x5.tsv]====" >> ${basic_tests_1}
cat input3x2.tsv | ${prog} -H -- - input3x5.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x2.tsv | tsv-append -H input3x5.tsv -- -]====" >> ${basic_tests_1}
cat input3x2.tsv | ${prog} -H input3x5.tsv -- - >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input3x2.tsv | tsv-append -H -f standard-input=- -f 3x5=input3x5.tsv ]====" >> ${basic_tests_1}
cat input3x2.tsv | ${prog} -H -f standard-input=- -f 3x5=input3x5.tsv >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "no_such_file.tsv" ${error_tests_1}
runtest ${prog} "-f none=no_such_file.tsv" ${error_tests_1}
runtest ${prog} "--no-such-param input1x3.tsv" ${error_tests_1}
runtest ${prog} "-d ß input1x3.tsv" ${error_tests_1}
