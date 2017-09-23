# Coding notes for tsv-pretty

This file contains some miscellaneous notes about the code in tsv-pretty.d

## Auto-detect header

*Definition*: First line in a file is declared a header if any column is identified as numeric when considering all rows but the first in the look-ahead cache, and the first row cannot be parsed as numeric.

The expectation is that if all values except the first are numeric, then the first row is likely a header. This will not work for all files, but will work for most files that have numeric data. Only the values in the look-ahead cache are considered, but if enough lines are read it should be reasonably reliable.

*Multiple files*: Another good clue whether the first line is a header or not is if the first lines multiple files are identical. This comes into play if the look-ahead cache is not filled when the second file is read. When this occurs an auto-detect decision is made when the second file is read, without waiting to fill the look-ahead cache. This greatly simplifies the algorithm.

## TsvPrettyProcessor algorithms

The different command line options and processing behavior create a somewhat complex algorithm, one that is not as easy to follow from the code as would be nice. A sketch of the original algorithms are below. The complexity is due largely to header auto-detection, the look-ahead cache, and multiple files. Note that the code may divert from this over time.

*Processing the first line of each file*
```
 A) CmdOptions.noHeader: Process as a normal data line
 B) CmdOptions.hasHeader:
    a) First file: Set-as-header for the line.
       i) CmdOptions.lookahead == 0:
          Output lookahead cache (finalizes field formats, outputs header, sets not caching)
       j) CmdOptions.lookahead > 0: Do nothing
    b) 2nd+ file: Ignore the line (do nothing)
 C) CmdOptions.autoDetectHeader
    a) Detected-as-no-header: Process as normal data line
    b) Detected-as-header: Assert: 2nd+ file; Ignore the line (do nothing)
    c) No detection yet
       Assert: Still doing lookahead caching
       Assert: First or second file
       i) First file: Set as candidate header
       j) Second file: Compare to first candidate header
          p) Equal to first candidate header:
             Set detected-as-header
             Set-as-header for the line
          q) !Equal to first candidate header:
             Set detected-as-no-header
             Add-fields-to-line format for first candidate-header
             Process line as data line
       IMPLIES: Header detection can occur prior to lookahead completion.
 ```

*Processing each data line*
```
A) Not caching: Output data line
B) Still caching
   Append data line to cache
   if cache is full: output look-ahead cache
      (finalizes field formats, outputs the header, sets not caching, etc.)
```

*Finish all processing*
```
A) Not caching: Do nothing (done)
B) Still caching: Output lookahead cache
```

*Output lookahead cache*
```
All:
   if CmdOptions.autoDetectHeader && not-detected-yet:
      Compare field formats to candidate field formats
      A) Looks-like-header: Set detected-as-header
      B) Look-like-not-header:
         Set detected-as-no-header
         Add-field-to-line-format for candidate header
All:
   Finalize field formatting
   A) _options.hasHeader || detected-as-header: output header
   B) _options.autoDetectHeader && detected-as-not-header && candidate-header filled in:
      Output candidate header as data line

All:
   Output data line cache
   Set as not caching
```

## Field Formatting and alignment

Format choices are simple when all values in a column are similar. The become more difficult when data is less consistent. The approach to alignment used in this program are as follows:

- Text columns: Values always left-aligned, unchanged.
- Integer columns: Values always right-aligned, unchanged.
- Floating point columns, not formatted:
  - Floating point values aligned on decimal point
  - Integer values aligned on decimal point
  - Exponential values right aligned
  - Text values right aligned
- Exponential columns, not formatted:
  - Values always right-aligned, unchanged.
- Floating point columns, formatted:
  - Floating point value
    - Raw precision <= column precision:
      - Zero-pad raw value to precision
    - Raw precision > column precision: Format with %f
  - Integer value: Format with %f
  - Text value: Right align
  - Exponent: Right align
- Exponential columns, formatted
  - Exponential value:
    - Raw precision <= column precision:
      - Zero-pad raw value to precision
    - Raw precision > column precision: Format with %e
  - Floating point value: Format with %e
  - Integer value: Format with %e
  - Text value: Right align

## Print length calculations

This programs aligns data assuming fixed width characters. Input data is assumed to be UTF-8. In UTF-8, many characters are represented with multiple bytes. Unicode also includes "combining characters", characters that modify the print representation of an adjacent character.

In D a printable character is represented as a "grapheme". A grapheme is a base character plus any adjacent combining characters. A grapheme then is one or more characters, and each character represented as one or more bytes in the `string` data type.

The number of graphemes in a string can be calculated as follows:
```
import std.uni : byGrapheme;
import std.range : walkLength;
size_t graphemeLength = myUtf8String.byGrapheme.walkLength;
```

The grapheme length is a good measure of the number of user perceived characters printed. For European character sets this is a good measure of print width. However, this is still not correct, as many Asian characters are printed as double-width in many fixed-width fonts. This program uses a hack to get a better approximation: It checks the first code point in a grapheme is a CJK character. (The first code point is normally the "grapheme-base".) If the first character is CJK, a print width of two is assumed. This is hardly foolproof, and should not be used if higher accuracy is needed. However, it does do well enough to properly handle many common alignments, and is much better than doing nothing.

Note: A more accurate approach would be to use an equivalent of wcwidth/wcswidth. This is a POSIX function available on many systems. This could be used when available. The functionality is defined as part of the Unicode standard, and could be derived directly from Unicode tables as well. See [Unicode® Standard Annex #11: East Asian Width](http://unicode.org/reports/tr11/).
