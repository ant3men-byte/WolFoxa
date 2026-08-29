
# WolFox

iOS environment simulation & testing platform (Theos / Objective-C).
Authorized testing only.

## Structure (compact)
- Tweak.x — entry point
- WolFox.h / Core.mm — all Objective-C modules
- Portable.h / Portable.cpp — shared math & rules (also compiled by Linux tests)
- Tests/AllTests.cpp — single test file

## Build
- Linux tests: `c++ -std=c++17 Tests/AllTests.cpp Portable.cpp -o tests && ./tests`
- Package: `make package FINALPACKAGE=1`
- CI on push to main: tests → config validation → rootful + rootless packages + dylib + SHA256SUMS

Phases 1–3 done. Phases 4–9 pending (AppManager returns NotAvailable honestly).
