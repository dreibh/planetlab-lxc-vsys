#
# Vsys shell - sliverland utility
#
# RPM spec file

%define name vsyssh
%define version 0.99
%define taglevel 1

%define release %{taglevel}%{?pldistro:.%{pldistro}}%{?date:.%{date}}

Vendor: PlanetLab
Packager: PlanetLab Central <support@planet-lab.org>
Distribution: PlanetLab %{plrelease}
URL: %{SCMURL}

Summary: Vsys shell - a sliverland vsys client
Name: %{name}
Version: %{version}
Release: %{release}
License: GPL
Group: System Environment/Libraries
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot

Source0: vsyssh-%{version}.tar.gz

%description
vsyssh is a utility designed to be installed in the slivers, a helper to ease the invokation of vsys scripts.

%prep 
#%setup -q -n vsys-%{version} 
%setup

%build
rm -rf $RPM_BUILD_ROOT
make -C vsyssh

%install
mkdir -p $RPM_BUILD_ROOT/usr/bin
cp -p vsyssh/vsyssh $RPM_BUILD_ROOT/usr/bin

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
/usr/bin/vsyssh

%changelog
* Thu Jan 27 2011 Thierry Parmentelat <thierry.parmentelat@sophia.inria.fr> - vsys-0.99-1
- vsyssh is a simple shell to use vsys through, in the vsys-vsyssh rpm
- fix build dep to require ocaml-ocamldoc instead of ocaml-docs

* Thu Dec 16 2010 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.99-0
- Fixed a memory leak, mainly. The other changes are simply commits that got lost between the move from svn/head to
- git/master.

* Sun Dec 27 2009 Thierry Parmentelat <thierry.parmentelat@sophia.inria.fr> - vsys-0.9-4
- fix build for f12

* Mon May 18 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.9-3
- The previous tag (0.9-2) doesn't build. This one is tested to build and install (or rather, upgrade) fine with the previous
 version of vsys.

* Mon May 18 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.9-2
- Getting rid of factory scripts from the main vsys. They now live elsewhere.

* Tue Mar 31 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.9-1
- * The main change in version 0.9 is file-descriptor passing support. The way this works in Vsys is that you write a
- script whose name has the prefix "fd_". Such scripts show up within slices as ".control" files and can be used to
- exchange file descriptors with root context. Vsys scripts inherit the socket that corresponds to this channel, so they
- do not need to deal with connection setup and teardown. Please see vsys-wrappers/ and vsys-factory/fuse,
- vsys-factory/bm_socket for more details.
- * Version 0.9 is the current stable version of Vsys. It has a fix for a vulnerability in 0.7, and has undergone a
- stability audit.
- * Version 0.95 (trunk) is the new development version.

* Tue Feb 24 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-26
- Tagging to force an update.

* Fri Feb 20 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-25

* Fri Feb 20 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-24

* Thu Feb 19 2009 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-23

* Tue Sep 30 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-22
- Tagging a trivial fix.

* Thu Sep 25 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-21
- includes new portsummary script for CoMon

* Mon Aug 11 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-20
- trying to fix the taglevel relative to the branch name

* Thu Jul 17 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-18
- Change for someone at Imperial.ac.uk, who wants access to Netflow data.

* Tue Jul 15 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-17
- * Don't kill vsys twice on restarts, do it only once
- * Restart vsys following a reinstall

* Wed Jul 02 2008 Thierry Parmentelat <thierry.parmentelat@sophia.inria.fr> - vsys-0.7-16
- Usability changes that are necessary for the stability of CoMon

* Wed Jun 25 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-15
- added patch to pl-ps needed by slicestat
- 
- 

* Mon Jun 23 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-14
- This change is an attempt to fix unexpected blocking after many days of uptime, reported by KyoungSoo.

* Thu Jun 19 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-13
- accept '-' in filenames also
- 

* Wed Jun 18 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-12
- don't overwrite the config file that already exists.
- 

* Wed Jun 18 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-11
- Suppress some temp file that RPM creates frmo showing up as a vsys script.
- 
- 

* Wed Jun 18 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-10
- Changed a policy in vsys. When an acl is empty, the script doesn't show up in ANY slice. The previous behavior was for 
- it to show up in all slices.
- 
- 

* Wed Jun 18 2008 Sapan Bhatia <sapanb@cs.princeton.edu> - vsys-0.7-9
- Added a vsys script for CoMon.
- 

* Mon Jun 16 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-8
- ignore non-existent directories after restart.
- 

* Fri May 16 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-7
- added logrotate configuration to package.
- 

* Mon May 12 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-6
- Added two new scripts for CoMon on 4.2
- 

* Tue May 06 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-5
- 
- Corrected directory that the script mounts to the correct one:
- /var/local/fprobe
- 

* Wed Apr 23 2008 Stephen Soltesz <soltesz@cs.princeton.edu> - vsys-0.7-4
- Pulling the latest changes for the 4.2rc2 release
- 

* Fri Feb 15 2008 Faiyaz Ahmed <faiyaza@cs.princeton.edu> - vsys-0.7-2 vsys-0.7-3
- * daemonization, writing to a logfile, and saving the pid
- 

