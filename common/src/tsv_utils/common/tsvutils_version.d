/** tsv-utils version file.
 */

module tsv_utils.common.tsvutils_version;

enum string tsvutilsVersion = "v2.2.3";

string tsvutilsVersionNotice (string toolName) @safe pure nothrow
{
    return toolName ~ " (eBay/tsv-utils) " ~ tsvutilsVersion ~ "\n" ~ q"EOS
Copyright (c) 2015-2021, eBay Inc.
https://github.com/eBay/tsv-utils
EOS";
}

@safe unittest
{
    string programName = "program.name";
    assert(tsvutilsVersionNotice(programName).length > programName.length);
}
