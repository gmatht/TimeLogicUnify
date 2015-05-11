(* ex: set tabstop=4 *)
module Int = struct
  type t = int
  let compare = compare
end

module IntSet = struct
	include Set.Make(Int)
	let rec of_list l = match l with [] -> empty | h::t -> add h (of_list t) 
	let disjoint x y = equal (inter x y) empty
end

module ISS = struct
	include Set.Make(IntSet)
	let rec of_list l = match l with [] -> empty | h::t -> add h (of_list t)
	let of_list2 ll = of_list (List.map IntSet.of_list ll)	
end

let bool2str b = if b then "Y" else "n"
let printf = Printf.printf

(*let memoize f =
    let table = Hashtbl.Poly.create () in
    (fun x ->
      match Hashtbl.find table x with
      | Some y -> y
      | None ->
        let y = f x in
        Hashtbl.add_exn table ~key:x ~data:y;
        y
    );;*)

(*let cartesian l l' = 
  List.concat (List.map (fun e -> List.map (fun e' -> (e,e')) l') l)*)

let agents_disjoint al = 
	let rec r prev l =
		match l with
		| [] -> true
		| head::tail -> 
			if IntSet.disjoint prev head
			then r (IntSet.union prev head) tail 
			else false in
	r IntSet.empty (ISS.elements al);;

let println_list_of_int li = printf "[%s]\n" (String.concat "; " (List.map string_of_int li))

let subsets xs = List.fold_right (fun x rest -> rest @ List.map (fun ys -> x::ys) rest) xs [[]]

let iter_small_subsets f n xs =
	let rec r pl n xs =
		if (n < 1)
		then f pl
		else match xs with 
				| [] -> f pl
				| head::tail -> 
					r (head::pl) (n-1) tail;
					r pl          n    tail in
	r [] n xs;;


let rec range i j = if i > j then [] else i :: (range (i+1) j)

let ( ==> ) a b = ((not a) || b)

type coalition = IntSet.t

let coalition_to_string c = "{" ^ (String.concat "" (List.map string_of_int (IntSet.elements c))) ^ "}"

let rec fixpoint f x = let fx = f x in
	if (x = fx) 
	then x
	else fixpoint f fx;;
	
assert ( (fixpoint (fun x -> x/2) 9) = 0);;

(* We extend the (B)ATL* formulas with "STRONG" and "WEAK" vetos *)

type formula =
    | ATOM of char
    | NOT of formula
    | AND of formula * formula   
    | NEXT of formula
	| UNTIL of formula * formula
    | CAN of coalition * formula (* a Strategy: Can A psi = <<A>>psi *)
    | STRONG of coalition (* Strong Veto *)
    | WEAK of coalition (* Weak Veto *)


module Formula = struct
	type t = formula 
	let rec to_string psi = let s = to_string in
		match psi with
	    | ATOM c      -> (String.make 1 c)
		| NOT x       -> "~" ^ (s x)
		| NEXT x      -> "X" ^ (s x)
		| AND (x,y)   -> "(" ^ (s x) ^ "&" ^ (s y) ^ ")"
		| UNTIL (x,y) -> "(" ^ (s x) ^ "U" ^ (s y) ^ ")"		
		| CAN (a,y)   -> (coalition_to_string a) ^ (s y)
		| STRONG a -> "V" ^ (coalition_to_string a)
		| WEAK  a -> "v" ^ (coalition_to_string a);;

	let of_string s =
		let i = ref 0 in
		let s = "("^s^")" in
		let rec c() = (
			let got=s.[(!i)] in
			i:=(!i)+1;
			print_char got;
			flush stdout;
			if got = ' ' then c() else got
		) in
		let rec ag() =
			match c() with 
			| '}' -> IntSet.empty
			| x -> if (x > '0' && x <= '9') 
				then IntSet.add ( (int_of_char (x) - int_of_char('0')) ) (ag()) 
				else (printf "Invalid Agent#  %c at position %d\n" x (!i); assert (false)) in
		let rec r()=
			let rec bimodal x = 
				let op = c() in
				if op = ')' then x
				else bimodal (
					match op with 
					| '&' -> AND   (x,r())
					| 'U' -> UNTIL (x,r())
					| '|' -> NOT   (AND (NOT x, NOT (r())))
					| x -> (printf "Unexpected op  %c at position %d" x (!i); assert (false))
				) 
			in
			match (c()) with
			| '~' | '-' -> NOT (r())  
			| 'X' | 'N' -> NEXT (r())  
			| '(' ->  bimodal (r()) 
			| '{' -> 
				let agents = ag() in
				let psi = r() in
				CAN (agents, psi)
			| x -> ATOM x in
		r();;
		
		
			
				
	let  max_agent psi = let rec s psi = 
		match psi with
	    | ATOM c      ->  0
		| NOT x | NEXT x -> (s x)
		| AND (x,y) | UNTIL(x,y)  -> max (s x) (s y)
		| CAN (a,y)   -> max (IntSet.max_elt (IntSet.add 0 a)) (s y)
		| STRONG a | WEAK a -> (IntSet.max_elt a) in
		s psi
			
					
				
	let print x = (print_string (to_string x))
	let println x = print_string ((to_string x) ^ "\n") 
	let compare = compare
end  

let neg psi = 
	match psi with
	| NOT alpha -> alpha
	| alpha -> NOT alpha
	

(* We now fix a formula that we wish to decide *)
(*
let phi = AND (CAN (IntSet.singleton(1), NOT (NEXT (ATOM 'p'))), CAN (IntSet.empty, ATOM 'p')) 
let phi = NEXT (AND (ATOM 'p', NOT (ATOM 'p'))) 
*)


let phi =
	if Array.length Sys.argv > 1
	then Formula.of_string Sys.argv.(1)
	else Formula.of_string "({1}p&{1}~p)"
	(*else UNTIL (ATOM 'p', (AND (ATOM 'p', NOT (ATOM 'p')))) *)

let num_agents = Formula.max_agent(phi)  
let colour_limit = 1000000
let verbose = false 
(*let max_hues_in_colour=3*)

let all_agents_list = range 1 num_agents
let all_agents = IntSet.of_list(all_agents_list)
let all_coalitions_list = subsets all_agents_list
let all_coalitions = ISS.of_list2 all_coalitions_list

(* We define a Hue as a set of formulas, however a "Hue" is only a
   hue as defined the the B-ATL* paper iff the Hue.valid function
   returns true *) 
module Hue = struct
	include Set.Make(Formula)
	let bigunion = List.fold_left union empty
	let union3 a b c= union a (union b c)
	
	let rec of_list l = match l with [] -> empty | h::t -> add h (of_list t) 
	
	let rec closure_of p =
		let r = closure_of in
		let p_notp = of_list [p; NOT p] in
		match p with
	    | ATOM c      -> p_notp 
		| NOT x       -> add p (r x)
		| NEXT x      -> union p_notp (r x)
		| AND (x,y) | UNTIL (x,y) -> union3 p_notp (r x) (r y)
		| CAN (a,y)   -> union3 p_notp (of_list [STRONG a; WEAK a]) (r y)  
		| STRONG a | WEAK a -> singleton p

		(* FIXME: should there ever be "WEAK empty" in the closure *)
		
	let closure = closure_of phi
	
	let mpc h = for_all (fun b -> let has x = mem x h in 
					match b with
					| NOT a ->   ( (has b) != (has a) )
					| AND (x,y) -> ( (has b)  = ((has x) && (has y)) )
					| _ -> true
				) closure;;

	let rec add_vetos prev_vetos h =
		let rec r (w,s) h =
			match h with
			| (WEAK   ag)::tail -> r ((ISS.add ag w), s) tail
			| (STRONG ag)::tail -> r (w, (ISS.add ag s)) tail
			| [] -> (w,s)
			| _::tail -> r (w,s) tail in
		r prev_vetos (elements h)
	let get_vetos = add_vetos (ISS.empty, ISS.empty)
	let vetos_valid (w,s) = ((ISS.cardinal w) <= 1) && (agents_disjoint (ISS.union w s)) && ((ISS.inter w s) = ISS.empty);;

	let _ =
		let (w,s) = get_vetos (of_list[STRONG (IntSet.singleton 1)] ) in
		printf "STRONG: %s\n" (String.concat "" (List.map coalition_to_string (ISS.elements s)));;

	assert (get_vetos empty = (ISS.empty, ISS.empty));;
	assert (get_vetos (of_list[STRONG (IntSet.singleton 1)] ) = (ISS.empty, ISS.of_list2 [[1]]));;
	assert (get_vetos (of_list[ WEAK (IntSet.singleton 1); STRONG (IntSet.singleton 1)] ) = (ISS.of_list2 [[1]], ISS.of_list2 [[1]]));;
	assert (get_vetos (of_list[ WEAK (IntSet.singleton 1); STRONG (IntSet.singleton 2)] ) = (ISS.of_list2 [[1]], ISS.of_list2 [[2]]));;

	let without_vetos = filter (fun psi ->
		match psi with
		| WEAK _ | STRONG _ -> false
		| _ -> true
	);;

	assert (vetos_valid (ISS.empty,ISS.empty));;
	assert (not (vetos_valid (ISS.of_list2 [[1];[2]] ,ISS.empty)));;
	assert ((vetos_valid (ISS.empty,ISS.of_list2 [[1];[2]])));;
	assert (not (vetos_valid (ISS.empty,ISS.of_list2 [[1;2];[2]])));;
	assert (not (vetos_valid (ISS.of_list2 [[1]],ISS.of_list2 [[1]])));;

	(* NOTE: the paper currently only has the `vetos_valid` test on colours. either is correct, but this ways if faster. Maybe change paper?*)
	let valid h = (mpc h) && (vetos_valid (get_vetos h)) &&  
				  for_all (fun p ->
				    let has x = mem x h in
					match p with 
					| UNTIL(a,b) -> (has a) || (has b)
					| NOT (UNTIL (a,b)) -> (not(has b))
					| CAN(x,a) ->      ( (x=IntSet.empty) ==> (has a) )
					| NOT CAN(x,a) ->  ( (x=all_agents) ==> (not (has a)))
					| _ -> true
					) h;;

	
    let all_hues = List.filter valid (List.map of_list (subsets (elements closure)));;

    let rx h g = for_all (fun x -> match x with
		| NEXT a       ->      mem a g
		| NOT (NEXT a) -> not (mem a g)
		| UNTIL(a,b)   ->     (mem b h) || (mem x g)
		| WEAK(s) | STRONG (s) -> (mem x g)
		| _ -> true
	) h

	let can_formula p = 
		match p with
		| CAN _ -> true
		| _     -> false
		
	let can_formulas h = filter can_formula h;;

	assert (not (can_formula (STRONG (IntSet.singleton 1))));
	assert ((can_formulas (singleton(ATOM 'p')))=empty);
	assert  (can_formulas (singleton(STRONG (IntSet.singleton 1)))=empty);
	assert ((can_formulas (singleton(CAN (IntSet.empty, ATOM 'p'))))!=empty);
	;;

(* 
	let ra h g = 
		let r h g = for_all (fun x -> 
			match x with
			| UNTIL(a,b)   ->     (mem x g)
			| _ -> true) h in
		(r h g) &&  (r g h);;
*)
	let vetoed = 
		exists (fun psi->
			match psi with
			| STRONG _ | WEAK _ -> true;
			| _ -> false;
		) 
	let not_vetoed h = not (vetoed h)			

(* The Hues are now implemented, we now do some Input/Output defintions *)
					
    let to_string x = "{" ^ (String.concat ", " (List.map Formula.to_string (elements x))) ^ "}";;
    let println x = print_string ((to_string x) ^ "\n") ;; 

	let _ = iter Formula.println closure;; 
    
 (*   let _ = print_string (String.concat "\n" (List.map to_string all_hues));; *)
    
    printf "\nNumber of Hues: %d \n" (List.length all_hues);;

(* Since we will have to implement pruning of Colours later, let us
   practice pruning hues that are not even LTL-consistent *)
 		
	let has_successor hues h = List.exists (rx h) hues;;
	let filter_hues hues = List.filter (has_successor hues) hues
	let all_hues = fixpoint filter_hues all_hues;; 
	
    printf "\nNumber of Hues with successors: %d \n" (List.length all_hues);;
	
	let directly_fulfilled b hues = List.filter (fun h->mem b h) hues;;
	
    (* let _ = List.iter println  all_hues;; *)

    let _ = List.iter println (directly_fulfilled (ATOM 'a') all_hues);;
 	
	(* returns a list of hues in "hues" that are fulfilled by arleady fulfilled hues in "fh" *)  
	let fulfilled_step hues b fh = List.filter 
		(fun h-> List.exists (fun g-> (equal g h) || (rx h g)) fh)
		hues ;;
    let fulfilled hues b = fixpoint (fulfilled_step hues b) (directly_fulfilled b hues)
    
    let all_fulfilled start_hues =
		let hues = ref (filter_hues start_hues) in
		iter (fun f -> match f with
             | UNTIL(a,b) -> let ful_b = fulfilled (!hues) b in
							let new_hues = List.filter (fun h->
								mem (UNTIL(a,b)) h ==> List.mem h ful_b
 							) (!hues) in
 							hues := new_hues
 			| _ -> ())
 			closure;
 		(!hues)
 	
 	let all_hues = fixpoint all_fulfilled all_hues;;						  
		
    printf "Number of LTL-Consistent Hues: %d \n\n" (List.length all_hues);;
    
	let _ = List.iter println all_hues;;
end


let max_hues_in_colour = 
	if Array.length Sys.argv > 2
	then int_of_string Sys.argv.(2)
	else int_of_float (log (float_of_int colour_limit) /. log (float_of_int (List.length Hue.all_hues)));;
(*let max_hues_in_colour = 2;;*)
printf "Limiting ourselves to %d hues per colour\n" max_hues_in_colour;;

flush stdout;

module Colour = struct
	include Set.Make(Hue)
	let rec of_list l = match l with [] -> empty | h::t -> add h (of_list t) 
	
	(* exists a formula satisfying fn
	exists_f fn c = 
		exists (fun h->
			exists fn h
		) c
	*)
	
	let mem_f f c = 
        exists (fun h->
			Hue.mem f h
		) c;;	
		
	assert (mem_f (ATOM 'p') (singleton(Hue.singleton(ATOM 'p'))));;

	let can_formulas c = 
		let arbitrary_hue = min_elt c in
		Hue.can_formulas arbitrary_hue 

            let to_string x = "{" ^ (String.concat ", " (List.map Hue.to_string (elements x))) ^ "}";;

	let valid c =
		let can_f = can_formulas c in
		let sat_c1 = for_all (fun h-> 
(*			let cf_h=Hue.can_formulas h in
			let yn = (cf_h=can_f) in
			printf "i%d  U%d %s \n" (Hue.cardinal  (Hue.inter cf_h can_f)) (Hue.cardinal  (Hue.union cf_h can_f)) (bool2str yn);
			printf "i%s  U%s %s \n" (Hue.to_string (Hue.inter cf_h can_f)) (Hue.to_string (Hue.union cf_h can_f)) (bool2str yn);
			printf "%s ?? %s %s \n" (Hue.to_string cf_h) (Hue.to_string can_f) (bool2str yn); *)
			Hue.equal (Hue.can_formulas h) can_f 
		) c in
		let sat_c2 =
			Hue.for_all (fun f->
				match f with
				| CAN(_,alpha) -> mem_f alpha c
				| _	-> assert(false)
			) can_f in
		let sat_c3 = exists Hue.not_vetoed c in
		let sat_c4 = Hue.vetos_valid (
			let rec r vetos hues = 
				match hues with
				| [] -> vetos
				| head::tail -> r (Hue.add_vetos vetos head) tail in
			r (ISS.empty, ISS.empty) (elements c)
		) in 
		let _ = if verbose then print_endline ((String.concat "" (List.map bool2str [sat_c1;sat_c2;sat_c3;sat_c4])) ^ (to_string c)) in
		(sat_c1 && sat_c2 && sat_c3 && sat_c4);;

	print_endline "building_all_colours";;

	let all_colours = 
		let out = ref [] in
		iter_small_subsets 
			(fun hl->let c=of_list hl in if ((cardinal c) > 0 && valid c) then out:=c::(!out))
			 max_hues_in_colour
			 Hue.all_hues;
		(!out);;

    let println x = print_string ((to_string x) ^ "\n") ;; 

	print_string (String.concat "\n" (List.map to_string all_colours));; 
    	printf "\nNumber of Colours: %d" (List.length all_colours);;
	print_newline();;
 



	let rx c d = 
			for_all (fun g -> 
				exists (fun h -> Hue.rx h g) c
			) d

	let ra_r (ag: IntSet.t) (h: Hue.t) (g: Hue.t) =
			let sat_a = Hue.equal (Hue.without_vetos h) (Hue.without_vetos g) in
			let sat_bcd =
				ISS.for_all (fun (a2: IntSet.t) ->
					(if IntSet.disjoint ag a2
					then ( Hue.mem (STRONG ag) h = Hue.mem (STRONG a2) g ) (*sat_b*)
					else ( ( Hue.mem (STRONG ag) h) && (Hue.mem (STRONG a2) g) ) ==> (IntSet.equal ag a2) (*sat d*) (*NOTE: chunk of text missing from paper *)
					) && (not (Hue.mem (WEAK a2) g)) (*sat_c*)
				) all_coalitions in
			(sat_a && sat_bcd)
	let ra_r_hashtbl = Hashtbl.create 1;; 
	let memoised_ra_r ag h g =
		if Hashtbl.mem ra_r_hashtbl (ag,h,g) 
		then Hashtbl.find  ra_r_hashtbl (ag,h,g) 
		else ra_r ag h g
		 
    let ra (ag: IntSet.t) (c: t) (d: t)= 
		let r (h: Hue.t) (g: Hue.t) = 
			(*memoised_ra_r ag h g in *)
			let sat_a = Hue.equal (Hue.without_vetos h) (Hue.without_vetos g) in
			let sat_bcd =
				ISS.for_all (fun (a2: IntSet.t) ->
					(if IntSet.disjoint ag a2
					then ( Hue.mem (STRONG a2) h = Hue.mem (STRONG a2) g ) (*sat_b*)
					else ( ( Hue.mem (STRONG ag) h) && (Hue.mem (STRONG a2) g) ) ==> (IntSet.equal ag a2) (*sat d*) (*NOTE: chunk of text missing from paper *)
					) && (not (Hue.mem (WEAK a2) g)) (*sat_c*)
				) all_coalitions in
			 if verbose then printf "R %s %s --> %s %s%s\n" (coalition_to_string ag) (Hue.to_string h) (Hue.to_string g) (bool2str sat_a) (bool2str sat_bcd); 
			(sat_a && sat_bcd) in 
		(*assert (r Hue.empty Hue.empty);*)
		let sat_2 =
			for_all (fun h2 ->
				exists (fun h->
					r h h2
				) c
			) d in
		let sat_3 =
			for_all (fun h->
				exists (fun h2->
					r h h2
				) d
			) c in
		if verbose then printf "ra %s %s --> %s %s%s\n" (coalition_to_string ag) (to_string c) (to_string d) (bool2str sat_2) (bool2str sat_3) ;
		(sat_2 && sat_3)
(*				
    let ra (ag: IntSet.t) (c: t) (d: t)= 
	let out = ra ag c d in
	printf "ra %s %s --> %s %s\n" (coalition_to_string ag) (to_string c) (to_string d) (bool2str out);
	out
 *)
	let has_successor set e = List.exists (rx e) set;;


(*	
	
let prune_rule_1 colours =
		List.filter (fun (c: t) ->
			not (
				exists (fun h ->
					(Hue.not_vetoed h) &&
					List.for_all (fun d->
						(not (rx c d)) ||
						for_all (fun g-> not (Hue.rx h g)) d
					) colours
				) c 
			)
		) colours

let directly_fulfilled b colours = List.filter (fun h->mem b h) hues;;
	let directly_fulfilled b colours = List. (fun h->mem b h) hues;;


	let all_instances colours
    List.concat (Colours.map (fun e -> List.map (fun e' -> (e,e')) l') colours)
	
				 
	let prune_step colours = prune_rule_1 colours (* NOTE: MUST ADD OTHER RULES *)  

	let prune colours = fixpoint prune_step colours

	let remaining_colours = prune all_colours

*)						
(*			
		let sat_c2 =
			for_all (fun f->
				match f with
				| CAN(_,alpha) -> mem_f alpha c
				| _	-> assert(false)
			) can_f in
		(sat_c1 && sat_c2)
		*)
	
end	


module Instance = struct
  type t = Colour.t * Hue.t
  let compare = compare
  let to_string (c,h) = "Col: " ^ (Colour.to_string c) ^ "Hue: " ^ (Hue.to_string h)
end

(*NOTE: fix paper, is an instance a three tuple or two tuple?*)

module InstanceSet = struct
	include Set.Make(Instance)
	
	let fulfilled_step beta cl (prev: t) = 
		let ret = ref prev in
		List.iter (fun (c: Colour.t) ->
			Colour.iter (fun h ->
				if (Hue.mem beta h) || (
					exists (fun (d,g) ->
						(Colour.rx c d) &&
						(Hue.rx h g) &&
						(Colour.mem g d)
					) (!ret)
				) then ret := add (c,h) (!ret)
			) c
		) cl;
		(!ret)

	let fulfilled (beta: Formula.t) cl = fixpoint (fulfilled_step beta cl) empty

	let println= iter (fun inst -> print_string ((Instance.to_string inst) ^ "\n") )

				
end

let prune_rule_1 colours =
    		printf "Before rule 1: Number of Colours: %d" (List.length colours);
		print_newline();
		List.filter (fun (c: Colour.t) ->
			not (
				Colour.exists (fun h ->
					(Hue.not_vetoed h) &&
					List.for_all (fun d->
						(not (Colour.rx c d)) ||
						Colour.for_all (fun g-> not (Hue.rx h g)) d
					) colours
				) c 
			)
		) colours;;

let prune_rule_2 in_colours =
    		printf "Before rule 2: Number of Colours: %d" (List.length in_colours);
		print_newline();
		let colours = ref in_colours in
		Hue.iter (fun f -> match f with
             | UNTIL(a,beta) -> 
				let ful_b = InstanceSet.fulfilled beta (!colours) in
				InstanceSet.println ful_b;
				let new_colours = List.filter (fun c->
					Colour.for_all ( 
						fun h-> ((Hue.not_vetoed h) && (Hue.mem beta h)) ==>  InstanceSet.mem (c,h) ful_b (*NOTE: check "non-vetoed" in paper*)
					) c
				) (!colours) in
				colours := new_colours 
 			| _ -> ())
 			Hue.closure;
		(!colours);;

let prune_rule_3 colours =
    		printf "Before rule 3: Number of Colours: %d" (List.length colours);
		print_newline();
		List.filter (fun (c: Colour.t) -> 
			let arbitrary_hue = Colour.min_elt c in
			Hue.for_all (fun f->
				match f with 
				| CAN(ag, psi) ->
(* (Hue.mem (CAN(ag, psi)) arbitrary_hue) ==> *)
					List.exists (fun d-> Colour.ra ag c d && 
						Colour.for_all (fun g->
							(Hue.mem psi g) || (Hue.mem (STRONG ag) g)
						) d
					) colours
				| NOT CAN (ag, psi) -> true (*NOTE: Must fix *)
				| _ -> true
			) arbitrary_hue
		) colours;;

(* The order of applying the pruning rules shouldn't matter
   Lets use rule 2 last since it has the most overhead *)
let prune_step colours = (prune_rule_2 (prune_rule_3 (prune_rule_1 colours)))
let prune_step colours = (prune_rule_3 (prune_rule_2 (prune_rule_1 colours)))

let prune = fixpoint prune_step;;

let remaining_colours = prune Colour.all_colours;;

printf "Number of colours remaining %d\n" (List.length remaining_colours);
;;
let satisfied = List.exists (fun c ->
		let has_phi = Colour.mem_f phi c in
		if has_phi then printf "Satisfied by %s\n" (Colour.to_string c);
		has_phi
	) remaining_colours;;

if satisfied
then print_string "RESULT: SATISFIABLE\n"
else 
	if (max_hues_in_colour < List.length Hue.all_hues) 
	then (printf "Not satisfied, but large colours with more than %d (of %d) hues have been excluded\n" max_hues_in_colour (List.length Hue.all_hues);
	     print_string "RESULT: UNKNOWN\n";)
	else print_string "RESULT: UNsatisfiable\n";

printf "Finished Processing %s\n" (Formula.to_string phi);
