/** tsv-utils version file.
 */

module tsv_utils.common.tsvutils_version;

enum string tsvutilsVersion = "v1.4.4";

string tsvutilsVersionNotice (string toolName)
{
    return toolName ~ " (eBay/tsv-utils) " ~ tsvutilsVersion ~ "\n" ~ q"EOS
Copyright (c) 2015-2020, eBay Inc.
https://github.com/eBay/tsv-utils
EOS";
}

unittest
{
    string programName = "program.name";
    assert(tsvutilsVersionNotice(programName).length > programName.length);
}
