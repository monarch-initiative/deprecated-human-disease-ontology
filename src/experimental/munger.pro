:- use_module(bio(ontol_db)). 
:- use_module(bio(ontol_writer)). 
:- use_module(bio(ontol_writer_obo)). 
:- use_module(bio(metadata_nlp)). 
:- use_module(bio(metadata_db)). 
:- use_module(bio(index_util)).
:- use_module(bio(bioprolog_util)).
:- use_module(library(porter_stem)).


entity_xref_from(Grp,D,S) :-
        entity_xref(Grp,D),
        id_idspace(Grp,S).

entity_xref_from_to(Grp,D,S,S2) :-
        entity_xref_idspace(Grp,D,S2),
        id_idspace(Grp,S).

d2group(D,Grp,dc) :-
        subclass(D,Grp),
        id_idspace(Grp,'DC'),
        Grp \= 'DC:0000138'.
d2group(D,Grp,ordo) :-
        entity_xref_from(Grp,D,'Orphanet').
d2group(D,Grp,ps) :-
        subclass(D,Grp),
        atom_concat('OMIM:PS',_,Grp).
d2group(D,Grp,doid) :-
        entity_xref_from(Grp,D,'DOID').
d2group(D,Grp,efo) :-
        entity_xref_from(Grp,D,'EFO').

d2groups(D,L,GN) :-
        solutions(Grp,d2group(D,Grp,GN),L).



d(D) :-
        setof(D,P^d2p(D,P),Ds),
        member(D,Ds).
g(G) :-
        setof(G,D^N^d2group(D,G,N),Gs),
        member(G,Gs).


s(D,G1,G2,G3,G4,G5) :-
        d(D),
        d2groups(D,G1,dc),
        d2groups(D,G2,ordo),
        d2groups(D,G3,ps),
        d2groups(D,G4,doid),
        d2groups(D,G5,efo).

gn(dc).
gn(ordo).
gn(ps).
gn(doid).
gn(efo).

missing(D,GN) :-
        gn(GN),
        d2groups(D,[],GN).

/*
infer_prefix(DC,Prefix) :-
        subclass(D1,DC),
        subclass(D2,DC),
        D1\=D2,
        class_name_stem(D1,D2N),
        class_name_stem(D2,D2N),
        atom_concat(
*/

dcroot('DC:0000138').


%new_omim_cluster(MIM,DC) :-
%        new_omim_cluster(MIM,DC,_).

new_omim_cluster(MIM,DC) :-
        infer_omim_cluster(MIM,DC),
        dcroot(Root),
        subclass(MIM,Root).

conflict_omim_cluster(MIM,DC) :-
        infer_omim_cluster(MIM,DC),
        subclass(MIM,DC2),
        \+ subclassRT(DC2,DC),
        \+ dcroot(DC2).


infer_omim_cluster(MIM,DC) :-
        infer_omim_cluster(MIM,DC,_).
infer_omim_cluster(MIM,DC,Suffix) :-
        class_name_stem(DC,DCN),
        id_idspace(DC,'DC'),
        class_name_stem(MIM,N),
        atom_concat(DCN,Suffix,N),
        Suffix\=''.


class_name_stem(C,N) :-
        class(C,N1),
        porter_stem(N1,N).


omim2ordo_via_doid(Mim,Ordo) :-
        entity_xref_idspace(D,Mim,'OMIM'),
        entity_xref_idspace(D,Ordo,'Orphanet'),
        id_idspace(D,'DOID').

omim2ordo_inc(Mim,Ordo,not_in_ordo) :-
        omim2ordo_via_doid(Mim,Ordo),
        \+ entity_xref(Ordo,Mim).
omim2ordo_inc(Mim,Ordo,not_in_doid) :-
        entity_xref_from_to(Ordo,Mim,'Orphanet','OMIM'),
        % Mim ID should be in doid
        entity_xref_from_to(_,Mim,'DOID','OMIM'),
        \+ omim2ordo_via_doid(Mim,Ordo).

        

        

nonreciprocal(T1,T2,S1,S2) :-
        nonreciprocal1(T1,T2,S1,S2).
nonreciprocal(T1,T2,S1,S2) :-
        nonreciprocal1(T1,T2,S2,S1).

nonreciprocal1(T1,T2,S1,S2) :-
        entity_xref_from_to(T1,T2,S1,S2),
        \+ entity_xref_from_to(T2,T1,S2,S1).

ix :-
        materialize_index(hallmark(+,+)),
        materialize_index(corpus(+)),
        materialize_index(pfreq(+,+)).

corpus(Num) :-
        setof(D,P^hallmark(D,P),Ds),
        length(Ds,Num).


pfreq(P,Freq) :-
        class(P),
        solutions(D,hallmark(D,P),DsWith),
        length(DsWith,NumWith),
        corpus(Num),
        Freq is NumWith / Num.
        
        
/*

  note: actual hallmarks don't work well; e.g. many do not have this described

  hyperparathyroidism
  http://www.monarchinitiative.org/disease/OMIM_145000

  However, hyperparathyroidism *is* described as a hallmark for others
  http://www.monarchinitiative.org/phenotype/HP:0000843

  
  
  */

hallmark(G,D,P) :-
        d2group(D,G,_),
        hallmark(D,P).

hallmark(D,P) :-
        %dpfreq(D,P1,hallmark),
        dpfreq(D,P1,_),
        parentRT(P1,P).





group_phenotype_number(G,P,Num) :-
        g(G),
        setof(D,hallmark(G,D,P),Ds),
        length(Ds,Num).
group_phenotype_number(G,P,Num,Freq,BgFreq,Score) :-
        g(G),
        setof(D,hallmark(G,D,P),DsWithP),
        P \= 'HP:0000001',
        P \= 'HP:0000118',
        length(DsWithP,NumWith),
        g2diseases(G,Ds),
        length(Ds,Num),
        Freq is NumWith/Num,
        pfreq(P,BgFreq),
        BgFreq < 0.02,
        Freq > 0.6,
        Score is (Num * Freq) / BgFreq.

ordo_group_phenotype_number(G,P,Num,F,BF,S) :-
        group_phenotype_number(G,P,Num,F,BF,S),
        \+ \+ subclassT(G,'Orphanet:377794').  % group of disorders

proper_d2group(D,G) :-
        d2group(D,G,_),
        \+ \+ hallmark(D,_).

% must have at least one annot
g2diseases(G,Ds) :-
        setof(D,proper_d2group(D,G),Ds).

        
%% ORDO

is_group_of_disorders(G) :-
        call_unique(subclassT(G,'Orphanet:377794')). % group of disorders


ignore('phenome').
ignore('biological anomaly').
ignore('morphological anomaly').
ignore('clinical syndrome').
ignore('malformation syndrome').
ignore('gene').
ignore('inheritance').
ignore('age of onset').
ignore('particular clinical situation in a disease or syndrome').

is_ignore(X) :- ignore(X),!.
is_ignore(X) :- class(X,XN),ignore(XN),!.

dmatch(Grp,D,IsStemmed) :-
        entity_pair_label_reciprocal_best_intermatch(Grp,D,IsStemmed),
        \+ id_idspace(D,'OMIM').

ordo2do('Orphanet:377788','DOID:4') :- !.  % disease
ordo2do('Orphanet:377794','DOID:4') :- !.  % group -> disease

ordo2do(Grp,D) :-
        setof(D,dmatch(Grp,D,false),Ds),
        !,
        nr_member(D,Ds).
ordo2do(Grp,D) :-
        setof(D,dmatch(Grp,D,true),Ds),
        !,
        nr_member(D,Ds).
ordo2do(Grp,D) :-
        solutions(D,(entity_pair_label_intermatch(Grp,D,_,_,_),\+id_idspace(D,'OMIM')),Ds),
        !,
        nr_member(D,Ds).

nr_member(D,Ds) :-
        member(D,Ds),
        \+ ((member(Z,Ds),
             Z\=D,
             subclassT(Z,Ds))).

% check any with HPOA annotations that ARE groups
ordo_category(X,check,hpoa) :-
        is_group_of_disorders(X),
        \+ \+ dpfreq(X,_,_),
        !.

% preserve if has HPO annotations and not a group
ordo_category(X,preserve,hpoa) :-
        \+ is_group_of_disorders(X),
        \+ \+ dpfreq(X,_,_),
        !.

% try and map as many Groups to DOID or DC as possible
ordo_category(X,map_to_disease,Ds) :-
        is_group_of_disorders(X),
        setof(D,ordo2do(X,D),Ds),
        !.

% DUMB CODE
%  does exactly the same as the above;
%  sometimes clinical subtypes (e.g. Acquired angioedema type 1, Orphanet:100056)
%  are subclasses of disease-level (e.g. Orphanet:91385 ! Acquired angioedema) which map to a single OMIM
%  e.g. OMIM:300909 ! Angioedema Induced by Ace Inhibitors, Susceptibility to;
%  here the OMIM is truly a subclass
ordo_category(X,map_to_disease,Ds) :-
        \+ is_group_of_disorders(X),
        setof(D,ordo2do(X,D),Ds),
        !.


% Map OMIM leaf nodes
ordo_category(X,map_to_omim,[M]) :-
        \+ is_group_of_disorders(X),
        setof(M,entity_xref_idspace(X,M,'OMIM'),[M]),
        !.


% dodgy
ordo_category(X,multi_map_to_omim,Ms) :-
        \+ is_group_of_disorders(X),
        setof(M,entity_xref_idspace(X,M,'OMIM'),Ms),
        !.

% ordo is weird...
ordo_category(X,map_ordo,[M]) :-
        is_group_of_disorders(X),
        d_toks(X,Toks),
        select(genetic,Toks,Rest),
        class(M),
        id_idspace(M,'Orphanet'),
        d_toks(M,Rest),
        !.
% this one never used?
ordo_category(X,map_ordo2,[M]) :-
        is_group_of_disorders(X),
        d_toks(X,Toks),
        select(rare,Toks,Rest),
        class(M),
        id_idspace(M,'Orphanet'),
        d_toks(M,Rest),
        !.
% rare X -> genetic X (arbitrary)
ordo_category(X,map_ordo3,[M]) :-
        is_group_of_disorders(X),
        d_toks(X,Toks),
        select(rare,Toks,Rest),
        class(M),
        id_idspace(M,'Orphanet'),
        d_toks(M,Toks2),
        select(genetic,Toks2,Rest),
        !.

ordo_category(X,ignore,null) :- is_ignore(X),!.
ordo_category(_,unknown,null) :- !.

d_toks(X,Toks) :-
        class(X,N),
        concat_atom(L,' ',N),
        maplist(downcase_atom,L,L2),
        sort(L2,Toks).


% TODO: genes follow this path too
%is_phenome(C) :-
%        parentRT(C,'Orphanet:C001').
is_phenome(C) :-
        subclassRT(C,'Orphanet:C001'),
        !.
is_phenome(C) :-
        parentRT(C,part_of,'Orphanet:C001'),
        !.



all_ordo_category(X,C,W) :-
        class(X),
        id_idspace(X,'Orphanet'),
        is_phenome(X),
        ordo_category(X,C,W).

keep(X) :- ordo_category(X,preserve,_),!.
keep(X) :- ordo_category(X,multi_map_to_omim,_),!.
keep(X) :- ordo_category(X,map_to_omim,_),!.    % see notes above; 

write_all_mdo :-
        write_all_ordo,
        write_all_non_ordo.
write_all_ordo :-
        class(X),
        id_idspace(X,'Orphanet'),        
        is_phenome(X),
        write_ordo(X),
        fail.
write_all_ordo.
write_all_non_ordo :-
        all_ordo_category(X,C,Ds),
        member(D,Ds),
        write_non_ordo(D,C,X),
        fail.
write_all_non_ordo.        

% e.g. write DOID stanzas with ORDO as xref
write_non_ordo(X,map_to_disease,Y) :-
        class2n(Y,YN),
        class2n(X,XN),
        format('[Term]~n'),
        format('id: ~w ! ~w~n',[X,XN]),
        format('xref: ~w ! ~w~n',[Y,YN]),
        nl.

write_non_ordo(X,map_to_omim,Y) :-
        class2n(Y,YN),
        class2n(X,XN),
        format('[Term]~n'),
        format('id: ~w ! ~w~n',[X,XN]),
        (   \+parent(_,Y)
        ->  format('xref: ~w ! ~w~n',[Y,YN])
        ;   format('is_a: ~w ! ~w~n',[Y,YN])),
        nl.

write_non_ordo(X,multi_map_to_omim,Y) :-
        class2n(Y,YN),
        class2n(X,XN),
        format('[Term]~n'),
        format('id: ~w ! ~w~n',[X,XN]),
        format('is_a: ~w ! ~w~n',[Y,YN]),
        nl.



keep(preserve).
keep(multi_map_to_omim).
keep(map_to_omim).
keep(unknown).

write_ordo(X) :-
        subclassRT(X,'ObsoleteClass'),
        !,
        class2n(X,XN),
        format('[Term]~n'),
        format('id: ~w~n',[X]),
        format('name: obsolete ~w~n',[XN]),
        format('is_obsolete: true~n'),
        nl.

write_ordo(X) :-
        ordo_category(X,Cat,With),
        keep(Cat),
        class2n(X,XN),
        !,
        format('! ~w -> ~w~n',[Cat,With]),
        format('[Term]~n'),
        format('id: ~w~n',[X]),
        format('name: ~w~n',[XN]),
        forall(def(X,Y),
               format('def: "~w" [~w]~n',[Y,X])),
        forall(entity_synonym_scope(X,Syn,Scope),
               format('synonym: "~w" ~w []~n',[Syn,Scope])),
        forall(entity_xref(X,Y),
               format('xref: ~w~n',[Y])),
        forall(parent(X,R,Y),
               write_parent(R,Y)),
        nl.

write_parent(subclass,Y) :- write_parent(Y).
write_parent(part_of,Y) :- write_parent(Y).
write_parent(R,Y) :- format('! Ignoring ~w ~w~n',[R,Y]).

write_parent(Y) :- is_ignore(Y),!.
write_parent(Y) :-
        ordo_category(Y,Cat,_),
        keep(Cat),
        class2n(Y,YN),
        !,
        format('is_a: ~w ! ~w~n',[Y,YN]).
write_parent(Y) :-
        ordo_category(Y,map_to_disease,Ds),
        !,
        forall(member(D,Ds),
               (   class2n(D,DN),
                   format('is_a: ~w ! ~w~n',[D,DN]))).
write_parent(Y) :-
        ordo_category(Y,C,Ds),
        (   C=map_ordo
        ;   C=map_ordo2
        ;   C=map_ordo3),
        !,
        member(D,Ds),
        forall(member(D,Ds),
               write_parent(D)).
write_parent(Y) :-
        format('! UH OH: ~w~n',[Y]),
        !.


class2n(C,N) :-
        class(C,N),
        !.
class2n(C,C).


        
/*        
write_ordo(X) :-
        ordo_category(X,map_to_omim,_),
        !.
write_ordo(X) :-
        format('! Leaving as-is~n'),
        write_class(obo,X),
        !.
*/
       

/*
ordo_parent(X,R,Z) :-
        parent(X,R,Y),
        ordo_category(Y,map_to_disease,Z).
ordo_parent(_,R,Y) :-
        ordo_category(Y,map_to_disease,Z).
*/
        
        
merge_equiv_omims :-
        class(M),
        id_idspace(M,'OMIM'),
        setof(P,subclass(M,P),[P]),
        setof(Z,subclass(Z,P),[M]),
        \+ restriction(_,_,P),
        \+ \+ entity_pair_label_intermatch(M,P,_,_,_),
        debug(merge,'Merging ~w -> ~w',[P,M]),
        merge_class(P,M,[use_xrefs(true),add_provenance(true)]),
        fail.
merge_equiv_omims.