#!/usr/bin/env bash

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

## A hack for now - Know the exact relative path of the dircat program.
dircat_prog='../../buildtools/dircat'

if [ ! -e "$dircat_prog" ]; then
    echo "Program $dircat_prog does not exist."
    echo "Is 'cd buildtools && make' needed?."
    exit 1
fi

if [ ! -x "$dircat_prog" ]; then
    echo "Program $dircat_prog is not an executable."
    exit 1
fi

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
## result files using 'dircat' from the 'buildtools' directory. This concatenates
## all files with a header line giving the file name between. The result is similar
## to 'tail -n +1', but more consistent across platforms.
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
    prog=$1
    shift
    
    args=$1
    shift

    output_file=$1
    shift

    dir=$1
    
    echo "" >> ${output_file}
    echo "====[tsv-split ${args}]====" >> ${output_file}

    rm -rf ${workdir}

    output_dir="${workdir}"
    if [[ ! -z "${dir}" ]]; then
        output_dir="${workdir}/${dir}"
    fi

    mkdir -p ${output_dir}
    ( cd ${workdir} && ${prog} --DRT-covopt="dstpath:../" ${args} >> ${testdir_relpath}/${output_file} 2>&1 )
    ${dircat_prog} ${output_dir} >> ${output_file} 2>&1

    rm -rf ${workdir}

    return 0
}

## This variant appends multiple file sets. Each input file is
## provided as a separate argument.
##
## Arguments: program, args, output-file, file1 [... fileN]
runtest_wdir_append () {
    prog=$1
    shift
    
    args=$1
    shift

    output_file=$1
    shift

    input_file=$1
    shift
    
    echo "" >> $output_file
    rm -rf ${workdir}
    mkdir -p ${workdir}

    while [ ! -z "$input_file" ]
    do
        echo "====[tsv-split $args $input_file]====" >> $output_file
        ( cd ${workdir} && $prog --DRT-covopt="dstpath:../" $args $input_file >> ${testdir_relpath}/${output_file} 2>&1 )
        input_file=$1
        shift
    done
    
    ${dircat_prog} ${workdir} >> ${output_file} 2>/dev/null
    rm -rf ${workdir}

    return 0
}

## This variant sets the ulimit open files limit
## Arguments: program, args, output-file, max-open-files
runtest_wdir_ulimit () {
    prog=$1
    shift
    
    args=$1
    shift

    output_file=$1
    shift

    ulimit_max_open_files=$1
    
    echo "" >> ${output_file}
    echo "====[ulimit -Sn ${ulimit_max_open_files} && tsv-split ${args}]====" >> ${output_file}

    rm -rf ${workdir}
    mkdir -p ${workdir}
    ( cd ${workdir} && ulimit -Sn ${ulimit_max_open_files} && ${prog} --DRT-covopt="dstpath:../" ${args} >> ${testdir_relpath}/${output_file} 2>&1 )
    ${dircat_prog} ${output_dir} >> ${output_file} 2>/dev/null

    rm -rf ${workdir}

    return 0
}

## This variant cats a file to standard input
## Arguments: program, args, output-file, input-file
runtest_wdir_stdin () {
    prog=$1
    shift
    
    args=$1
    shift

    output_file=$1
    shift

    input_file=$1
    
    echo "" >> ${output_file}
    echo "====[cat ${input_file} | tsv-split ${args}]====" >> ${output_file}

    rm -rf ${workdir}
    mkdir -p ${workdir}
    ( cd ${workdir} && cat ${input_file} | ${prog} --DRT-covopt="dstpath:../" ${args} >> ${testdir_relpath}/${output_file} 2>&1 )
    tail -n +1 ${workdir}/* >> ${output_file} 2>&1

    rm -rf ${workdir}

    return 0
}

##
## Tests begin here
##

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

runtest_wdir ${prog} "-l 1 --digit-width 1 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}
runtest_wdir ${prog} "-l 1 -w 5 ${testdir_relpath}/input1x5.txt" ${lines_per_file_tests}

runtest_wdir_append ${prog} "-l 3 --append" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt
runtest_wdir_append ${prog} "-H -l 3 -a" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt
runtest_wdir_append ${prog} "-I -l 3 --append" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x3.txt

runtest_wdir_stdin ${prog} "-l 3" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-H -l 3" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-I -l 3" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt

runtest_wdir_stdin ${prog} "-l 3 -- - ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-H -l 3 -- - ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-I -l 3 -- - ${testdir_relpath}/input1x3.txt" ${lines_per_file_tests} ${testdir_relpath}/input1x5.txt

echo "Random assignment tests" > ${random_assignment_tests}
echo "-----------------------" >> ${random_assignment_tests}

runtest_wdir ${prog} "--static-seed --num-files 2 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 3 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 5 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 10 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 11 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 101 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "-s --num-files 2 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 11 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-s -n 101 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "--seed-value 15017 --num-files 2 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 11 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 2 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "-v 15017 -n 2 -H ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 -H ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 2 -H ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 -H ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "-v 15017 -n 2 -I ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 -I ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 2 -I ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 -I ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "-v 15017 -n 3 --prefix pre_ ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --prefix pre_ ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 3 --prefix pre_ --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --prefix pre_ --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "-v 15017 -n 3 --dir odir --prefix pre_ ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} odir
runtest_wdir ${prog} "-v 15017 -n 3 --dir odir --prefix pre_ ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} odir
runtest_wdir ${prog} "-v 15017 -n 3 --dir odir --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} odir
runtest_wdir ${prog} "-v 15017 -n 3 --dir odir --prefix pre_ --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} odir
runtest_wdir ${prog} "-v 15017 -n 101 --dir odir --prefix pre_ --suffix .txt ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} odir

runtest_wdir ${prog} "-v 15017 -n 101 --max-open-files 5 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --max-open-files 6 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --max-open-files 11 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --max-open-files 12 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 --max-open-files 13 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir ${prog} "-v 15017 -n 20 --digit-width 1 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 20 -w 5 ${testdir_relpath}/input1x5.txt" ${random_assignment_tests}

runtest_wdir_ulimit ${prog} "-v 15017 -n 101 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} 5
runtest_wdir_ulimit ${prog} "-v 15017 -n 101 --max-open-files 5 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} 5
runtest_wdir_ulimit ${prog} "-v 15017 -n 101 ${testdir_relpath}/input1x3.txt ${testdir_relpath}/input1x5.txt" ${random_assignment_tests} 6

runtest_wdir_append ${prog} "-v 15017 -n 3 --append" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt
runtest_wdir_append ${prog} "-v 15017 -n 3 -H --append" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt
runtest_wdir_append ${prog} "-v 15017 -n 3 -I -a" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt

runtest_wdir_stdin ${prog} "-s -n 101" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-s -n 101 -H" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-s -n 101 -I" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt

runtest_wdir_stdin ${prog} "-v 15017 -n 101 -- ${testdir_relpath}/input1x3.txt -" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-v 15017 -n 101 -H -- ${testdir_relpath}/input1x3.txt -" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt
runtest_wdir_stdin ${prog} "-v 15017 -n 101 -I -- ${testdir_relpath}/input1x3.txt -" ${random_assignment_tests} ${testdir_relpath}/input1x5.txt


echo "Key assignment tests" > ${key_assignment_tests}
echo "--------------------" >> ${key_assignment_tests}

runtest_wdir ${prog} "--static-seed --num-files 2 --key-fields 1 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 2 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 10 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 11 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 101 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 2 -k 1,3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 17 -k 1,3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 101 -k 1,3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 2 -k 1,3,4 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}

runtest_wdir ${prog} "--seed-value 15017 --num-files 2 --key-fields 1 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}

runtest_wdir ${prog} "-v 15017 -n 101 -k 0 ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 101 -k 1,3 ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests}

runtest_wdir ${prog} "--header --static-seed --num-files 2 --key-fields 1 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-H -v 15017 -n 101 -k 1,3 ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests}

runtest_wdir ${prog} "--header-in-only --static-seed --num-files 2 --key-fields 1 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-I -s -n 11 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-I -s -n 101 -k 1,3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-I -v 15017 -n 101 -k 1,3 ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests}

runtest_wdir ${prog} "-H -s -n 2 -k 1 --prefix pre_ ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-H -s -n 2 -k 1 --suffix _suf ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-H -s -n 2 -k 1 --prefix pre_ --suffix _suf ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}

runtest_wdir ${prog} "-H -s -n 2 -k 1 --dir odir ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} odir
runtest_wdir ${prog} "-H -s -n 2 -k 1 --prefix pre_ --dir odir ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} odir
runtest_wdir ${prog} "-H -s -n 2 -k 1 --suffix _suf --dir odir ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} odir
runtest_wdir ${prog} "-H -s -n 2 -k 1 --prefix pre_ --suffix _suf --dir odir ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} odir

runtest_wdir ${prog} "-v 15017 -n 20 -k 0 --digit-width 1 ${testdir_relpath}/input1x5.txt" ${key_assignment_tests}
runtest_wdir ${prog} "-v 15017 -n 20 -k 0 -w 5 ${testdir_relpath}/input1x5.txt" ${key_assignment_tests}

runtest_wdir ${prog} "-s -n 101 --max-open-files 5 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 101 --max-open-files 6 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 101 --max-open-files 22 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 101 --max-open-files 23 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-s -n 101 --max-open-files 24 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests}

runtest_wdir_ulimit ${prog} "-s -n 101 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} 5
runtest_wdir_ulimit ${prog} "-s -n 101 --max-open-files 5 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} 5
runtest_wdir_ulimit ${prog} "-s -n 101 -k 3 ${testdir_relpath}/input4x58.tsv" ${key_assignment_tests} 6

runtest_wdir_append ${prog} "-s -n 11 -k 3 --append" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x58.tsv
runtest_wdir_append ${prog} "-s -n 11 -k 3 -H --append" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x58.tsv
runtest_wdir_append ${prog} "-s -n 11 -k 3 -I -a" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv ${testdir_relpath}/input4x58.tsv

runtest_wdir_stdin ${prog} "-s -n 101 -k 3" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv
runtest_wdir_stdin ${prog} "-s -n 101 -k 3 -H" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv
runtest_wdir_stdin ${prog} "-s -n 101 -k 3 -I" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv
runtest_wdir_stdin ${prog} "-v 15017 -n 101 -k 1,3 -- - ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv
runtest_wdir_stdin ${prog} "-v 15017 -n 101 -k 1,3 -H -- - ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv
runtest_wdir_stdin ${prog} "-v 15017 -n 101 -k 1,3 -I -- - ${testdir_relpath}/input4x18.tsv" ${key_assignment_tests} ${testdir_relpath}/input4x58.tsv

runtest_wdir ${prog} "--delimiter : -s -n 101 -k 3 ${testdir_relpath}/input4x58_colon-delim.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-d : -H -s -n 101 -k 3 ${testdir_relpath}/input4x58_colon-delim.tsv" ${key_assignment_tests}
runtest_wdir ${prog} "-d : -I -s -n 101 -k 3 ${testdir_relpath}/input4x58_colon-delim.tsv" ${key_assignment_tests}


## Help and Version printing

echo "" >> ${help_and_version_tests}
echo "Help and Version printing 1" >> ${help_and_version_tests}
echo "-----------------" >> ${help_and_version_tests}
echo "" >> ${help_and_version_tests}

echo "====[tsv-split --help | grep -c Synopsis]====" >> ${help_and_version_tests}
${prog} --help 2>&1 | grep -c Synopsis >> ${help_and_version_tests} 2>&1

echo "====[tsv-split --help-verbose | grep -c Synopsis]====" >> ${help_and_version_tests}
${prog} --help-verbose 2>&1 | grep -c Synopsis >> ${help_and_version_tests} 2>&1

echo "====[tsv-split --version | grep -c 'tsv-split (eBay/tsv-utils)']====" >> ${help_and_version_tests}
${prog} --version 2>&1 | grep -c 'tsv-split (eBay/tsv-utils)' >> ${help_and_version_tests} 2>&1

echo "====[tsv-split -V | grep -c 'tsv-split (eBay/tsv-utils)']====" >> ${help_and_version_tests}
${prog} -V 2>&1 | grep -c 'tsv-split (eBay/tsv-utils)' >> ${help_and_version_tests} 2>&1

## Error cases

error_tests_1=${odir}/error_tests_1.txt

echo "Error test set 1" > ${error_tests_1}
echo "----------------" >> ${error_tests_1}

runtest ${prog} "input1x5.txt" ${error_tests_1}
runtest ${prog} "-l 10 no-such-file.txt" ${error_tests_1}
runtest ${prog} "-n 10 no-such-file.txt" ${error_tests_1}
runtest ${prog} "-n 10 -k 3 no-such-file.txt" ${error_tests_1}
runtest ${prog} "-n 0 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 0 -k 1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 1 -k 1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 2 -k 1.5 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 2 -k 0,1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 2 -k -1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 10 -k 99 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 10 --max-open-files 4 input1x5.txt" ${error_tests_1}
runtest ${prog} "-l 10 --dir no-such-directory input1x5.txt" ${error_tests_1}
runtest ${prog} "-n 10 --dir no-such-directory input1x5.txt" ${error_tests_1}
runtest ${prog} "-n 10 -k 1 --dir no-such-directory input4x58.tsv" ${error_tests_1}
runtest ${prog} "-l 10 -k 1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-l 10 -n 3 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-l 10 -n 3 -k 1 input4x58.tsv" ${error_tests_1}
runtest ${prog} "-l 10 --header --header-in-only input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 2 --prefix dir/file input4x58.tsv" ${error_tests_1}
runtest ${prog} "-n 2 --suffix ab/cd input4x58.tsv" ${error_tests_1}
runtest_wdir_ulimit ${prog} "-s -n 101 -k 3 --max-open-files 6 ${testdir_relpath}/input4x58.tsv" ${error_tests_1} 5
runtest_wdir_ulimit ${prog} "-s -n 101 -k 3 ${testdir_relpath}/input4x58.tsv" ${error_tests_1} 4
runtest_wdir_append ${prog} "-l 3" ${error_tests_1} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt
runtest_wdir_append ${prog} "-v 15017 -n 3" ${error_tests_1} ${testdir_relpath}/input1x5.txt ${testdir_relpath}/input1x5.txt
runtest_wdir_append ${prog} "-s -n 11 -k 3" ${error_tests_1} ${testdir_relpath}/input4x18.tsv ${testdir_relpath}/input4x18.tsv
