#! /bin/sh

## Most tsv-split testing is done using this script, which runs against the final
## executable. There are some unit tests in the code, but it is hard to capture
## much of the file system interaction using unit tests.

if [ $# -le 1 ]; then
    echo "Insufficient arguments. A program name and output directory are required."
    exit 1
fi

prog=$1
shift
odir=$1
echo "Testing ${prog}, output to ${odir}"

##
## 'runtest' is used when no files are expected, only output to standard output or
## standard error. This routine is used for '--help', '--version', command line error
## outputs, etc. It is the same as the 'runtest' used by most tsv-utils command line
## test utilities.
##
## Three args: program, args, output file
runtest () {
    echo "" >> $3
    echo "====[tsv-sample $2]====" >> $3
    $1 $2 >> $3 2>&1
    return 0
}

##
## 'runtest_wdir' is used when a 'work directory' is needed to capture the output
## from multiple files produces by tsv-split. It is the primary way to test tsv-split.
##
## 'runtest_wdir' works differently than most of the other command line test programs
## in tsv-utils repo. In particular, because 'tsv-split' produces multiple output
## files, having a single file comparison basis is setup differently. This version
## of 'runtest' generates a directory with multiple files, then concatenates the
## result files using 'tail -n +1'. This concatenates all files with a header line
## giving the file name between.
##
## For consistency with the other tsv-utils test scripts, this routine takes the
## same three arguments as the standard 'runtest' scripts. A fourth logical
## parameter, the working directory, is defined globally rather than as a function
## argument.
##
## IMPORTANT:
## (1) Files passed to tsv-split must be prefixed by '${testdir_relpath}/. This is
##     because the program is not run from the main test directory.
## (2) tsv-split args containing the '--dir' parameter must use relative paths. The
##     relative path directory must be passed as a fourth argument to this routine.
##     There is no ability to specify absolute paths using this routine.
##
## Three required args: program, args, output file
## One optional arg: relative directory to write files to.
##

workdir="./tsvsplit_workdir"
testdir_relpath='..'

runtest_wdir () {
    echo "" >> $3
    echo "====[tsv-split $2]====" >> $3

    rm -rf ${workdir}

    output_dir="${workdir}"
    if [[ ! -z "$4" ]]; then
        output_dir="${workdir}/${4}"
    fi

    mkdir -p ${output_dir}
    ( cd ${workdir} && $1 $2 >> ${testdir_relpath}/${3} 2>&1 )
    tail -n +1 ${output_dir}/* >> $3 2>&1

    rm -rf ${workdir}

    return 0
}
help_and_version_tests=${odir}/help_and_version_tests.txt
lines_per_file_tests=${odir}/lines_per_file_tests.txt
random_assignment_tests=${odir}/random_assignment_tests.txt
key_assignment_tests=${odir}/key_assignment_tests.txt

echo "Lines per file tests" > ${lines_per_file_tests}
echo "-----------------" >> ${lines_per_file_tests}

runtest_wdir ${prog} "--lines-per-file 1 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "--lines-per-file 2 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 3 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 4 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 5 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 6 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "--lines-per-file 1 --header ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "--lines-per-file 2 -H ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 3 -H ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 4 -H ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 5 -H ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 6 -H ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "-l 1 --header-in-only ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 2 -I ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 3 -I ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 4 -I ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 5 -I ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 6 -I ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "-l 1 ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 2 ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 7 ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 8 ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "-l 1 -H ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 2 -H ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 7 -H ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 8 -H ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "-l 1 -I ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 2 -I ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 7 -I ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 8 -I ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "-l 3 --prefix pre_ --suffix _post ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 3 --suffix .txt ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 3 --prefix pre ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}

runtest_wdir ${prog} "-l 3 --dir odir ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests} odir
runtest_wdir ${prog} "-l 3 --dir odir --prefix pre_ --suffix _post ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests} odir

## Help and Version printing

echo "" >> ${help_and_version_tests}
echo "Help and Version printing 1" >> ${help_and_version_tests}
echo "-----------------" >> ${help_and_version_tests}
echo "" >> ${help_and_version_tests}

echo "====[tsv-split --help | grep -c Synopsis]====" >> ${help_and_version_tests}
${prog} --help 2>&1 | grep -c Synopsis >> ${help_and_version_tests} 2>&1

# echo "====[tsv-split --help-verbose | grep -c Synopsis]====" >> ${help_and_version_tests}
# ${prog} --help-verbose 2>&1 | grep -c Synopsis >> ${help_and_version_tests} 2>&1

echo "====[tsv-split --version | grep -c 'tsv-split (eBay/tsv-utils)']====" >> ${help_and_version_tests}
${prog} --version 2>&1 | grep -c 'tsv-split (eBay/tsv-utils)' >> ${help_and_version_tests} 2>&1

echo "====[tsv-split -V | grep -c 'tsv-split (eBay/tsv-utils)']====" >> ${help_and_version_tests}
${prog} -V 2>&1 | grep -c 'tsv-split (eBay/tsv-utils)' >> ${help_and_version_tests} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

