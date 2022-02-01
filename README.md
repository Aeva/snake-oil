What
----

This is a library for embedding Python 3 in racket.

Dependencies
------------

You need Python 3.10 or newer installed on your system with the system PATH environment variable set up correctly.

Linux users will probably have to install `libpython3` or an equivalent package.

Installation
------------

Download this somewhere, `cd` to the project root, and then run `raco pkg install`.

Usage
-----

```rkt
#lang racket/base

(require snake-oil)

; Import functions, etc from python source files!
(require-py "test.py" fnord)
(fnord 1 2 3)

; Or from modules!
(require-py "math" radians)
(radians 90)

; Or just vibe!
(py-eval "(min(123, 456), [456, 789], 'Hail Eris!', {'a':1, 'b':2})")

; Or if you need to get really fancy,
(define math (py-import "math"))
(py-eval "sqrt(2)" math)
```

What can this do?
-----------------

It can export numbers, strings, dictionaries, tuples, lists, and callables from Python.
Exported functions can be called from Racket with integers, flonums, strings, lists, vectors, or hashes as arguments.

Is this "production ready"?
---------------------------

No.  This is a work in progress with no known users.
