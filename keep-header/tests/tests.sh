#! /bin/sh

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
    echo "====[keep-header $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

runtest ${prog} "input1.csv -- sort" ${basic_tests_1}
runtest ${prog} "input1.csv -- sort -r" ${basic_tests_1}
runtest ${prog} "input1.csv -- sort -t , -k2,2n" ${basic_tests_1}
runtest ${prog} "emptyfile.txt -- sort" ${basic_tests_1}
runtest ${prog} "input1.csv input2.csv -- sort" ${basic_tests_1}
runtest ${prog} "emptyfile.txt input1.csv -- sort" ${basic_tests_1}
runtest ${prog} "emptyfile.txt input1.csv input2.csv -- sort" ${basic_tests_1}
runtest ${prog} "input1.csv input1.csv -- sort -t , -k2,2n" ${basic_tests_1}
runtest ${prog} "input_headeronly.csv -- sort" ${basic_tests_1}
runtest ${prog} "input_headeronly.csv emptyfile.txt -- sort" ${basic_tests_1}
runtest ${prog} "input_headeronly.csv input1.csv -- sort" ${basic_tests_1}
runtest ${prog} "input1.csv input_headeronly.csv -- sort" ${basic_tests_1}
runtest ${prog} "emptyfile.txt input_headeronly.csv input1.csv input2.csv -- sort" ${basic_tests_1}
runtest ${prog} "emptyfile.txt emptyfile.txt -- cat" ${basic_tests_1}
runtest ${prog} "oneblankline.txt -- cat" ${basic_tests_1}
runtest ${prog} "oneblankline.txt oneblankline.txt -- cat" ${basic_tests_1}
runtest ${prog} "emptyfile.txt oneblankline.txt -- cat" ${basic_tests_1}
runtest ${prog} "oneblankline.txt emptyfile.txt -- cat" ${basic_tests_1}
runtest ${prog} "oneblankline.txt input1.csv input2.csv -- cat" ${basic_tests_1}
runtest ${prog} "input1.csv oneblankline.txt input2.csv -- cat" ${basic_tests_1}

## Standard input tests
echo "" >> ${basic_tests_1}; echo "====[cat input1.csv | keep-header -- sort]====" >> ${basic_tests_1}
cat input1.csv | ${prog} -- sort  >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.csv | keep-header input2.csv - -- sort -t , -k2,2n]====" >> ${basic_tests_1}
cat input1.csv | ${prog} input2.csv - -- sort -t , -k2,2n >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat emptyfile.txt | keep-header -- cat]====" >> ${basic_tests_1}
cat emptyfile.txt | ${prog} -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat emptyfile.txt input1.csv | keep-header -- cat]====" >> ${basic_tests_1}
cat emptyfile.txt input1.csv | ${prog} -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.csv emptyfile.txt | keep-header -- cat]====" >> ${basic_tests_1}
cat input1.csv emptyfile.txt | ${prog} -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat emptyfile.txt | keep-header - input1.csv -- cat]====" >> ${basic_tests_1}
cat emptyfile.txt | ${prog} input1.csv - -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat oneblankline.txt | keep-header -- cat]====" >> ${basic_tests_1}
cat oneblankline.txt | ${prog} -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat oneblankline.txt input1.csv | keep-header -- cat]====" >> ${basic_tests_1}
cat oneblankline.txt input1.csv | ${prog} -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input1.csv oneblankline.txt | keep-header -- cat]====" >> ${basic_tests_1}
cat input1.csv oneblankline.txt | ${prog} -- cat >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat oneblankline.txt | keep-header - input1.csv -- cat]====" >> ${basic_tests_1}
cat oneblankline.txt | ${prog} input1.csv - -- cat >> ${basic_tests_1} 2>&1

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[keep-header --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[keep-header -h | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} -h 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[keep-header --version | grep -c 'keep-header (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'keep-header (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1

echo "====[keep-header --V | grep -c 'keep-header (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} --V 2>&1 | grep -c 'keep-header (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1

echo "====[keep-header -V | grep -c 'keep-header (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'keep-header (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "nosuchfile.txt -- sort" ${error_tests_1}
runtest ${prog} "input1.csv -- nosuchprogram" ${error_tests_1}
runtest ${prog} "" ${error_tests_1}
runtest ${prog} "input1.csv" ${error_tests_1}
runtest ${prog} "input1.csv --" ${error_tests_1}
runtest ${prog} "--" ${error_tests_1}
