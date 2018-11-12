/** tsv-utils version file.
 */

module tsv_utils.common.tsvutils_version;

enum string tsvutilsVersion = "v1.3.2";

string tsvutilsVersionNotice (string toolName)
{
    return toolName ~ " (eBay/tsv-utils) " ~ tsvutilsVersion ~ "\n" ~ q"EOS
Copyright (c) 2015-2018, eBay Software Foundation
https://github.com/eBay/tsv-utils
EOS";
}

unittest
{
    string programName = "program.name";
    assert(tsvutilsVersionNotice(programName).length > programName.length);
}
