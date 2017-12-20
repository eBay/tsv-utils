#! /bin/sh

if [ $# -eq 0 ]; then
    echo "Insufficient arguments. The path of the instrumented program is required."
    exit 1
fi

prog=$1
shift

for f in profile.*.raw; do
    if [ -e $f ]; then
        rm $f
    fi
done

if [ -e app.profdata ]; then
   rm -f app.profdata
fi

## All operators get at least one call, but the basic arithmetic operators are the
## most common, make sure they are overweighted.
$prog profile_data_1.tsv -H --lt 3:0 > /dev/null
$prog profile_data_1.tsv -H --le 2:0 > /dev/null
$prog profile_data_1.tsv -H --ge 16:0 > /dev/null
$prog profile_data_1.tsv -H --gt 17:0 > /dev/null
$prog profile_data_1.tsv -H --lt 8:-1.11 > /dev/null
$prog profile_data_1.tsv -H --gt 12:10000000 > /dev/null
$prog profile_data_1.tsv -H --le 19:-10 > /dev/null
$prog profile_data_1.tsv -H --ge 18:10 > /dev/null
$prog profile_data_1.tsv -H --gt 6:-55 --lt 9:-0.2 > /dev/null
$prog profile_data_1.tsv -H --ge 3:0.002 --le 14:0.0005 > /dev/null
$prog profile_data_1.tsv -H --gt 1:-2.8899720283 --lt 1:2.82987744963 > /dev/null
$prog profile_data_1.tsv -H --gt 14:0.000242308466917 --lt 14:0.00071920351827 > /dev/null
$prog profile_data_1.tsv -H --gt 15:-54.2458244835 --lt 15:57.8627273685 > /dev/null
$prog profile_data_1.tsv -H --invert --le 1:2.2 --lt 16:1.11 > /dev/null
$prog profile_data_1.tsv -H --or --ge 4:1.65 --lt 5:22.0 > /dev/null
$prog profile_data_1.tsv -H --invert --or --ge 18:-15 --lt 20:-15 > /dev/null
$prog profile_data_2.tsv --ge 2:573 --le 2:629 > /dev/null
$prog profile_data_2.tsv --ge 3:22 --le 3:76 > /dev/null
$prog profile_data_2.tsv --ge 4:120 --le 4:303 > /dev/null
$prog profile_data_2.tsv --or --eq 2:646 --eq 2:647 --eq 2:609 > /dev/null
$prog profile_data_2.tsv --ne 2:622 --ne 2:642 --ne 2:649 > /dev/null
$prog profile_data_2.tsv --or --eq 3:16 --gt 4:570 --ge 3:140 --le 3:3 --lt 2:510 > /dev/null

## Most of the other operators start here
$prog profile_data_5.tsv --ff-eq 2:3 > /dev/null
$prog profile_data_5.tsv --ff-ne 3:4 > /dev/null
$prog profile_data_5.tsv --ff-le 3:2 > /dev/null
$prog profile_data_5.tsv --ff-le 4:2 > /dev/null
$prog profile_data_5.tsv --ff-lt 4:3 > /dev/null
$prog profile_data_5.tsv --ff-ge 4:3 > /dev/null
$prog profile_data_5.tsv --ff-gt 2:4 > /dev/null
$prog profile_data_5.tsv --ff-str-eq 2:3 > /dev/null
$prog profile_data_5.tsv --ff-istr-eq 2:3 > /dev/null
$prog profile_data_5.tsv --ff-str-ne 3:4 > /dev/null
$prog profile_data_5.tsv --ff-istr-ne 3:4 > /dev/null
$prog profile_data_1.tsv -H --ff-absdiff-le 10:17:1.11 > /dev/null
$prog profile_data_1.tsv -H --ff-absdiff-gt 9:10:2.5 > /dev/null
$prog profile_data_1.tsv -H --ff-reldiff-le 1:17:2.0 > /dev/null
$prog profile_data_1.tsv -H --ff-reldiff-gt 1:17:2.0 > /dev/null
$prog profile_data_5.tsv -H --str-eq 1:weiß --str-ne 3:2 > /dev/null
$prog profile_data_5.tsv -H --or --istr-eq 1:Grün --str-eq 1:日本語 --istr-ne 1:YELLOW > /dev/null
$prog profile_data_4.tsv -H --str-le 4:cab --str-gt 5:RR > /dev/null
$prog profile_data_4.tsv -H --invert --str-lt 4:cab --str-ge 5:RR > /dev/null
$prog profile_data_4.tsv -H --str-in-fld 4:ba --str-not-in-fld 5:T > /dev/null
$prog profile_data_4.tsv -H --istr-in-fld 4:ab --istr-not-in-fld 5:xx > /dev/null
$prog profile_data_4.tsv -H --regex 4:'ab[ac]d' > /dev/null
$prog profile_data_4.tsv -H --regex 4:'b.+c*a' > /dev/null
$prog profile_data_4.tsv -H --regex 4:'d.+d.+e' > /dev/null
$prog profile_data_4.tsv -H --iregex 5:'^x.+z$' > /dev/null
$prog profile_data_4.tsv -H --not-regex 4:'ab[^ab]+ab' --not-iregex 5:xx.+z > /dev/null
$prog profile_data_4.tsv -H --regex 4:'^e+[^bde]+[bd]' > /dev/null
$prog profile_data_4.tsv -H --or --blank 3 --is-numeric 3 > /dev/null
$prog profile_data_4.tsv -H --empty 3 > /dev/null
$prog profile_data_4.tsv -H --not-empty 3 > /dev/null
$prog profile_data_4.tsv -H --not-blank 3 > /dev/null
$prog profile_data_4.tsv -H --is-infinity 2 > /dev/null
$prog profile_data_4.tsv -H --is-finite 2 > /dev/null
$prog profile_data_4.tsv -H --is-numeric 3 > /dev/null
$prog profile_data_4.tsv -H --is-nan 3 > /dev/null
$prog profile_data_4.tsv -H --is-finite 3 --le 3:30 > /dev/null

ldc-profdata merge -o app.profdata profile.*.raw
