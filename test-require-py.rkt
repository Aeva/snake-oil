#lang racket/base

(require "python.rkt")

(require-py "test.py" fnord)

(fnord 1 2 3)
