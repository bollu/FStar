module FStar.TypeChecker.Core
open FStar.Compiler.Util
open FStar.Syntax.Syntax
module Env = FStar.TypeChecker.Env
module S = FStar.Syntax.Syntax
module R = FStar.Compiler.Range
module U = FStar.Syntax.Util


val clear_memo_table (_:unit)
  : unit

val check (g:Env.env) (e:term)
  : either (typ & option typ) string

