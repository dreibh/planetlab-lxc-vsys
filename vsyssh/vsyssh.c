/* gcc -Wall -O2 -g chpid.c -o chpid */
#define _XOPEN_SOURCE
#define _XOPEN_SOURCE_EXTENDED
#define _SVID_SOURCE
#define _GNU_SOURCE
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/select.h>
#include <sys/resource.h>
#include <sys/mount.h>
#include <sys/vfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <sched.h>
#include <stdarg.h>
#include <dirent.h>

int main(int argc, char **argv, char **envp)
{
	if (argc<2) {
		printf("Usage: vsyssh <vsys entry> [cmd]\n");
		exit(1);
	}
	else {
		int vfd0,vfd1;
		char *inf,*outf;
		struct timeval tv;

		inf=(char *)malloc(strlen(argv[1])+3);
		outf=(char *)malloc(strlen(argv[1])+4);
		strcpy(inf,argv[1]);
		strcpy(outf,argv[1]);
		strcat(inf,".in");
		strcat(outf,".out");
		tv.tv_sec = 100;
		tv.tv_usec = 0;

		vfd1 = open(inf,O_WRONLY|O_NONBLOCK);
		vfd0 = open(outf,O_RDONLY|O_NONBLOCK);

		if (vfd0==-1 || vfd1 == -1) {
			printf("Error opening vsys entry %s\n", argv[1]);
			exit(1);
		}

		if (argc<3) {
			fd_set set;
			FD_ZERO(&set);
			FD_SET(0, &set);
			FD_SET(vfd0, &set);

			while (1) {
				int ret;
				printf("vsys>");fflush(stdout);
				ret = select(vfd0+1, &set, NULL, NULL, &tv);
				FD_SET(0, &set);
				FD_SET(vfd0, &set);
				if (FD_ISSET(0,&set)) {
					char lineread[2048];
					int ret;
					printf("Here\n");
					ret=read(0,lineread,2048);
					write(vfd1,lineread,ret);
					FD_CLR(0,&set);
				}
				if (FD_ISSET(vfd0,&set)) {
					char lineread[2048];
					int ret;
					printf("Here2\n");
					ret=read(vfd0,lineread,2048);
					write(1,lineread,ret);
					printf("Here3\n");
					FD_CLR(vfd0,&set);
				}
			}

		}
		else {
			close(0);
			close(1);

			dup2(vfd0,0);
			dup2(vfd1,1);
			execve(argv[3],argv+3,envp);
		}
       }

       return;

}
