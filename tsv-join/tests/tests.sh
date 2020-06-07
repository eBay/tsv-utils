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
    echo "====[tsv-join $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

## Note: input1.tsv has duplicate values in fields 2 & 3. Tests with those fields
## as keys that have append values need to use --allow-duplicate-keys (unless
## testing error handling).

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

# Whole line as key
echo "====Whole line as key===" >> ${basic_tests_1}
runtest ${prog} "--header --filter-file input1.tsv input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --key-fields 0 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --key-fields 0 --data-fields 0 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --exclude input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --append-fields 1 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --append-fields 1,2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --append-fields 2,1 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --append-fields 2,1 --prefix i1_ input2.tsv" ${basic_tests_1}

runtest ${prog} "--filter-file input1_noheader.tsv input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --key-fields 0 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --key-fields 0 --data-fields 0 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --exclude input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --append-fields 1 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --append-fields 1,2 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --append-fields 2,1 input2_noheader.tsv" ${basic_tests_1}

# Single key
echo "" >> ${basic_tests_1}; echo "====Single key===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv --key-fields 1 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv --key-fields 2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -e input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3 -e input2.tsv" ${basic_tests_1}

runtest ${prog} "-f input1_noheader.tsv --key-fields 1 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv --key-fields 2 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 3 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -e input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 3 -e input2_noheader.tsv" ${basic_tests_1}

# Single key, different data key
echo "" >> ${basic_tests_1}; echo "====Single key, different data key===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 2 --data-fields 2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 1 -d 3 input2.tsv" ${basic_tests_1}
runtest ${prog} "-H -f input1.tsv -k 1 -d 3 input2.tsv input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3 -d 2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 3 -e input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3 -d 3 -e input2.tsv" ${basic_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2 --data-fields 2 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 1 -d 3 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 1 -d 3 input2_noheader.tsv input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -d 3 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 3 -d 2 input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -d 3 -e input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 3 -d 3 -e input2_noheader.tsv" ${basic_tests_1}

# Single key append variants
echo "" >> ${basic_tests_1}; echo "====Single key append variants===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 2 -a 5 --allow-duplicate-keys input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 2 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 3 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 4 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 5 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 3 -a 4 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 2,3 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 3,2 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 3,2,4 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 3-2,4 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 1,2,3,4,5 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 1-5 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 5,4,3,2,1 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 5-1 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2 -a 5 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 2 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 3 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 4 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 5 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -d 3 -a 4 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 2,3 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 3,2 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 3,2,4 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 3-2,4 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 1,2,3,4,5 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 1-5 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 5,4,3,2,1 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 5-1 --allow-duplicate-keys input2_noheader.tsv" ${basic_tests_1}

# Whole line appends
echo "" >> ${basic_tests_1}; echo "====Whole line appends===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 3 -d 2 -a 0 --allow-duplicate-keys input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3 -d 2 -a 0 --allow-duplicate-keys -p i1_ input2.tsv" ${basic_tests_1}

# Multiple field keys
echo "" >> ${basic_tests_1}; echo "====Multi-field keys===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 2,3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3,2 -d 3,2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3-2 -d 3-2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3,2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -d 3,2 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3,4 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 5,2,3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 5,2-3 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -e input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3,2 -e input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3,2 -d 3,2 -e input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 3-2 -d 3-2 -e input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -a 4 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -a 4,5 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2-3 -a 4-5 input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -a 4 -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -a 4,5 -p i1_ input2.tsv" ${basic_tests_1}

# Repeated fields tests
echo "" >> ${basic_tests_1}; echo "====Repeated fields tests===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 2,3,2 -a 4,5,4 -p i1_ input2.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -d 3,3 -a 5,5,1,5 -p i1_ input2.tsv" ${basic_tests_1}

# Write all tests
echo "" >> ${basic_tests_1}; echo "====Write all tests===" >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 2,3 -a 5 --write-all MISSING  input2.tsv" ${basic_tests_1}

## Can't pass the single quotes to runtest
echo "" >> ${basic_tests_1}; echo "====[tsv-join --header -f input1.tsv -k 2,3 -a 5 --write-all ''  input2.tsv]====" >> ${basic_tests_1}
${prog} --header -f input1.tsv -k 2,3 -a 5 --write-all ''  input2.tsv >> ${basic_tests_1}

runtest ${prog} "--header -f input1.tsv -k 2,3 -a 4,5 --write-all MISSING  input2.tsv" ${basic_tests_1}

# Misc other cases
# Note - The pipe operation not supported by runtest, need to write out those tests.
echo "" >> ${basic_tests_1}; echo "====Misc other tests===" >> ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[tail -n 10 input1.tsv | tsv-join -f - -k 4 -a 1 input2.tsv]====" >> ${basic_tests_1}
tail -n 10 input1.tsv | ${prog} -f - -k 4 -a 1 input2.tsv >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[tail -n 10 input1.tsv | tsv-join -f - -k 4 -d 5 input2.tsv]====" >> ${basic_tests_1}
tail -n 10 input1.tsv | ${prog} -f - -k 4 -d 5 input2.tsv >> ${basic_tests_1} 2>&1

runtest ${prog} "--header -f input1.tsv -k 4 -d 5 input2.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====[tail -n 10 input2.tsv | tsv-join -f input1.tsv -k 4,5 -a 1 -- input2.tsv - input1.tsv]====" >> ${basic_tests_1}
tail -n 10 input2.tsv | ${prog} -f input1.tsv -k 4,5 -a 1 -- input2.tsv - input1.tsv >> ${basic_tests_1}  2>&1

# Single column input file tests
echo "" >> ${basic_tests_1}; echo "====Single column input file tests===" >> ${basic_tests_1}

runtest ${prog} "--header -f input_1x5.tsv -k 1 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input_1x5.tsv -k 1 -d 2 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input_1x5.tsv -k 1 -d 2 -a 1 input1.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 1 input_1x5.tsv" ${basic_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 1 input_1x5.tsv" ${basic_tests_1}
runtest ${prog} "--allow-duplicate-keys --header -f input1.tsv -k 2 -d 1 -a 5,1 -p i1_ input_1x5.tsv" ${basic_tests_1}

# Alternate delimiter tests
echo "" >> ${basic_tests_1}; echo "====Alternate delimiter tests===" >> ${basic_tests_1}

runtest ${prog} "--delimiter : --header -k 1 -f input_2x3_colon.tsv input_5x4_colon.tsv" ${basic_tests_1}
runtest ${prog} "--delimiter : --header -k 1 -d 5 -f input_2x3_colon.tsv input_5x4_colon.tsv" ${basic_tests_1}
runtest ${prog} "--delimiter : --header -k 1,2 -d 5,3 -a 1 -f input_2x3_colon.tsv input_5x4_colon.tsv" ${basic_tests_1}
runtest ${prog} "--delimiter : --header -d 1,2 -k 5,3 -a 2 -f input_5x4_colon.tsv input_2x3_colon.tsv" ${basic_tests_1}

echo "" >> ${basic_tests_1}; echo "====Empty file tests===" >> ${basic_tests_1}
runtest ${prog} "-f input_emptyfile.tsv input2.tsv"  ${basic_tests_1}
runtest ${prog} "-H -f input_emptyfile.tsv input2.tsv"  ${basic_tests_1}
runtest ${prog} "-f input1.tsv input_emptyfile.tsv"  ${basic_tests_1}
runtest ${prog} "-H -f input1.tsv input_emptyfile.tsv"  ${basic_tests_1}

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[tsv-join --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-join --help-verbose | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help-verbose 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-join --version | grep -c 'tsv-join (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'tsv-join (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

echo "====[tsv-join -V | grep -c 'tsv-join (eBay/tsv-utils)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'tsv-join (eBay/tsv-utils)' >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Duplicate keys===" >> ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 0 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 4 input2.tsv" ${error_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2 -a 0 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 4 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Invalid field indicies===" >> ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 6 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 4 -a 6 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 4 -d 6 input2.tsv" ${error_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 6 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 4 -a 6 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 4 -d 6 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Missing filter file===" >> ${error_tests_1}
runtest ${prog} "--header -k 2 input2.tsv" ${error_tests_1}
runtest ${prog} "-k 2 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Stdin filter file, no data file===" >> ${error_tests_1}
runtest ${prog} "--header -f - -k 2" ${error_tests_1}
runtest ${prog} "-f - -k 2" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Invalid Whole line and individual field combos===" >> ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,0 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 0,2 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -d 0,2 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -d 2,0 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 1 -a 2,0 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 1 -a 0,2 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 0 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 0 -d 2 input2.tsv" ${error_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2,0 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 0,2 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2,3 -d 0,2 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2,3 -d 2,0 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 1 -a 2,0 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 1 -a 0,2 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -d 0 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 0 -d 2 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Different number of filter and data keys===" >> ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 2,3 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -d 2 input2.tsv" ${error_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2 -d 2,3 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2,3 -d 2 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Header prefix without header===" >> ${error_tests_1}
runtest ${prog} "--prefix -f input1.tsv -k 2 input1_ input2.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Exclude with an append field===" >> ${error_tests_1}
runtest ${prog} "--header --exclude -a 3 -f input1.tsv -k 6 input2.tsv" ${error_tests_1}
runtest ${prog} "--exclude -a 3 -f input1_noheader.tsv -k 6 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Invalid write-all combinations===" >> ${error_tests_1}
runtest ${prog} "--header --write-all MISSING -f input1.tsv -k 2,3 input2.tsv" ${error_tests_1}
runtest ${prog} "--header --write-all MISSING -a 0 -f input1.tsv -k 2,3 input2.tsv" ${error_tests_1}
runtest ${prog} "--header --write-all MISSING -a 1 --exclude  -f input1.tsv -k 2,3 input2.tsv" ${error_tests_1}

runtest ${prog} "--write-all MISSING -f input1_noheader.tsv -k 2,3 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "--write-all MISSING -a 0 -f input1_noheader.tsv -k 2,3 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "--write-all MISSING -a 1 --exclude  -f input1_noheader.tsv -k 2,3 input2_noheader.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Invalid field ranges===" >> ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,x input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 -d 2,1.5 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -a 1- input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,,4 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k input2.tsv input_emptyfile.tsv" ${error_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2,x input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2,3 -d 2,1.5 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2 -a 1- input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k 2,,4 input2_noheader.tsv" ${error_tests_1}
runtest ${prog} "-f input1_noheader.tsv -k input2_noheader.tsv input_emptyfile.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===Windows Newline detection===" >> ${error_tests_1}
runtest ${prog} "--header -f input1_dos.tsv -k 2,3 input2.tsv" ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2,3 input2_dos.tsv" ${error_tests_1}
runtest ${prog} "-f input1_dos.tsv -k 2,3 input2.tsv" ${error_tests_1}
runtest ${prog} "-f input1.tsv -k 2,3 input2_dos.tsv" ${error_tests_1}

echo "" >> ${error_tests_1}; echo "===No such file===" >> ${error_tests_1}
runtest ${prog} "--header -f input1.tsv -k 2 -d 2,3 no_such-file.tsv" ${error_tests_1}
runtest ${prog} "--header -f no_such_file -k 2,3 -d 2 input2.tsv" ${error_tests_1}

runtest ${prog} "-f input1_noheader.tsv -k 2 -d 2,3 no_such-file.tsv" ${error_tests_1}
runtest ${prog} "-f no_such_file -k 2,3 -d 2 input2_noheader.tsv" ${error_tests_1}

exit $?
