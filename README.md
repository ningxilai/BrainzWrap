# vino-project

Record listening and reading history locally.

- **musicbrainz.el** — MusicBrainz API client with EIEIO entity dispatch, lazy pagination, Org integration
- **bookbrainz.el** — BookBrainz API client with search, lookup, EIEIO entity dispatch, VUI interface, Org integration

Inspired by [d12frosted/vino](https://github.com/d12frosted/vino).

## Running tests

```sh
emacs -Q --batch -l tests/test-runner.el -f ert-run-tests-batch-and-exit
```
