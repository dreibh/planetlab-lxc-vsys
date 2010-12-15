(** directfifowatcher.ml: Routines to handle non-persistent scripts *)
(* Semantics:
 *      - The 'out' descriptor must be opened first
 *      - As soon as the backend script dies, the connection to the entry is
 *      closed.
 *      - To avoid user-inflicted pain, all entries are opened at the time
 *      that they are created. Reopening these entries is a little complicated
 *      but nevertheless sound:
 *              * When a script dies, its fd is reopened
 *              * If a script fails to execute, its fd is closed and reopened to
 *              beat a race that can happen when the user closes the connection
 *              before the script can be launched.
 *)

open Inotify
open Unix
open Globals
open Dirwatcher
open Printf
open Splice

let close_if_open fd = (try (ignore(close fd);) with _ -> ())

type in_pathname = string
type directory = string
type base_pathname = string
type slice_name = string

let direct_fifo_table: (in_pathname,(directory*base_pathname*slice_name*Unix.file_descr) option) Hashtbl.t = 
  Hashtbl.create 1024

let pidmap: (int,in_pathname * Unix.file_descr) Hashtbl.t = Hashtbl.create 1024

let move_gate fname =
  let tmpfname=String.concat "." [fname;"tmp"] in 
    (* XXX add a check *)
    Unix.rename fname tmpfname;
    tmpfname

let move_ungate fname restore =
  (* XXX add a check *)
  Unix.rename restore fname

let list_check lst elt _ =
  let rec list_check_rec lst = 
    match lst with
      | [] -> false
      | car::cdr -> 
          if (car==elt) then
               true
          else
            list_check_rec cdr
  in
    list_check_rec lst

let fs_openentry fifoin =
  let fdin =
    try openfile fifoin [O_RDONLY;O_NONBLOCK] 0o777 with 
        e->logprint "Error opening and connecting FIFO: %s,%o\n" fifoin 0o777;raise e
  in
    fdin

(** Open entry safely, by first masking out the file to be opened *)
let openentry_safe root_dir fqp_in backend_spec =
  let restore = move_gate fqp_in in
  let fd_in = fs_openentry restore in
    move_ungate fqp_in restore;
    let (fqp,slice_name) = backend_spec in
      Hashtbl.replace direct_fifo_table fqp_in (Some(root_dir,fqp,slice_name,fd_in))

let openentry root_dir fqp backend_spec =
  let fqp_in = String.concat "." [fqp;"in"] in
    openentry_safe root_dir fqp_in backend_spec

let reopenentry fifoin =
  let entry = try Hashtbl.find direct_fifo_table fifoin with _ -> None in
    match entry with
      | Some(dir, fqp,slice_name,fd) -> close_if_open fd;openentry_safe dir fifoin (fqp,slice_name)
      | None -> ()

(* vsys is activated when a client opens an in file *)
let connect_file fqp_in =
  (* Do we care about this file? *)
  let entry_info = try
    Hashtbl.find direct_fifo_table fqp_in with _ -> None in
    match entry_info with
      | Some(_,execpath,slice_name,fifo_fdin) ->
          begin
            let len = String.length fqp_in in
            let fqp = String.sub fqp_in 0 (len-3) in
            let fqp_out = String.concat "." [fqp;"out"] in
            let fifo_fdout =
              try openfile fqp_out [O_WRONLY;O_NONBLOCK] 0o777 with
                  _-> (* The client is opening the descriptor too fast *)
                    sleep 1;try openfile fqp_out [O_WRONLY;O_NONBLOCK] 0o777 with
                      _->
                        logprint "%s Output pipe not open, using stdout in place of %s\n" slice_name fqp_out;
                        logprint "Check if vsys script %s is executable\n" execpath;
                        stdout
            in
              ignore(sigprocmask SIG_BLOCK [Sys.sigchld]);
              (
                clear_nonblock fifo_fdin;
                let pid = 
                  try
                    Some(create_process execpath [|execpath;slice_name|] fifo_fdin fifo_fdout fifo_fdout) 
                  with 
                    e -> logprint "Error executing %s for slice %s\n" execpath slice_name; None
                in
                  match pid with 
                    | Some(pid) ->
                        if (fifo_fdout <> stdout) then close_if_open fifo_fdout;
                        Hashtbl.add pidmap pid (fqp_in,fifo_fdout)
                    | None ->logprint "Error executing service: %s\n" execpath;reopenentry fqp_in
              );
              ignore(sigprocmask SIG_UNBLOCK [Sys.sigchld]);
          end
      | None -> ()


(** Make a pair of fifo entries *)
let mkentry fqp abspath perm uname = 
  logprint "Making entry %s->%s\n" fqp abspath;
  let fifoin=sprintf "%s.in" fqp in
  let fifoout=sprintf "%s.out" fqp in
    (try Unix.unlink fifoin with _ -> ());
    (try Unix.unlink fifoout with _ -> ());
    (try 
       let infname =(sprintf "%s.in" fqp) in
       let outfname =(sprintf "%s.out" fqp) in
         (* XXX add checks *)
         Unix.mkfifo infname 0o666;
         Unix.mkfifo outfname 0o666;
         ( (* Make the user the owner of the pipes in a non-chroot environment *)
           if (!Globals.nochroot) then
             let pwentry = Unix.getpwnam uname in
               (* XXX add checks *)
               Unix.chown infname pwentry.pw_uid pwentry.pw_gid; 
               Unix.chown outfname pwentry.pw_uid pwentry.pw_gid
         );
         Success
     with 
         e->logprint "Error creating FIFO: %s->%s. May be something wrong at the frontend.\n" fqp fifoout;Failed)


(** Close fifos that just got removed *)
let closeentry fqp =
  let fqp_in = String.concat "." [fqp;"in"] in
  let entry = try Hashtbl.find direct_fifo_table fqp_in with Not_found -> None in
    match entry with
      | None -> ()
      | Some(_,_,_,fd) -> 
          close_if_open fd;
          Hashtbl.remove direct_fifo_table fqp_in

let sigchld_handle s =
  let rec reap_all_processes () =
    let pid,_= try Unix.waitpid [Unix.WNOHANG] 0 with _ -> (-1,WEXITED(-1)) in
      if (pid > 0) then
        begin
          begin
            try
              let fqp_in,fd_out = Hashtbl.find pidmap pid in
                begin
                  reopenentry fqp_in;
                  Hashtbl.remove pidmap pid
                end
            with _ -> ()
          end;
          reap_all_processes ()
        end
  in
    reap_all_processes()
                
(** The backendhandler class: defines event handlers for events in
the backend backend directory.
  @param dir_root The location of the backend in the server context (eg. root context for vservers)
  @param frontend_list List of frontends to serve with this backend
  *)
let rec add_dir_watch fqp =
  Dirwatcher.add_watch fqp [S_Open] direct_fifo_handler
and
    direct_fifo_handler wd dirname evlist fname =
  let is_event = list_check evlist in
    if (is_event Open Attrib) then 
      let fqp_in = String.concat "/" [dirname;fname] in
        connect_file fqp_in

let del_dir_watch fqp =
  ()

let initialize () =
  Sys.set_signal Sys.sigchld (Sys.Signal_handle sigchld_handle)
