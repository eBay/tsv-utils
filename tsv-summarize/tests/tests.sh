#! /bin/sh

## Most tsv-summarize testing is done as unit tests. Unit tests include operators,
## summarizers, and non-error cases of command line handling. Tests executed by this
## script are run against the final executable. This provides a sanity check that the
## final executable is good. It also tests areas that are hard to test in unit tests.
## This includes file handling, erroneous command lines, special case and invalid
## input files, etc.

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
    echo "====[tsv-summarize $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

basic_tests_1=${odir}/basic_tests_1.txt

echo "Basic tests set 1" > ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}

## One test for each operator. Make sure it is hooked up to the command line args properly
runtest ${prog} "--header --float-precision 2 --retain 1 --first 1 --last 1 --min 3 --max 3 --range 3 --sum 3 --median 3 --quantile 3:0.5 --mad 3 --var 3 --stdev 3 --mode 1 --mode-count 1 --values 1 --unique-values 1 input_5field_a.tsv" ${basic_tests_1}

runtest ${prog} "--header --missing-count 1 --not-missing-count 1 input_1field_a.tsv" ${basic_tests_1}

## Functionality tests
runtest ${prog} "--header --count --min 3,4,5 --max 3,4,5 input_5field_a.tsv" ${basic_tests_1}
runtest ${prog} "--header --group-by 1 --count --min 3,4,5 --max 3,4,5 input_5field_a.tsv" ${basic_tests_1}
runtest ${prog} "--header --group-by 1,2 --count --min 3,4,5 --max 3,4,5 input_5field_a.tsv" ${basic_tests_1}
runtest ${prog} "--header --group-by 1-2 --count --min 3-5 --max 5-3 input_5field_a.tsv" ${basic_tests_1}

runtest ${prog} "--header --count --min 3,4,5 --max 3,4,5 input_5field_a.tsv input_5field_b.tsv input_5field_c.tsv empty_file.tsv input_5field_header_only.tsv" ${basic_tests_1}
runtest ${prog} "--header --group-by 1 --count --min 3,4,5 --max 3,4,5 input_5field_a.tsv input_5field_b.tsv input_5field_c.tsv empty_file.tsv input_5field_header_only.tsv" ${basic_tests_1}

runtest ${prog} "--header --group-by 1,2 --count --min 3,4,5 --max 3,4,5 input_5field_a.tsv input_5field_b.tsv input_5field_c.tsv empty_file.tsv input_5field_header_only.tsv" ${basic_tests_1}

runtest ${prog} "--header --group-by 1 --count --range 3,4,5 input_5field_a.tsv empty_file.tsv input_5field_b.tsv input_5field_header_only.tsv input_5field_c.tsv" ${basic_tests_1}

## No header tests.
runtest ${prog} "--count --unique-count 1,2,3,4,5 input_5field_a.tsv empty_file.tsv input_5field_b.tsv input_5field_header_only.tsv input_5field_c.tsv" ${basic_tests_1}
runtest ${prog} "--count --unique-count 1-5 input_5field_a.tsv empty_file.tsv input_5field_b.tsv input_5field_header_only.tsv input_5field_c.tsv" ${basic_tests_1}

runtest ${prog} "--count --group-by 1 --unique-count 2,3,4,5 input_5field_a.tsv empty_file.tsv input_5field_b.tsv input_5field_header_only.tsv input_5field_c.tsv" ${basic_tests_1}

runtest ${prog} "--group-by 1,2 --count --unique-count 3,4,5 input_5field_a.tsv empty_file.tsv input_5field_b.tsv input_5field_header_only.tsv input_5field_c.tsv" ${basic_tests_1}

runtest ${prog} "--write-header --group-by 1,2 --count --unique-count 3,4,5 input_5field_a.tsv empty_file.tsv input_5field_b.tsv input_5field_header_only.tsv input_5field_c.tsv" ${basic_tests_1}

## runtest can't create a command lines with standard input. Write them out.
echo "" >> ${basic_tests_1}; echo "====[cat input_5field_a.tsv | tsv-summarize --header --count --min 3,4,5 --max 3,4,5]====" >> ${basic_tests_1}
cat input_5field_a.tsv | ${prog} --header --count --group-by 2 --min 3,4,5 --max 3,4,5 >> ${basic_tests_1} 2>&1

echo "" >> ${basic_tests_1}; echo "====[cat input_5field_b.tsv | tsv-summarize --header --count --group-by 2 --min 3,4,5 --max 3,4,5 input_5field_a.tsv - input_5field_c.tsv]====" >> ${basic_tests_1}
cat input_5field_b.tsv | ${prog} --header --count --group-by 2 --min 3,4,5 --max 3,4,5 -- input_5field_a.tsv - input_5field_c.tsv >> ${basic_tests_1} 2>&1

## One-field files. Several special cases including an empty line.

runtest ${prog} "--header --count input_1field_a.tsv" ${basic_tests_1}
runtest ${prog} "--header --count empty_file.tsv" ${basic_tests_1}
runtest ${prog} "--header --count --unique-count 1 input_1field_a.tsv input_1field_b.tsv" ${basic_tests_1}
runtest ${prog} "--header --count --unique-count 1 input_1field_a.tsv input_1field_b.tsv empty_file.tsv" ${basic_tests_1}
runtest ${prog} "--header --group-by 1 --count --unique-count 1 input_1field_a.tsv input_1field_b.tsv " ${basic_tests_1}
runtest ${prog} "--header --group-by 1 --count --unique-count 1 input_1field_a.tsv input_1field_b.tsv empty_file.tsv" ${basic_tests_1}

runtest ${prog} "--count input_1field_a.tsv" ${basic_tests_1}
runtest ${prog} "--count empty_file.tsv" ${basic_tests_1}
runtest ${prog} "--count --unique-count 1 input_1field_a.tsv input_1field_b.tsv" ${basic_tests_1}
runtest ${prog} "--count --unique-count 1 input_1field_a.tsv input_1field_b.tsv empty_file.tsv" ${basic_tests_1}
runtest ${prog} "--group-by 1 --count --unique-count 1 input_1field_a.tsv input_1field_b.tsv " ${basic_tests_1}
runtest ${prog} "--group-by 1 --count --unique-count 1 input_1field_a.tsv input_1field_b.tsv empty_file.tsv" ${basic_tests_1}

runtest ${prog} "--count input_1field_a.tsv --exclude-missing" ${basic_tests_1}
runtest ${prog} "--values 1 input_1field_a.tsv --exclude-missing" ${basic_tests_1}
runtest ${prog} "--count input_1field_a.tsv --replace-missing XYZ" ${basic_tests_1}
runtest ${prog} "--values 1 input_1field_a.tsv --replace-missing XYZ" ${basic_tests_1}

runtest ${prog} "--count empty_file.tsv --exclude-missing" ${basic_tests_1}
runtest ${prog} "--count empty_file.tsv --replace-missing XYZ" ${basic_tests_1}

## Help and Version printing

echo "" >> ${basic_tests_1}
echo "Help and Version printing 1" >> ${basic_tests_1}
echo "-----------------" >> ${basic_tests_1}
echo "" >> ${basic_tests_1}

echo "====[tsv-summarize --help | grep -c Synopsis]====" >> ${basic_tests_1}
${prog} --help 2>&1 | grep -c Synopsis >> ${basic_tests_1} 2>&1

echo "====[tsv-summarize --version | grep -c 'tsv-summarize (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} --version 2>&1 | grep -c 'tsv-summarize (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1

echo "====[tsv-summarize -V | grep -c 'tsv-summarize (eBay/tsv-utils-dlang)']====" >> ${basic_tests_1}
${prog} -V 2>&1 | grep -c 'tsv-summarize (eBay/tsv-utils-dlang)' >> ${basic_tests_1} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "--count no_such_file.tsv" ${error_tests_1}
runtest ${prog} "--unique-count 0 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--unique-count 2, input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--unique-count 2: input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--unique-count 2,3:my_header input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--unique-count 2-5:my_header input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--retain 2:my_header input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--unique-count x input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--unique-count 2 input_5field_a.tsv input_1field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 1 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 0 --count input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 0 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 2, input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 2: input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by x input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 2 --unique-count 1 input_5field_a.tsv input_1field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 1- input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--group-by 3-0 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--header --max 1 input_1field_a.tsv" ${error_tests_1}
runtest ${prog} "-d abc --count input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "-d ß --count input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "-v abc --count input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "-v ß --count input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--count --exclude-missing --replace-missing XYZ input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3:2 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3:0.5,2 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 0:0.5 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3,4:0.75:q3 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3:0.25,0.75:q1q3 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3, input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 3- input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 0:0.25 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 1.5:0.25 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile 1-:0.25 input_5field_a.tsv" ${error_tests_1}
runtest ${prog} "--quantile -2:0.25 input_5field_a.tsv" ${error_tests_1}
