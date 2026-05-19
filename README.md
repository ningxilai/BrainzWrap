# vino-project

Emacs Lisp API clients for MusicBrainz and BookBrainz, sharing the same tech stack (EIEIO entity dispatch, async API requests, Org integration).

## Modules

| Module | API | Highlights |
|--------|-----|------------|
| `musicbrainz.el` | MusicBrainz | Lazy pagination for releases/recordings/works, `mz-let*` / `mz-when-let*` macros |
| `bookbrainz.el` | BookBrainz | VUI interactive views, `cl-defmethod` dispatch (`bb-detail`, `bb-format-result`), search/lookup |

## Tests

57 unit tests for bookbrainz.el:

```sh
emacs -Q --batch -l tests/test-runner.el -f ert-run-tests-batch-and-exit
```
