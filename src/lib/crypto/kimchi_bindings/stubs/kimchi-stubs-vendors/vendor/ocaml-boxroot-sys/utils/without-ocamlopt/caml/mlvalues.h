// Definitions to be able to build boxroot without an OCaml install

typedef long value;
typedef char * addr;
typedef void (*scanning_action) (value, value *);
typedef void (*caml_timing_hook) (void);

#define Is_long(x)   (((x) & 1) != 0)
#define Is_block(x)  (((x) & 1) == 0)
#define CAMLassert(x) ((void) 0)
#define Is_young(val) \
  (CAMLassert (Is_block (val)), \
   (addr)(val) < (addr)caml_young_end && (addr)(val) > (addr)caml_young_start)

extern value *caml_young_start, *caml_young_end;
extern char * caml_code_area_start, * caml_code_area_end;
extern void (*caml_scan_roots_hook) (scanning_action);
extern caml_timing_hook caml_minor_gc_begin_hook, caml_minor_gc_end_hook;
extern caml_timing_hook caml_finalise_begin_hook, caml_finalise_end_hook;
