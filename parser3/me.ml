(* lead = <-
   trail = -> *)



let append = fun a x -> let (l,e) = a in  e.(l) <- x; (l+1,e) 

(* Now we start our mathematical definitions *)

type label_t = LabelC of char | LabelS of bool array;;

(*type tree = { l : label; c : tree list; };;*)



type 'a array2 = {mutable a: 'a array; mutable len: int}
type 'a dag_node = {n: 'a ; d:  int array}
type 'a dag =  'a dag_node array2

type array2ii = {a0: label_t dag; mutable a1: int array; mutable a2: int array }

let new_array2 = 
 fun () -> {a=[| |]; len=0} 
let new_array2ii = fun () -> {a0 = new_array2(); a1=[| |]; a2=[| |]} 

let array2_compact aa = {a=Array.sub aa.a 0 aa.len; len=aa.len}



(*
let new_dag_from = fun d -> if d.len = 0
	then new_dag()
	else {a=Array.make (Array.length d.a) d.a.(0); len=0}
*)		

type 'a dagElem = int * 'a dag

let array_double = fun a -> Array.append a a

let append1 = fun l a x ->
	let new_a = if l >= Array.length a 
	then 
		begin
		if l = 0 then [|x|]
		else (array_double a)
		end
	else a in 
	(new_a.(l) <- x ; new_a) 
;;

let append = fun aa x ->
	let l=aa.len in 
	aa.a <- append1 l aa.a x ;
	aa.len <- l+1;
	l

let appendii = fun aaa x ->
	let aa=aaa.a0 in 
	let l=aa.len in
	aaa.a1 <- append1 l aaa.a1 (-1) ;
	aaa.a2 <- append1 l aaa.a2 (-1) ;
	append aa x 

let array2_map f aa =
	let bb = new_array2() in 
	for i = 0 to aa.len-1 do
		ignore (append bb (f aa.a.(i)))
	done ;
	bb
let array2_iter f aa = ignore ( array2_map f aa )

let dag_map f aa = array2_map (fun dag_nd -> {dag_nd with n=(f dag_nd.n)}) aa

let aa_to_array aa = Array.sub aa.a 0 aa.len 

let arrayi_to_string = fun j f a -> String.concat j (Array.to_list (Array.mapi f a)) 
let array_to_string  = fun j f a -> String.concat j (Array.to_list (Array.map  f a)) 
let intarray_to_string = array_to_string ", " string_of_int
let boolarray_to_string = array_to_string "" (fun b -> if b then "T" else ".")
(*
let dag_to_string = fun f d -> Array.mapi (fun i dn -> ((int_to_string i) ^ " " ^ (f dn) ^ " " ^ (intarray_to_string dn.d) ^ "\n" )) (aa_to_array d)*)

(* print_dag f d prints the dag d using function f to convert nodes to strings *)
let print_dag = fun f d -> ignore ( Array.mapi (
	fun i dn -> Printf.printf "%d %s %s\n" 
		i
		(f dn.n)
		(intarray_to_string dn.d)
		) (aa_to_array d))

let formula_printer node child_s =
	match (Array.length child_s) with 
	  0 -> node
	| 1 -> node ^ child_s.(0)
	| 2 -> let p, q = child_s.(0), child_s.(1) in
		( match node with 
		  "U"| "S" -> node ^ "(" ^ p ^ ", " ^ q ^ ")"
		| _ -> "(" ^ p ^ node ^ q ^ ")" ) 
	| _ -> failwith "Too many children"

let letter_to_string names letter =
	let l = ref [] in 
	Array.iteri ( fun i b -> if b then l := names.(i)::!l ) letter;
	"{" ^ (String.concat ", " (List.rev !l)) ^ "}"

let me_printer names l c =
	match l with 
	  LabelC '+' -> "(" ^ c.(0) ^ "+" ^ c.(1) ^ ")"
	| LabelC '>' -> ">" ^ c.(0) 
	| LabelC '<' -> "<" ^ c.(0)
	| LabelC 'S' -> "[" ^ (array_to_string "; " (fun x->x) c) ^ "]" 
	| LabelC chr -> failwith "Unknown ME op " ^ (String.make 1 chr)
	| LabelS a   -> letter_to_string names a

let pretty_print_dag store_array repeats  prefix printer dag =
	let freq = Array.make dag.len 0 in 
	array2_iter ( fun elem ->
		Array.iter ( fun child -> freq.(child) <- freq.(child) + 1 ) elem.d 
	) dag ;
	let id i =  prefix ^ string_of_int i in 
	let fmt r_ i = printer dag.a.(i).n (Array.map r_ dag.a.(i).d) in
	let rec r i = 
		let str = if freq.(i) > repeats 
			then id i
			else fmt r i in 
		if (Array.length store_array) > i then store_array.(i) <- str;
		str  in
	print_string (fmt r (dag.len-1)); 
	ignore (r (dag.len-1)); (* Just to make sure that store_array if full *)
	for i =  dag.len - 2 downto 0 do
		 if freq.(i) > repeats then print_string ("\n\t" ^ (id i) ^ "= " ^ (fmt r i)) 
	done

let pretty_print_formula fd =
	let names = Array.make fd.len "" in
	pretty_print_dag names max_int "T" formula_printer fd;
	names

let pretty_print_me names repeats fd =
	pretty_print_dag [||] repeats "M" (me_printer names) fd
	



type melement = label_t
type formula_op = string
type formula_dag = formula_op dag
type formula = formula_op dagElem
type me_dag = melement dag
(*type model_expression = {m : int ; mdii : array2ii; fd : formula_dag }
*)
(*
let lead_or_trail_ = fun op me -> 
	let m=me.m in 
	let cache = if op = '<' then me.mdii.a1 else me.mdii.a2 in
	(Printf.printf "op: %c cache.(%d)=%d\n" op m cache.(m));
	if cache.(m) < 0 then cache.(m) <- appendii me.mdii {n=LabelC op; d=[|m|]};
  {me with m=cache.(m)}

let (~<) = (lead_or_trail_ '<') (* lead  *)  
let (~>) = (lead_or_trail_ '>') (* trail *)  

let letter_ =  fun mdii fd atoms -> {m=appendii mdii {n=LabelS atoms; d=[||]}; mdii=mdii; fd=fd} 
let shuffle_ = fun mdii fd chld  -> {m=appendii mdii {n=LabelC 'S'  ; d=chld}; mdii=mdii; fd=fd}
*)
let (=>) = fun x y -> (not x) || y
let (<=) = fun x y -> x || (not y)

let dedup mdii m alt = 
	let aa = mdii.a0 in
	let aaa = aa.a in 
	if  m = aa.len - 1 && alt >= 0 && (aaa.(m).n = aaa.(alt).n) && (aaa.(m).d = aaa.(alt).d)
		then (aa.len <- m; alt)
		else m 

type cacheU = { pre_false: int ; pre_true: int; all_p: bool; some_q: bool }  

let bool_to_int = fun b -> if b then 1 else 0

let swap_pair = fun a -> 
	let a0 = a.(0) in
	let a1 = a.(1) in 
        a.(0) <- a1; a.(1) <- a0

let mirror d = for k = 0 to d.len - 1 do 
		let dak = d.a.(k) in
		d.a.(k) <- match dak.n with 
			LabelC label -> (
                                match label with  
                                        '+'   ->  swap_pair dak.d; dak
                                        (*ALT: '+'   ->  {dak with d=[|mI.(1); mI.(0)|]}*)
                                        | '<' ->  {dak with n=LabelC '>'}
                                        | '>' ->  {dak with n=LabelC '<'}
                                        | 'S' ->  dak
					| _ -> failwith "Invalid_ME_Operator"
				
			)
                        | LabelS atoms -> dak
	done


let build_pre = fun d fd f ->
	let pre = (Array.make_matrix (d.len) 2 (-1)) in
	let all_q = Array.make d.len false in
	let some_p = Array.make d.len false in
	let pq = (fd.a.(f).d) in
	let (p,q) = (pq.(0),pq.(1)) in
	for k = 0 to d.len - 1
	do 
		let dak = d.a.(k) in
		match dak.n with 
			LabelC label -> 
				let children = dak.d in 
				all_q.(k)  <- Array.fold_left (fun x i -> x && all_q.(i) ) true  children;
				some_p.(k) <- Array.fold_left (fun x i -> x || some_p.(i)) false children;
				let mI = children in 
				let pre_ = fun b -> match label with 
					'+'   ->  pre.(mI.(0)).(pre.(mI.(1)).(b))
					| '>' ->  pre.(mI.(0)).(b)
					| _   ->  bool_to_int (((b==1) || some_p.(k)) && all_q.(k)) in
				( pre.(k).(0) <- pre_ 0;
				  pre.(k).(1) <- pre_ 1 )
			| LabelS atoms ->
				let pre_ = fun b -> bool_to_int (atoms.(p) || ( (b==1)  && atoms.(q) )) in
				( pre.(k).(0) <- pre_ 0;
				  pre.(k).(1) <- pre_ 1;
				  all_q.(k) <- atoms.(q);
				  some_p.(k) <- atoms.(p) )
	done ;
	pre

let safe_set a i x = let c = (Array.copy a) in Array.set c i x ; c

let max_growth = 3
(* This is the maximum growth in the size of the me node array as a factor
 * size of array that we will add the formula Upq as an atom to.
 * 
 * Take an ME of the form "<K" in the input array.
 *
 * Assume that K has already been added to the output array; 
 * that we add is of the form {<I,<J,<I+J} for some I, J st.
 *      {I,J} = {t(K,T), t(K,F)}
 * Althouth we do not know whether I= t(K,T) or I= t(K,F)
 * We know that we do not add both <I+J and <J+I as there is no
 * ME I such that for all b in {T,F} pre(I,b) = (not b)  
 *
 * Hence an ME of the form "<K" will add at most 3 new nodes.
 * Any other ME K will only add at most two MEs: t(K,T) and t(K,F)
 * We may add one temporary element to the output array, but this
 * isn't a problem since not all nodes can be "<K" nodes.
 *
 * BTW, this gives a |M|*3^|phi| bound on size of the the model.
 * Refining this bound to a |phi||M|*2^|phi| bound is left as an 
 * exercise for the reader.     
 *)



;;
(* Should merge for performance *)
let add_atom_Upq = fun  d_in fd f ->
	let mdii = new_array2ii () in
	let lead_cache =  Array.make (d_in.len*max_growth+1) (-1) in
	let trail_cache = Array.make (d_in.len*max_growth+1) (-1) in
	let d_out = mdii.a0 in
	let lead_or_trail_ = fun cache op m -> ( 
		(*let cache = if op = '<' then me.mdii.a1 else me.mdii.a2 in 
		(Printf.printf "op: %c cache.(%d)=%d\n" op m cache.(m)); flush stdout; *)
		if cache.(m) < 0 then cache.(m) <- appendii mdii {n=LabelC op; d=[|m|]};
	  	cache.(m) )in
	let (~<) = (lead_or_trail_ lead_cache '<') (* lead  *) in 
	let (~>) = (lead_or_trail_ trail_cache '>') (* trail *) in  
	let (+:) = fun e g -> appendii mdii {n=LabelC '+'; d=[|e;g|]} in 

	let letter =  fun atoms -> appendii mdii {n=LabelS atoms; d=[||]} in
	let shuffle = fun chld  -> appendii mdii {n=LabelC 'S'  ; d=chld} in
(*	let d_out = new_dag_from d_in in *)
(*	let shuffle = (shuffle_ d_outii fd) in
	let letter  = (letter_  d_outii fd) in *)
	let pre = build_pre d_in fd f in
	let t_cache = Array.make_matrix d_in.len 2 (-1) in
	let rec t_rec k b =
		let t = fun i b -> (
			if t_cache.(i).(b)<0 then t_cache.(i).(b) <- t_rec i b; 
			t_cache.(i).(b)
		) in(*
		let t = fun i b -> {m=t_ i b; mdii=d_outii; fd=fd} in*) 
		let dak = d_in.a.(k) in
		let new_me = match dak.n with
			LabelC label -> (
                                let mI = dak.d in
				flush stdout;
                                0 + ( match label with  
                                        '+'   ->  ( (t mI.(0) (pre.(mI.(1)).(b))) +: (t mI.(1) b) ) 
                                        | '<' ->  let left = (t mI.(0) pre.(mI.(0)).(b)) in
						  let right = (t mI.(0) b) in 
						  if (left=right)
							then   ( ~< left ) 
							else ( ( ~< left ) +: (right) )
                                        | '>' ->  ( ~> ( t mI.(0) pre.(mI.(0)).(b)) )
                                        | 'S' ->  (shuffle (Array.map (fun i -> t i b) mI))
					| _ -> failwith "Invalid_ME_Operator"
				)
			)
                        | LabelS atoms -> 
				let atoms = if (b==1) then safe_set atoms f true else atoms in
				letter atoms  in
		dedup mdii new_me t_cache.(k).(1-b)
		
	in
	ignore (t_rec (d_in.len-1) 0) ;
	d_out 

let add_atom_Spq = fun  d_in fd f ->
	mirror d_in; 
	let d_out = add_atom_Upq d_in fd f in
	mirror d_out;
	d_out

let add_atom_PC = fun d fd f bool_func ->
	for k = 0 to d.len - 1
	do 
		let dak = d.a.(k) in
		match dak.n with 
			LabelC label -> ()
			| LabelS atoms -> if bool_func (atoms)
				then Array.set atoms f true
				else ()
	done ; d

let satisfied = fun d fd ->
        let sat = ref false in
	for k = 0 to d.len - 1
	do 
		let dak = d.a.(k) in
		match dak.n with 
			LabelC label -> ()
			| LabelS atoms -> if atoms.(fd.len-1)
				then sat := true 
	done ; 
        ! sat

let add_atom = fun d fd f ->
	let pq = (fd.a.(f).d) in
	let f_op = fd.a.(f).n in 
	let pc = (add_atom_PC d fd f) in
	match (Array.length pq) with
		0 -> d
		| 1 -> assert (f_op = "-") ; let p = pq.(0) in 
                        pc (fun atoms -> not atoms.(p))
		| 2 -> let (p,q) = (pq.(0),pq.(1)) in ( match f_op with
			  "&" -> pc (fun a -> a.(p) && a.(q)) 
			| "|" -> pc (fun a -> a.(p) || a.(q))
			| "=" -> pc (fun a -> a.(p) =  a.(q))
			| ">" -> pc (fun a -> a.(p) => a.(q))
			| "<" -> pc (fun a -> a.(p) <= a.(q))
			| "U" -> add_atom_Upq d fd f	
			| "S" -> add_atom_Spq d fd f
			| _   -> failwith "Invalid_Operator" )
		| _ -> failwith "More_than_two_children_in_formula"

	
let label_to_string l = match l with 
	LabelC c -> Char.escaped c
	| LabelS a -> boolarray_to_string a
	
let add_atoms = fun d fd ->
	let d_out = ref d in 
	for f = 0 to fd.len -1
	do
(*		print_string "\nDAG:";
        	print_dag label_to_string (!d_out);  *) 
		d_out := add_atom (!d_out) fd f
	done ; (!d_out)
	
	 
(* Now some boring details for parsing *)
type parse_t = ParseC of char | ParseS of string list;;

let parse_to_label fd p = match p with
	  ParseC c  -> LabelC c
	| ParseS ss -> LabelS (Array.init fd.len ( fun i -> List.mem fd.a.(i).n ss ))

type 'a tree = {l: 'a; c: 'a tree list}
	
let rec dag_from_tree_ h d t = 
	let children = List.map (dag_from_tree_ h d) t.c in
	let new_node = {n=t.l; d=(Array.of_list children)} in
	try Hashtbl.find h new_node
	with Not_found -> let new_id = append d new_node in
		Hashtbl.add h new_node new_id ; new_id

let dag_from_tree t =
	let h = Hashtbl.create 100 in
	let d = {a=[| |]; len=0} in 
	ignore (dag_from_tree_ h d t);
	d

let do_model_check formula_tree me_tree =
begin 
(*	let fd = array2_compact (dag_from_tree formula_tree) in *)
	let fd = dag_from_tree formula_tree in
	let parse_dag = (dag_from_tree me_tree) in
	let md  = dag_map (parse_to_label fd) (parse_dag) in 
	print_string "Input in canonical syntax: \n";
	let names = pretty_print_formula fd in
	print_string " : ";
	pretty_print_me names max_int md ;
	(*print_string "NAMES: \n";
	Array.iter (fun s -> print_string (s ^ "\n")) names;*)
(*	print_string "ME:\n" ;
	print_dag label_to_string d;
	print_string "\nFORMULA: \n" ;  
	print_dag (fun x->x) fd ; *)
	let pre_time = Sys.time() in
	let new_me = add_atoms md fd in
	let post_time = Sys.time() in
      	Printf.printf "\nCpu time used: %6.3f to model check, %6.3f total \n"
		 (post_time-.pre_time) post_time; flush stdout ;

(*	print_string "ME:\n" ;
        print_dag label_to_string new_d *)
(*	print_string "\nResulting DAG:";
        print_dag label_to_string new_me; *)
        let sat_str = if satisfied new_me fd then "IS" else "is NOT" in
	print_string "\n\n------------------------------------";
        Printf.printf "\nThe formula %s satisfied in: " sat_str;
	(*print_string "\nResulting ME:";*)
	pretty_print_me names 1 new_me 
end
	
