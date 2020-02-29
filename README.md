# What is this?

This repository consists of two parts:

  * Benchmark results (for most categories) for the node.js master branch that
    are collected daily
  * A web UI to consume the data

# Background

I wanted to set up an automated process that would continuously run node.js'
benchmarks so as to help catch (unintended) performance regressions as
(reasonably) quickly as possible.

I had an old Core i7 machine laying around that I thought would work well for
the job, so I maxed out the RAM in it and built a minimal, customized version of
Debian that it could boot from over the network and run completely from RAM in
isolation.

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
