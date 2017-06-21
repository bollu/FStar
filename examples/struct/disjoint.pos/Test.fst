module Test

module S  = FStar.Pointer
module HST = FStar.ST

let struct : S.struct_typ = [
  ("I", S.TBase S.TInt);
  ("B", S.TBase S.TBool);
]

let struct_t = S.TStruct struct

let obj = S.pointer struct_t

let callee
   (pfrom pto: obj)
: HST.Stack int
  (requires (fun h -> S.live h pfrom /\ S.live h pto /\ S.disjoint pfrom pto))
  (ensures (fun h z h' ->
    S.live h pfrom /\ S.live h pto /\
    S.live h' pfrom /\ S.live h' pto /\
    S.modifies_1 (S.gfield pto "I") h h' /\
    S.gread h (S.gfield pfrom "I") == z /\
    S.gread h' (S.gfield pto "I") == z + 1))
= S.write (S.field pto "I") (S.read (S.field pfrom "I") + 1);
  S.read (S.field pfrom "I")

let more_struct : S.struct_typ = [
  ("Less", struct_t);
  ("ThisMore", S.TBase S.TUnit);
]

let more_struct_t = S.TStruct more_struct

let more_obj = S.pointer more_struct_t

let caller
  ()
: HST.Stack int
  (requires (fun _ -> True))
  (ensures (fun _ z _ -> z == 18))
= HST.push_frame();
  let ofrom : obj = S.screate _ (S.struct_create struct (function | "I" -> 18 | "B" -> true)) in
  let moto : more_obj = S.screate _ (S.struct_create more_struct (function | "Less" -> S.struct_create struct (function  | "I" -> 1729 | "B" -> false ) | "ThisMore" -> ())) in
  let pfrom : obj = ofrom in
  let pto : obj = S.field moto "Less" in
  let z = callee pfrom pto in
  HST.pop_frame ();
  z
