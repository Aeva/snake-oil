#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define)
(require racket/format)

(define-ffi-definer define-python (ffi-lib "python39.dll"))

(define _PyObject (_cpointer/null _void))

(define Py_eval_input 258)

(define-python Py_Initialize (_fun -> _void))
(define-python Py_Finalize (_fun -> _void))
(define-python PyRun_String (_fun _string _int _PyObject _PyObject -> _PyObject))
(define-python PyErr_Occurred (_fun -> _PyObject))
(define-python PyErr_Clear (_fun -> _void))

(define-python PyDict_New (_fun -> _PyObject))

(define (slow-check fn py-object)
  (when (PyErr_Occurred)
    (error "???"))
  (fn py-object)
  (let ([ret (PyErr_Occurred)])
    (PyErr_Clear)
    (eq? ret #f)))

(define-python PyLong_AsLong (_fun _PyObject -> _long))
(define-python PyLong_AsLongLong (_fun _PyObject -> _llong))
(define (PyLong? py-object)
  (slow-check PyLong_AsLong py-object))

;(define-python PyFloat_Check (_fun _PyObject -> _bool))
(define-python PyFloat_AsDouble (_fun _PyObject -> _double))
(define (PyFloat? py-object)
  (slow-check PyFloat_AsDouble py-object))

;(define-python PyUnicode_Check (_fun _PyObject -> _bool))
(define-python PyUnicode_AsUTF8 (_fun _PyObject -> _string/utf-8))
(define (PyUnicode? py-object)
  (slow-check PyUnicode_AsUTF8 py-object))

(define-python PyObject_GetIter (_fun _PyObject -> _PyObject))
(define-python PyIter_Next (_fun _PyObject -> _PyObject))

(define (iterator? py-object)
  (slow-check PyObject_GetIter py-object))

(define (iterator-as-list py-object)
  (define (iterate py-object)
    (let ([next (PyIter_Next py-object)])
      (if next
          (cons (unpack next) (iterate py-object))
          null)))
  (let ([iter (PyObject_GetIter py-object)])
    (iterate iter)))

(define (unpack py-object)
  (cond
    [(PyLong? py-object) (PyLong_AsLong py-object)]
    [(PyFloat? py-object) (PyFloat_AsDouble py-object)]
    [(PyUnicode? py-object) (PyUnicode_AsUTF8 py-object)]
    [(iterator? py-object) (iterator-as-list py-object)]))


(define-python PyTuple_GetItem (_fun _PyObject _size -> _PyObject))
(define-python PyObject_Length (_fun _PyObject -> _size))


(Py_Initialize)

(define scope (PyDict_New))
(let ([out (PyRun_String "(123, 456, 'hello world')" Py_eval_input scope scope)])
  (unpack out))

(Py_Finalize)
