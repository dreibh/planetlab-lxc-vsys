(** Watches directories for events. Agnostic to vsys semantics of backends and
  frontends *)
open Inotify
open Fdwatcher
open Printf
open Globals

(* I don't know if a wd corresponding to a deleted directory is evicted or just
 * leaks - fix implementation of rmdir accordingly
 *)
let wdmap = Hashtbl.create 1024
let masks = Hashtbl.create 1024

let fd = Inotify.init ()

let rec list_check lst elt =
  match lst with
    | [] -> false
    | car::cdr -> if (car==elt) then true else list_check cdr elt

let handle_dir_event dirname evlist str = 
  let fname = String.concat "/" [dirname;str] in
    logprint "File: %s. " fname;
    List.iter 
      (fun e -> 
         logprint "Event: %s\n" (string_of_event e)) 
      evlist

let add_watch dir events handler =
  let wd = Inotify.add_watch fd dir events in
    Hashtbl.add wdmap wd (dir,Some(handler))
      (* Ignore the possibility that the whole directory can disappear and come
       * back while it is masked *)

let mask_watch fqp =
  try 
    Hashtbl.replace masks fqp true
  with _ ->
    ()

let unmask_watch fqp =
  if (Hashtbl.mem masks fqp) then
    begin
      Hashtbl.remove masks fqp
    end
  else
    logprint "WARNING: %s -- Unpaired unmask\n" fqp
  
let asciiz s =
  let rec findfirstnul str idx len =
    if ((idx==len) || 
        (str.[idx]==(char_of_int 0))) then idx
    else
      findfirstnul str (idx+1) len
  in
  let nulterm = findfirstnul s 0 (String.length s) in
    String.sub s 0 nulterm

let receive_event (eventdescriptor:fname_and_fd) (bla:fname_and_fd) =
  let (_,fd) = eventdescriptor in
  let evs = Inotify.read fd in
    List.iter (fun x->
                 match x with
                   | (wd,evlist,_,Some(str)) ->
                       begin
                               let purestr = asciiz(str) in
                               let (dirname,handler) = 
                                 try Hashtbl.find wdmap wd with Not_found->("",None)
                               in
                                   match handler with
                                     | None->logprint "Unhandled watch descriptor\n"
                                     | Some(handler)->
                                         let fqp = String.concat "/" [dirname;purestr] in
                                           logprint "Received event from %s\n" fqp;
                                         let mask_filter = Hashtbl.mem masks fqp in
                                           begin
                                           if ((not mask_filter)) then
                                             begin
                                               (*
                                                logprint "Received event for - %s\n"
                                                        fqp;*)
                                                handler wd dirname evlist
                                                 purestr
                                             end
                                           else
                                             begin
                                                (*logprint "Unmasking %s\n"
                                                 * fqp;*)
                                                unmask_watch fqp
                                             end
                                           end
                       end
                   | _ -> ()) 
      evs

let initialize () =
  Fdwatcher.add_fd (None,fd) (None,fd) receive_event
