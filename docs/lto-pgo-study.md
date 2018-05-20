_Visit the [Performance Benchmarks home page](Performance.md)_
_Visit the [TSV Utilities main page](../README.md)_

# Link Time Optimization and Profile Guided Optimization Evaluation

Link Time Optimization (LTO) and Profile Guided Optimization (PGO) are LLVM compiler technologies supported by LDC, the LLVM D Compiler. Benchmarks were done in fall 2017 to see if these technologies would benefit the TSV Utilities. The same benchmarks were used as in the [March 2017 Comparative Benchmark Study](ComparativeBenchmarks2017.md). Material improvements were seen both in run-time performance and binary size. Both LTO and PGO are now used when building the pre-built binaries available on the [Github releases](https://github.com/eBay/tsv-utils-dlang/releases) page.

This page contains the performance numbers from the study. For more information about LTO and PGO see the [About Link Time Optimization](BuildingWithLTO.md#about-link-time-optimization-lto) and [About Profile Guided Optimization](BuildingWithLTO.md#about-profile-guided-optimization-pgo) sections of the [Building with LTO and PGO](BuildingWithLTO.md) page. The slide decks from presentations at [Silicon Valley D Meetup (December 2017)](dlang-meetup-14dec2017.pdf) and [DConf 2018](dconf2018.pdf) also contain useful information about these studies.

The benchmarks were first run without LTO or PGO. Then LTO was applied to the TSV Utilities code, excluding the D standard libraries (druntime and phobos). Then it was applied to both the TSV Utilities code and the D standard libraries. Finally, PGO was added on top of LTO, against both the TSV Utilities code and D standard libraries.

Using LTO on only the TSV Utilities application code had very limited impact, but LTO on both the application and D standard library code resulted in significant gains on several benchmarks. PGO also resulted in material improvements on several benchmarks.

LTO also resulted in meaningful binary size deltas. These deltas were much more significant on MacOS than Linux, suggesting there are other considerations in the way LDC builds release mode binaries on MacOS.

## Performance improvements

**MacOS**

| LTO/PGO               | tsv-summarize | csv2tsv | tsv-filter<br>(numeric) | tsv-filter<br>(regex) | tsv-select |   tsv-join |
| --------------------- | ------------: | ------: | ----------------------: | --------------------: | ---------: | ---------: |
| None                  |         21.79 |   25.43 |                    4.98 |                  7.71 |       4.23 |      21.33 |
| ThinLTO: App Only     |         22.40 |   25.58 |                    5.12 |                  7.59 |       4.17 |      21.24 |
| ThinLTO: App+Libs     |         10.41 |   21.41 |                    3.71 |                  7.04 |       4.05 |      20.11 |
| ThinLTO+PGO: App+Libs |          9.25 |   14.32 |                    3.50 |                  7.09 |       3.97 | not tested |
| **Improvement**       |               |         |                         |                       |            |            |
| ThinLTO: App+Libs     |           52% |     16% |                     26% |                    9% |         4% |         6% |
| ThinLTO+PGO: App+Libs |           58% |     44% |                     30% |                    8% |         6% | not tested |

**Linux**

| LTO/PGO               | tsv-summarize | csv2tsv | tsv-filter<br>(numeric) | tsv-filter<br>(regex) | tsv-select |   tsv-join |
| --------------------- | ------------: | ------: | ----------------------: | --------------------: | ---------: | ---------: |
| None                  |         30.81 |   47.64 |                    7.98 |                 12.17 |       6.45 | not tested |
| FullLTO: App+Libs     |         18.01 |   34.07 |                    6.46 |                 11.23 |       5.99 |            |
| FullLTO+PGO: App+Libs |         16.90 |   31.31 |                    6.17 |                 11.15 |       5.93 |            |
| **Improvement**       |               |         |                         |                       |            |            |
| FullLTO: App+Libs     |           42% |     28% |                     19% |                    8% |         7% |            |
| FullLTO+PGO: App+Libs |           45% |     34% |                     23% |                    8% |         8% |            |

## LTO binary size deltas

**MacOS sizes (bytes)**

| LTO               | tsv-summarize |   csv2tsv | tsv-filter | tsv-select |  tsv-join |
| ----------------- | ------------: | --------: | ---------: | ---------: | --------: |
| None              |     7,988,448 | 6,709,936 |  8,137,804 |  6,890,192 | 6,945,336 |
| ThinLTO: App Only |     6,949,712 | 6,643,344 |  6,639,844 |  6,676,000 | 6,688,392 |
| ThinLTO: App+Libs |     3,082,068 | 2,679,184 |  3,172,648 |  2,734,356 | 2,738,700 |
| Reduction         |           61% |       60% |        61% |        60% |       61% |

**Linux sizes (bytes)**

| LTO               | tsv-summarize |   csv2tsv | tsv-filter | tsv-select |  tsv-join |
| ----------------- | ------------: | --------: | ---------: | ---------: | --------: |
| None              |     1,400,672 |   995.760 |  1,743,288 |  1,026,344 | 1,049,176 |
| ThinLTO: App Only |     1,300,792 |   998,432 |  1,547,656 |  1,024,312 | 1,036,648 |
| ThinLTO: App+Libs |     1,154,808 |   826,064 |  1,359,554 |    856,064 |   868,736 |
| Reduction         |           18% |       17% |        22% |        17% |       17% |
