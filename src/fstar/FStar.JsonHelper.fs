(* Helpers mainly for FStar.Interactive.Lsp; some sharing with
 * FStar.Interactive.Ide *)
#light "off"

module FStar.JsonHelper
open FStar
open FStar.Util
open FStar.Errors
open FStar.Exn

let json_debug = function
  | JsonNull -> "null"
  | JsonBool b -> Util.format1 "bool (%s)" (if b then "true" else "false")
  | JsonInt i -> Util.format1 "int (%s)" (Util.string_of_int i)
  | JsonStr s -> Util.format1 "string (%s)" s
  | JsonList _ -> "list (...)"
  | JsonAssoc _ -> "dictionary (...)"

let try_assoc (key: string) (d: 'a) =
  Util.map_option snd (Util.try_find (fun (k, _) -> k = key) d)

exception InvalidQuery of string
type query_status = | QueryOK | QueryNOK | QueryViolatesProtocol

// The definition in IDE is nested; this differs in not providing loc
let assoc key a =
  match try_assoc key a with
  | Some v -> v
  | None -> raise (InvalidQuery (Util.format1 "Missing key [%s]" key))

// All exceptions are guaranteed to be caught in the LSP server implementation
exception UnexpectedJsonType of string * json

let js_fail expected got =
  raise (UnexpectedJsonType (expected, got))

let js_int : json -> int = function
  | JsonInt i -> i
  | other -> js_fail "int" other
let js_str : json -> string = function
  | JsonStr s -> s
  | other -> js_fail "string" other
let js_list k = function
  | JsonList l -> List.map k l
  | other -> js_fail "list" other
let js_assoc : json -> list<(string * json)> = function
  | JsonAssoc a -> a
  | other -> js_fail "dictionary" other

type completion_context = { trigger_kind: int; trigger_char: option<string> }

let js_compl_context : json -> completion_context = function
  | JsonAssoc a ->
    { trigger_kind = assoc "triggerKind" a |> js_int;
      trigger_char = try_assoc "triggerChar" a |> Util.map_option js_str; }
  | other -> js_fail "dictionary" other

type txdoc_item = { uri: string; langId: string; version: int; text: string }

let js_txdoc_item : json -> txdoc_item = function
  | JsonAssoc a ->
    let arg k = assoc k a in
    { uri = arg "uri" |> js_str;
      langId = arg "languageId" |> js_str;
      version = arg "version" |> js_int;
      text = arg "text" |> js_str }
  | other -> js_fail "dictionary" other

type workspace_folder = { uri: string; name: string }
type wsch_event = { added: workspace_folder; removed: workspace_folder }

let js_wsch_event : json -> wsch_event = function
  | JsonAssoc a ->
      let added' = assoc "added" a |> js_assoc in
      let removed' = assoc "removed" a |> js_assoc in
      { added = { uri = assoc "uri" added' |> js_str;
                  name = assoc "name" added' |> js_str };
        removed = { uri = assoc "uri" removed' |> js_str;
                    name = assoc "name" removed' |> js_str } }
  | other -> js_fail "dictionary" other

type lquery =
| Initialize of int * string
| Initialized
| Shutdown
| Exit
| Cancel of string
| FolderChange of wsch_event
| ChangeConfig
| ChangeWatch
| Symbol of string
| ExecCommand of string
| DidOpen of txdoc_item
| DidChange
| WillSave of string
| DidSave of string
| DidClose of string
| Completion of completion_context
| Resolve
| Hover
| SignatureHelp
| Declaration
| Definition
| Implementation
| References
| DocumentHighlight
| DocumentSymbol
| CodeAction
| CodeLens
| DocumentLink
| DocumentColor
| ColorPresentation
| Formatting
| RangeFormatting
| TypeFormatting
| Rename
| PrepareRename
| FoldingRange
| BadProtocolMsg of string

type lsp_query = { query_id: string; q: lquery }

// The IDE uses a slightly different variant (wrap_js_failure)
// because types differ (query' versus lsp_query)
let wrap_jsfail qid expected got : lsp_query =
  { query_id = qid;
    q = BadProtocolMsg (Util.format2 "JSON decoding failed: expected %s, got %s"
                        expected (json_debug got)) }