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
    echo "====[number-lines $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

runtest ${prog} "input1.txt" ${basic_tests_1}
runtest ${prog} "--start-number 10 input1.txt" ${basic_tests_1}
runtest ${prog} "-n 10 input1.txt" ${basic_tests_1}
runtest ${prog} "-n -10 input1.txt" ${basic_tests_1}
runtest ${prog} "--header input1.txt" ${basic_tests_1}
runtest ${prog} "--header-string LINENUM input1.txt" ${basic_tests_1}
runtest ${prog} "-s LineNum_àßß input1.txt" ${basic_tests_1}
runtest ${prog} "--header -s line_num input1.txt" ${basic_tests_1}
runtest ${prog} "--delimiter : input1.txt" ${basic_tests_1}
runtest ${prog} "-d _ input1.txt" ${basic_tests_1}
runtest ${prog} "--header -d ^ input1.txt" ${basic_tests_1}
runtest ${prog} "empty-file.txt" ${basic_tests_1}
runtest ${prog} "-H empty-file.txt" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====Multi-file Tests===" >> ${basic_tests_1}
runtest ${prog} "input1.txt input2.txt empty-file.txt one-line-file.txt" ${basic_tests_1}
runtest ${prog} "input1.txt one-line-file.txt input2.txt empty-file.txt" ${basic_tests_1}
runtest ${prog} "empty-file.txt input1.txt one-line-file.txt input2.txt input1.txt" ${basic_tests_1}
runtest ${prog} "-H input2.txt input2.txt input2.txt" ${basic_tests_1}
runtest ${prog} "--header input1.txt input2.txt empty-file.txt one-line-file.txt" ${basic_tests_1}
runtest ${prog} "--header -n 10 input1.txt one-line-file.txt input2.txt empty-file.txt" ${basic_tests_1}
runtest ${prog} "--header -s LINENUM empty-file.txt input1.txt one-line-file.txt input2.txt input1.txt" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====Tests using Standard Input===" >> ${basic_tests_1}
## runtest can't do these. Generate them directly.

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt | number-lines]====" >> ${basic_tests_1}
cat input1.txt | ${prog} >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt input2.txt | number-lines --header]====" >> ${basic_tests_1}
cat input1.txt input2.txt | ${prog} --header >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt | number-lines -- input2.txt -]====" >> ${basic_tests_1}
cat input1.txt | ${prog} -- input2.txt - >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt | number-lines --header -- input2.txt -]====" >> ${basic_tests_1}
cat input1.txt | ${prog} --header -- input2.txt - >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt | number-lines -- input2.txt - one-line-file.txt]====" >> ${basic_tests_1}
cat input1.txt | ${prog} -- input2.txt - one-line-file.txt >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt | number-lines --header -- input2.txt - one-line-file.txt]====" >> ${basic_tests_1}
cat input1.txt | ${prog} --header -- input2.txt - one-line-file.txt >> ${basic_tests_1} 2>&1

## --line-buffered tests
echo "" >> ${basic_tests_1}; echo "====line buffered tests===" >> ${basic_tests_1}
runtest ${prog} "--line-buffered input1.txt" ${basic_tests_1}
runtest ${prog} "empty-file.txt" ${basic_tests_1}
runtest ${prog} "-H empty-file.txt" ${basic_tests_1}
runtest ${prog} "--line-buffered input1.txt input2.txt empty-file.txt one-line-file.txt" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[cat input1.txt input2.txt | number-lines --header --line-buffered]====" >> ${basic_tests_1}
cat input1.txt input2.txt | ${prog} --header --line-buffered >> ${basic_tests_1} 2>&1

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[number-lines --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[number-lines --version | grep -c 'number-lines (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'number-lines (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

echo "====[number-lines -V | grep -c 'number-lines (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'number-lines (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "nosuchfile.txt" ${error_tests_1}

# Disable this test until Phobos 2.071 is available on all compilers
# 2.071 changed the error message in a minor way.
#runtest ${prog} "-n notanumber input1.txt" ${error_tests_1}

runtest ${prog} "-d ß input1.txt" ${error_tests_1}
runtest ${prog} "--nosuchparam input1.txt" ${error_tests_1}

exit $?
