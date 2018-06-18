_Visit the [main page](../README.md)_

# Performance Studies

* [Comparative Benchmark Study](#comparative-benchmark-study)
* [LTO and PGO studies](#lto-and-pgo-studies)

## Comparative Benchmark Study

Performance is a key motivation for using D rather an interpreted language like Python or Perl. It is also a consideration in choosing between D and C/C++. To gauge D's performance, benchmarks were run comparing eBay's TSV Utilities to a number of similar tools written in other native compiled programming languages. Included were traditional Unix tools as well as several specialized toolkits. Programming languages involved were C, Go, and Rust.

The larger goal was to see how D programs would compare when written in a straightforward style, as if by a team of well qualified programmers in the course of normal development. Attention was giving to choosing good algorithms and identifying poorly performing code constructs, but heroic measures were not used to gain performance. D's standard library was used extensively, without writing custom versions of core algorithms or containers. Unnecessary GC allocation was avoided, but GC was used rather manual memory management. Higher-level I/O primitives were used rather than custom buffer management.

This larger goal was also the motivation for using multiple benchmarks and a variety of tools. Single points of comparison are more likely to be biased (less reliable) due to the differing goals and quality of the specific application.

The study was conducted in March 2017. An update done in April 2018 using the fastest tools from the initial study.

* [March 2017 Comparative Benchmark Study](ComparativeBenchmarks2017.md)
* [April 2018 Comparative Benchmark Update](ComparativeBenchmarks2018.md)

The D programs performed extremely well, exceeding the author's expectations. Six benchmarks were used in the 2017 study, the D tools were the fastest on each, often by significant margins. This is impressive given that very little low-level programming was done. In the 2018 update the TSV Utilities were first or second on all benchmarks. The TSV Utilities were faster than in 2017, but several of the other tools had gotten faster as well.

As with most benchmarks, there are caveats. The tools used for comparison are not exact equivalents, and in many cases have different design goals and capabilities likely to impact performance. Tasks performed are highly I/O dependent and follow similar computational patterns, so the results may not transfer to other applications.

Despite limitations of the benchmarks, this is certainly a good result. The benchmarks engage a fair range of programming constructs, and the comparison basis includes nine distinct implementations and several long tenured Unix tools. As a practical matter, performance of the tools has changed the author's personal work habits, as calculations that used to take 15-20 seconds are now instantaneous, and calculations that took minutes often finish in 10 seconds or so.

## LTO and PGO studies

In the fall of 2017 eBay's TSV Utilities were used as the basis for studying Link Time Optimization (LTO) and Profile Guided Optimization (PGO). In D, the LLVM versions of these technologies are made available via LDC, the LLVM-based D Compiler.

Both LTO and PGO resulted in significant performance gains. Details are on the [LTO and PGO Evaluation](lto-pgo-study.md) page.

Additional information about LTO and PGO can be found on the [Building with LTO and PGO](BuildingWithLTO.md) page. The slide decks from presentations at [Silicon Valley D Meetup (December 2017)](dlang-meetup-14dec2017.pdf) and [DConf 2018](dconf2018.pdf) also contain useful information, including additional references to other resources about LTO and PGO.
