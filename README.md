# What is this?

This repository consists of two parts:

  * Benchmark results (for most categories) for the node.js master branch that
    are collected daily
  * A web UI to consume the data

# Hardware

* Diskless (PXE boot and ran entirely from RAM)
* From the beginning (2020-02-03) through 2021-03-11: Core i7-860 with 16GB
  DDR3-1600 RAM running Debian Buster (10.x)
* From 2021-03-13 to current: Core i5-8500T with 40GB DDR4-2666 RAM running
  Debian Buster (10.x)

# Background

I wanted to set up an automated process that would continuously run node.js'
benchmarks so as to help catch (unintended) performance regressions as
(reasonably) quickly as possible.

As of this writing, a few benchmark categories are missing because they either
take way too long to complete or they don't make much sense to run in the
environment that they run in (for example: running `fs` benchmarks doesn't give
a realistic view of things because most machines don't run from RAM). I would
like to run *all* benchmarks, but my goal was to make this *at most* a daily
process (meaning 24 hours tops) so as to keep the changes between commits as low
as possible.

I also want to possibly incorporate benchmarks for other, select projects to
help monitor changes in performance there as well, but given that running the
node.js benchmarks already takes as long as it does, I may have to wait until I
can acquire multiple machines with identical hardware to be able to run all of
the benchmarks across all projects in parallel.
