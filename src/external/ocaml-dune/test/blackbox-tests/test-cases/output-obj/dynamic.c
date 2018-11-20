#include <stdio.h>
#include <dlfcn.h>

int main(int argc, char ** argv)
{
  void *handle;
  void (*caml_startup)(char **argv);
  handle = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
  if (handle == NULL) {
    fprintf(stderr, "%s\n", dlerror());
    return 1;
  }
  caml_startup = dlsym(handle, "caml_startup");
  if (handle == NULL) {
    fprintf(stderr, "%s\n", dlerror());
    return 1;
  }
  caml_startup(argv);
  return 0;
}
