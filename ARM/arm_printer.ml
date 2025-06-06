open Arm

let pp_hex fmt i =
  Format.fprintf fmt "%08lX" i

let cond_to_str c =
  match c with
  | EQ -> "EQ" | NE -> "NE" | CS -> "CS" | HS -> "HS"
  | CC -> "CC" | LO -> "LO" | MI -> "MI" | PL -> "PL" 
  | VS -> "VS" | VC -> "VC" | HI -> "HI" | LS -> "LS"
  | GE -> "GE" | LT -> "LT" | GT -> "GT" | LE -> "LE"
  | AL -> ""

let ldr_str_type_to_str t =
  match t with
  | B -> "B" | SB -> "SB" | H -> "H" | SH -> "SH" | W -> ""
  | T -> "T" | BT -> "BT"

let sign_to_str sign =
  if sign = sign_minus then "-" else ""

let s_to_str s =
  if s then "S" else ""

let l_to_str l =
  if l then "L" else ""

let print_register fmt r =
  Format.fprintf fmt "r%d" r

let print_immediate fmt i =
  Format.fprintf fmt "#%#lx" i

let print_imm_reg fmt i =
  match i with
  | Imm i -> print_immediate fmt i
  | Reg r -> print_register fmt r

let st_to_string st =
  match st with
  | LSL _ -> "LSL" | LSR _ -> "LSR" | ASR _ -> "ASR" | ROR _ -> "ROR"
  | RRX -> "RRX"

let print_st f fmt st =
  let str = st_to_string st in
  match st with
  | LSL i | LSR i | ASR i | ROR i ->
    Format.fprintf fmt "%s %a" str f i
  | RRX -> Format.fprintf fmt "%s" str  

let print_operand fmt op =
  match op with
  | Immediate i -> print_immediate fmt i
  | Register r -> Format.fprintf fmt "%a" print_register r
  | ScaledRegister (r, st) ->
    Format.fprintf fmt "%a, %a" print_register r (print_st print_imm_reg) st

let print_immediate_offset fmt (s, i) =
  Format.fprintf fmt "#%s%#lx" (sign_to_str s) i

let print_register_offset fmt (ro, addr_typ) =
  let str = if addr_typ = PreIndexed then "!" else "" in
  match ro, addr_typ with
  | OImmediate (r,s,i), PostIndexed -> Format.fprintf fmt "[%a], %a"
    print_register r print_immediate_offset (s, i)
  | ORegister (r,s,ro), PostIndexed -> Format.fprintf fmt "[%a], %s%a"
    print_register r (sign_to_str s) print_register ro
  | OScaledRegister (r,s,ro,st), PostIndexed -> Format.fprintf fmt "[%a], %s%a, %a"
    print_register r (sign_to_str s) print_register ro (print_st print_immediate) st
  | OImmediate (r,s,i), _ -> Format.fprintf fmt "[%a, %a]%s"
    print_register r print_immediate_offset (s, i) str
  | ORegister (r,s,ro), _ -> Format.fprintf fmt "[%a, %s%a]%s"
    print_register r (sign_to_str s) print_register ro str
  | OScaledRegister (r,s,ro,st), _ -> Format.fprintf fmt "[%a, %s%a, %a]%s"
    print_register r (sign_to_str s) print_register ro (print_st print_immediate) st str

let mem_instr_to_str instr =
  match instr with
  | STR -> "STR" | LDR -> "LDR"

let mov_instr_to_str instr =
  match instr with
  | MOV -> "MOV" | MVN -> "MVN"

let data_proc_instr_to_str instr =
  match instr with
  | ADC -> "ADC" | SBC -> "SBC" | AND -> "AND" | BIC -> "BIC"
  | ADD -> "ADD" | SUB -> "SUB" | ORR -> "ORR" | EOR -> "EOR"

let pp_arm fmt arm =
  match arm with
  | Custom i -> Format.fprintf fmt "0x%08lX" i
  | Mem {instr;typ;cond;rd;ro} -> Format.fprintf fmt "%s%s%s %a, %a"
    (mem_instr_to_str instr) (cond_to_str cond) (ldr_str_type_to_str typ)
    print_register rd print_register_offset ro
  | Mov {instr;s;cond;rd;rs}   -> Format.fprintf fmt "%s%s%s %a, %a"
    (mov_instr_to_str instr) (cond_to_str cond) (s_to_str s)
    print_register rd print_operand rs
  | DataProc {instr;s;cond;rd;rn;op2} -> Format.fprintf fmt "%s%s%s %a, %a, %a"
    (data_proc_instr_to_str instr) (cond_to_str cond) (s_to_str s)
    print_register rd print_register rn print_operand op2
  | Branch {l;cond;target} -> Format.fprintf fmt "B%s%s %a"
    (l_to_str l) (cond_to_str cond) print_immediate target
  | BranchX {l;cond;rm} -> Format.fprintf fmt "B%sX%s %a"
  (l_to_str l) (cond_to_str cond) print_register rm
