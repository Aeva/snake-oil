#lang racket/base

(require "python.rkt")

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
