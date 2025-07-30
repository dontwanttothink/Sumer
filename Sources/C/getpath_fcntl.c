#include "include/getpath_fcntl.h"
#include <sys/fcntl.h>

int getpath_fcntl(int fd, char *path_buffer) {
  return fcntl(fd, F_GETPATH, path_buffer);
}
