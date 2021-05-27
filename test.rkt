#lang racket/base

(require racket/format
         "python.rkt")

(define test.py (py-import "test.py"))

(define fnord (test.py "fnord"))

(fnord 2 4 6)

(py-eval "(min(123, 456), [456, 789], 'Hail Eris!', {'a':1, 'b':2})")

(py-eval "fnord(6, 7, 8)" test.py)
