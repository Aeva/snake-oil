This is a library for embedding Python 3 in racket.

Dependencies
------------

You need Python 3 installed on your system with the system PATH environment variable set up correctly.

Usage
-----

See test.rkt for a usage example.

What can this do?
-----------------

It can export numbers, strings, dictionaries, tuples, lists, and callables from Python.
Exported functions can be called from Racket with integers, flonums, strings, lists, vectors, or hashes as arguments.

Is this "production ready"?
---------------------------

Absolutely not.  This is not managing reference counts for most things, tracebacks leave something to be desired, and there's probably a bunch of other problems.
