# vino-project

Emacs Lisp API clients for MusicBrainz and BookBrainz.

- **musicbrainz.el** — MusicBrainz API client with EIEIO entity dispatch, lazy pagination for releases/recordings/works, Org integration
- **bookbrainz.el** — BookBrainz API client with search/lookup, EIEIO entity dispatch, VUI interface, Org integration
- **tests/** — 57 unit tests for bookbrainz.el

## Running tests

```sh
emacs -Q --batch -l tests/test-runner.el -f ert-run-tests-batch-and-exit
```
