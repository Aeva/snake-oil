#lang racket/base

; Copyright 2021 Aeva Palecek
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.


(require (for-syntax racket/base
                     racket/sequence
                     racket/syntax)
         ffi/unsafe
         ffi/unsafe/define
         racket/format
         racket/port
         racket/undefined
         syntax/parse/define)


(provide py-dir
         py-eval
         py-run
         py-import
         require-py)


; Definer for Python's "limited" stable API.
(define-ffi-definer define-python (ffi-lib "python3.dll"))


; Python Runtime Constants.
(define Py_single_input 256)
(define Py_file_input 257)
(define Py_eval_input 258)


; Python runtime types and structs.
(define _PyTypeObject _uintptr)

(define-cstruct _object ([ob_refcnt _ssize]
                         [ob_type _PyTypeObject]))

(define _PyObject (_cpointer/null _object))


; Python runtime core functions.
(define-python Py_Initialize (_fun -> _void))
(define-python Py_IsInitialized (_fun -> _bool))
(define-python Py_Finalize (_fun -> _void))
(define-python Py_IncRef (_fun _PyObject -> _void))
(define-python Py_DecRef (_fun _PyObject -> _void))
(define-python Py_CompileString (_fun _string _string _int -> _PyObject))
(define-python PyEval_EvalCode (_fun _PyObject _PyObject _PyObject -> _PyObject))
(define-python PyEval_GetBuiltins (_fun -> _PyObject))
(define-python PyObject_Call (_fun _PyObject _PyObject _PyObject -> _PyObject))
(define-python PyObject_CallNoArgs (_fun _PyObject -> _PyObject))
(define-python PyCallable_Check (_fun _PyObject -> _bool))
(define-python PyImport_ImportModule (_fun _string -> _PyObject))
(define-python PyModule_GetDict (_fun _PyObject -> _PyObject))


; Python runtime bool object functions.
(define-python PyBool_FromLong (_fun _bool -> _PyObject))


; Python runtime integer object functions.
(define-python PyLong_AsLong (_fun _PyObject -> _long))
(define-python PyLong_AsLongLong (_fun _PyObject -> _llong))
(define-python PyLong_FromLong (_fun _long -> _PyObject))
(define-python PyLong_FromLongLong (_fun _llong -> _PyObject))


; Python runtime float object functions.
(define-python PyFloat_AsDouble (_fun _PyObject -> _double))
(define-python PyFloat_FromDouble (_fun _double -> _PyObject))


; Python runtime string object functions.
(define-python PyUnicode_GetLength (_fun _PyObject -> _ssize))
(define-python PyUnicode_AsUCS4 (_fun _PyObject _pointer _ssize _bool -> _string/ucs-4))
(define-python PyUnicode_FromString (_fun _string -> _PyObject))


; Python runtime tuple object functions.
(define-python PyTuple_New (_fun _ssize -> _PyObject))
(define-python PyTuple_Size (_fun _PyObject -> _ssize))
(define-python PyTuple_GetItem (_fun _PyObject _ssize -> _PyObject))
(define-python PyTuple_SetItem (_fun _PyObject _ssize _PyObject -> (r : _int) -> (unless (eq? r 0) (error "failed"))))


; Python runtime list object functions.
(define-python PyList_New (_fun _ssize -> _PyObject))
(define-python PyList_Size (_fun _PyObject -> _ssize))
(define-python PyList_GetItem (_fun _PyObject _size -> _PyObject))
(define-python PyList_Append (_fun _PyObject _PyObject -> (r : _int) -> (unless (eq? r 0) (error "failed"))))


; Python runtime dictionary object functions.
(define-python PyDict_New (_fun -> _PyObject))
(define-python PyDict_SetItemString (_fun _PyObject _string  _PyObject -> (r : _int) -> (unless (eq? r 0) (error "failed"))))
(define-python PyDict_GetItemString (_fun _PyObject _string -> _PyObject))
(define-python PyDict_Keys (_fun _PyObject -> _PyObject))
(define-python PyDict_Values (_fun _PyObject -> _PyObject))
(define-python PyDict_Size (_fun _PyObject -> _ssize))


; Python runtime object protocol functions.
(define-python PyObject_Repr (_fun _PyObject -> _PyObject))
(define-python PyObject_Str (_fun _PyObject -> _PyObject))
(define-python PyObject_Length (_fun _PyObject -> _ssize))
(define-python PyObject_GetIter (_fun _PyObject -> _PyObject))
(define-python PyIter_Next (_fun _PyObject -> _PyObject))


; Python runtime exception handling.
(define-python PyErr_Fetch
  (_fun (ptype : (_ptr o _PyObject))
        (pvalue : (_ptr o _PyObject))
        (ptrace : (_ptr o _PyObject))
        -> _void
        -> (values (if ptype ptype #f)
                   (if pvalue pvalue #f)
                   (if ptrace ptrace #f))))


; High level error handling.
(define (check-py-error)
  (define (err-str err-obj default)
    (if err-obj
        (let ([unpacked (unpack-str (PyObject_Str err-obj))])
          (Py_DecRef err-obj)
          unpacked)
        default))
  (let-values ([(err-type err-value err-trace) (PyErr_Fetch)])
    (when err-type
      (error (~a "uncaught python exception:\n"
                 (err-str err-type "") "\n"
                 (err-str err-value "no errror value available") "\n"
                 (err-str err-trace "no traceback available") "\n")))))
    

; Get a python object's opaque type handle.
(define (py-type py-object)
  (unless py-object
    (error "null access violation" py-object))
  (let ([type-handle (object-ob_type (ptr-ref py-object _object))])
    type-handle))


; Initialize the python runtime, and determine the identity of the build-in types.
(define-values
  (py-true
   py-false
   py-bool-type
   py-int-type
   py-float-type
   py-str-type
   py-tuple-type
   py-list-type
   py-dict-type
   py-module-type)
  ((lambda ()
     (when (Py_IsInitialized)
       (Py_Finalize))
     (Py_Initialize)
     (values
      (PyBool_FromLong #t)
      (PyBool_FromLong #f)
      (py-type (PyBool_FromLong #t))
      (py-type (PyLong_FromLong 1))
      (py-type (PyFloat_FromDouble 0.0))
      (py-type (PyUnicode_FromString ""))
      (py-type (PyTuple_New 0))
      (py-type (PyList_New 0))
      (py-type (PyDict_New))
      (py-type (PyImport_ImportModule "__hello__"))))))


; Python type tests.
(define (py-bool? py-object)
  (eq? (py-type py-object) py-bool-type))

(define (py-int? py-object)
  (eq? (py-type py-object) py-int-type))

(define (py-float? py-object)
  (eq? (py-type py-object) py-float-type))

(define (py-str? py-object)
  (eq? (py-type py-object) py-str-type))

(define (py-tuple? py-object)
  (eq? (py-type py-object) py-tuple-type))

(define (py-list? py-object)
  (eq? (py-type py-object) py-list-type))

(define (py-dict? py-object)
  (eq? (py-type py-object) py-dict-type))

(define (py-module? py-object)
  (eq? (py-type py-object) py-module-type))


; Convert a Python bool into a Racket bool.
(define (unpack-bool py-bool)
  (equal? py-bool py-true))


; Convert a Python string to a Racket string.
(define (unpack-str py-str)
  (let* ([len (+ (PyUnicode_GetLength py-str) 1)]
         [buffer (malloc 'atomic (* len 4))])
    (PyUnicode_AsUCS4 py-str buffer len #t)))


; Convert a Python tuple to a Racket vector.
(define (unpack-tuple py-tuple)
  (let ([size (PyTuple_Size py-tuple)])
    (for/vector #:length size ([i size])
      (unpack (PyTuple_GetItem py-tuple i)))))


; Convert a Python list into a Racket list.
(define (unpack-list py-list)
  (let ([size (PyList_Size py-list)])
    (for/list ([i size])
      (unpack (PyList_GetItem py-list i)))))


; Convert a Python dict into a Racket hash.
(define (unpack-dict py-dict)
  (let ([size (PyDict_Size py-dict)]
        [keys (PyDict_Keys py-dict)]
        [vals (PyDict_Values py-dict)])
    (for/hash ([i size])
      (values
       (unpack (PyList_GetItem keys i))
       (unpack (PyList_GetItem vals i))))))


; Convert a Python module into a Racket hash.
(define (unpack-module py-module)
  (unpack (PyModule_GetDict py-module)))


; Wrap a Python callable with a Racket function.
(define (wrap-callable py-object)
  (lambda args
    (let ([ret (PyObject_Call py-object (pack (list->vector args)) #f)])
      (check-py-error)
      (unpack ret))))


; Convert a Python object into a Racket equivalent.
(define (unpack py-object)
  (cond
    [(not py-object) (error "can't unpack nullptr")]
    [(py-bool? py-object) (unpack-bool py-object)]
    [(py-int? py-object) (PyLong_AsLongLong py-object)]
    [(py-float? py-object) (PyFloat_AsDouble py-object)]
    [(py-str? py-object) (unpack-str py-object)]
    [(py-tuple? py-object) (unpack-tuple py-object)]
    [(py-list? py-object) (unpack-list py-object)]
    [(py-dict? py-object) (unpack-dict py-object)]
    [(PyCallable_Check py-object) (wrap-callable py-object)]
    [(py-module? py-object) (unpack-module py-object)]
    [else undefined]))


; Create a Python tuple from a Racket vector.
(define (pack-vector vec)
  (let* ([size (vector-length vec)]
         [tuple (PyTuple_New size)])
    (for ([i size])
      (PyTuple_SetItem tuple i (pack (vector-ref vec i))))
    tuple))


; Create a Python list from a Racket list.
(define (pack-list lst)
  (let ([pylist (PyList_New 0)])
    (for ([item lst])
      (PyList_Append pylist (pack item)))
    pylist))


; Convert a Racket object to a Python equivalent.
(define (pack rkt-object)
  (cond
    [(flonum? rkt-object) (PyFloat_FromDouble rkt-object)]
    [(integer? rkt-object) (PyLong_FromLongLong rkt-object)]
    [(string? rkt-object) (PyUnicode_FromString rkt-object)]
    [(vector? rkt-object) (pack-vector rkt-object)]
    [(list? rkt-object) (pack-list rkt-object)]
    [else (error "Cannot convert to Python equivalent." rkt-object)]))


; Python module struct.
(struct py-context (file-name
                    global-scope
                    local-scope)
  #:transparent
  #:property prop:procedure
  (lambda (self symbol)
    (let ([ret (PyDict_GetItemString (py-context-local-scope self) symbol)])
      (unless ret (error "attribute error") symbol)
      (unpack ret))))


; Return a list of symbols that can be extracted from a py-context.
(define (py-dir module)
  (unpack (PyDict_Keys (py-context-local-scope module))))


; Evaluate a Python expression from a string.
(define (py-eval src [context #f])

  (define (py-eval-inner globals locals)
    (let ([compiled (Py_CompileString src "" Py_eval_input)])
      (check-py-error)
      (let ([ret (PyEval_EvalCode compiled globals locals)])
        (check-py-error)
        (Py_DecRef compiled)
        (unpack ret))))

  (define (py-eval-anonymous)
    (let ([globals (PyDict_New)]
          [locals (PyDict_New)])
      (PyDict_SetItemString globals "__builtins__" (PyEval_GetBuiltins))
      (begin0
        (py-eval-inner globals locals)
        (Py_DecRef globals)
        (Py_DecRef locals))))

  (if context
      (py-eval-inner (py-context-global-scope context)
                     (py-context-local-scope context))
      (py-eval-anonymous)))


; Evaluate a Python source from a string.
(define (py-run src [file-name "anonymous"])
  (let ([compiled (Py_CompileString src file-name Py_file_input)])
    (check-py-error)
    (let ([globals (PyDict_New)]
          [locals (PyDict_New)])
      (PyDict_SetItemString globals "__builtins__" (PyEval_GetBuiltins))
      (let ([ret (PyEval_EvalCode compiled globals locals)])
        (check-py-error)
        (Py_DecRef compiled)
        (py-context file-name globals locals)))))


; Import a Python stuff from a module or a file.
(define (py-import file-path)

  (define (fake-import)
    (let* ([in-file (open-input-file file-path #:mode 'text)]
             [src (port->string in-file)])
        (close-input-port in-file)
        (py-run src file-path)))

  (define (actual-import module)
    (let ([globals (PyDict_New)]
          [locals (PyModule_GetDict module)])
      (PyDict_SetItemString globals "__builtins__" (PyEval_GetBuiltins))
      (py-context file-path globals locals)))

  (if (file-exists? file-path)
      (fake-import)
      (let ([module (PyImport_ImportModule file-path)])
        (if module
            (actual-import module)
            (error "No such module or file:" file-path)))))


; Handy requiresque macro.
(define-syntax-parse-rule (require-py path:str id:id ...)
  #:with (id-string ...)
  (for/list ([id-stx (in-syntax #'(id ...))])
    (symbol->string (syntax-e id-stx)))
  (begin
    (define py-context (py-import path))
    (define id (py-context 'id-string)) ...))