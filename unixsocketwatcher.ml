(** unixsocketwathcer.ml: Routines to handle unix sockets for fd passing *)
(* Semantics for the client C, script S and Vsys, V
 * - V creates a UNIX socket and listens on it, adding a watch
 * - C connects to the socket
 * - V accepts the connection, forks, execve()s S and gets out of the way
 * - S sends an fd to C and closes the connection
 * - If one of S or C dies, then the other gets a SIGPIPE, Vsys gets a sigchld,
 * either way, Vsys should survive the transaction.
 *)

open Unix
open Globals
open Dirwatcher
open Printf

let close_if_open fd = (try (ignore(close fd);) with _ -> ())

type control_path_name = string
type exec_path_name = string
type slice_name = string

let unix_socket_table: (control_path_name,(exec_path_name*slice_name*Unix.file_descr) option) Hashtbl.t = 
  Hashtbl.create 1024

(** Make a pair of fifo entries *)
let mkentry fqp exec_fqp perm uname = 
  logprint "Making control entry %s->%s\n" fqp exec_fqp;
  let control_filename=sprintf "%s.control" fqp in
    try
      let listening_socket = socket PF_UNIX SOCK_STREAM 0 in
        (try Unix.unlink control_filename with _ -> ());
        let socket_address = ADDR_UNIX(control_filename) in
          bind listening_socket socket_address;
          listen listening_socket 10;
          ( (* Make the user the owner of the pipes in a non-chroot environment *)
            if (!Globals.nochroot) then
              let pwentry = Unix.getpwnam uname in
                Unix.chown control_filename pwentry.pw_uid pwentry.pw_gid
          );
          Hashtbl.replace unix_socket_table control_file (Some(exec_fqp,slice_name,listening_socket));
          Success
    with 
        e->logprint "Error creating FIFO: %s->%s. May be something wrong at the frontend.\n" fqp fifoout;Failed

(** Close sockets that just got removed *)
let closeentry fqp =
  let control_filename = String.concat "." [fqp;"control"] in
  let entry = try Hashtbl.find direct_fifo_table control_filename with Not_found -> None in
    match entry with
      | None -> ()
      | Some(_,_,_,fd) -> 
          shutdown fd SHUTDOWN_ALL;
          close_if_open fd;
          Hashtbl.remove unix_socket_table control_filename

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
                        logprint "%s Output pipe not open, using stdout in place of %s\n" slice_name fqp_out;stdout
            in
              ignore(sigprocmask SIG_BLOCK [Sys.sigchld]);
              (
                clear_nonblock fifo_fdin;
                let pid=try Some(create_process execpath [|execpath;slice_name|] fifo_fdin fifo_fdout fifo_fdout) with e -> None in
                  match pid with 
                    | Some(pid) ->
                        if (fifo_fdout <> stdout) then close_if_open fifo_fdout;
                        Hashtbl.add pidmap pid (fqp_in,fifo_fdout)
                    | None ->logprint "Error executing service: %s\n" execpath;reopenentry fqp_in
              );
              ignore(sigprocmask SIG_UNBLOCK [Sys.sigchld]);
          end
      | None -> ()




let initialize () =
  ()
