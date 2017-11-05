enum string tsvutilsVersion = "v1.1.15-beta3";

string tsvutilsVersionNotice (string toolName)
{
    return toolName ~ " (eBay/tsv-utils-dlang) " ~ tsvutilsVersion ~ "\n" ~ q"EOS
Copyright (c) 2015-2017, eBay Software Foundation
https://github.com/eBay/tsv-utils-dlang
EOS";
}

unittest
{
    string programName = "program.name";
    assert(tsvutilsVersionNotice(programName).length > programName.length);
}
