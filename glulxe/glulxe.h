/* glulxe.h: Glulxe header file.
    Designed by Andrew Plotkin <erkyrath@eblong.com>
    http://eblong.com/zarf/glulx/index.html
*/

#ifndef _GLULXE_H
#define _GLULXE_H

/* We define our own TRUE and FALSE and NULL, because ANSI
   is a strange world. */
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef NULL
#define NULL 0
#endif

/* You may have to edit the definition of glui16 to make sure it's really a
   16-bit unsigned integer type, and glsi16 to make sure it's really a
   16-bit signed integer type. If they're not, horrible things will happen. */
typedef unsigned short glui16; 
typedef signed short glsi16; 

/* Uncomment this definition to turn on memory-address checking. In
   this mode, all reads and writes to main memory will be checked to
   ensure they're in range. This is slower, but prevents malformed
   game files from crashing the interpreter. */
#define VERIFY_MEMORY_ACCESS (1)

/* Uncomment this definition to turn on Glulx VM profiling. In this
   mode, all function calls are timed, and the timing information is
   written to a data file called "profile-raw". */
/* #define VM_PROFILING (1) */

/* Comment this definition to turn off floating-point support. You
   might need to do this if you are building on a very limited platform
   with no math library. */
#define FLOAT_SUPPORT (1)

/* Some macros to read and write integers to memory, always in big-endian
   format. */
#define Read4(ptr)    \
  ( (glui32)(((unsigned char *)(ptr))[0] << 24)  \
  | (glui32)(((unsigned char *)(ptr))[1] << 16)  \
  | (glui32)(((unsigned char *)(ptr))[2] << 8)   \
  | (glui32)(((unsigned char *)(ptr))[3]))
#define Read2(ptr)    \
  ( (glui16)(((unsigned char *)(ptr))[0] << 8)  \
  | (glui16)(((unsigned char *)(ptr))[1]))
#define Read1(ptr)    \
  ((unsigned char)(((unsigned char *)(ptr))[0]))

#define Write4(ptr, vl)   \
  (((ptr)[0] = (unsigned char)(((glui32)(vl)) >> 24)),   \
   ((ptr)[1] = (unsigned char)(((glui32)(vl)) >> 16)),   \
   ((ptr)[2] = (unsigned char)(((glui32)(vl)) >> 8)),    \
   ((ptr)[3] = (unsigned char)(((glui32)(vl)))))
#define Write2(ptr, vl)   \
  (((ptr)[0] = (unsigned char)(((glui32)(vl)) >> 8)),   \
   ((ptr)[1] = (unsigned char)(((glui32)(vl)))))
#define Write1(ptr, vl)   \
  (((unsigned char *)(ptr))[0] = (vl))

#if VERIFY_MEMORY_ACCESS
#define Verify(adr, ln) verify_address(adr, ln)
#define VerifyW(adr, ln) verify_address_write(adr, ln)
#else
#define Verify(adr, ln) (1)
#define VerifyW(adr, ln) (1)
#endif /* VERIFY_MEMORY_ACCESS */

#define Mem1(adr)  (Verify(adr, 1) ? Read1(memmap+(adr)) : 0)
#define Mem2(adr)  (Verify(adr, 2) ? Read2(memmap+(adr)) : 0)
#define Mem4(adr)  (Verify(adr, 4) ? Read4(memmap+(adr)) : 0)
#define MemW1(adr, vl)  (VerifyW(adr, 1) ? Write1(memmap+(adr), (vl)) : 0)
#define MemW2(adr, vl)  (VerifyW(adr, 2) ? Write2(memmap+(adr), (vl)) : 0)
#define MemW4(adr, vl)  (VerifyW(adr, 4) ? Write4(memmap+(adr), (vl)) : 0)

/* Macros to access values on the stack. These *must* be used 
   with proper alignment! (That is, Stk4 and StkW4 must take 
   addresses which are multiples of four, etc.) If the alignment
   rules are not followed, the program will see performance
   degradation or even crashes, depending on the machine CPU. */

#define Stk1(adr)   \
  (*((unsigned char *)(gstack+(adr))))
#define Stk2(adr)   \
  (*((glui16 *)(gstack+(adr))))
#define Stk4(adr)   \
  (*((glui32 *)(gstack+(adr))))

#define StkW1(adr, vl)   \
  (*((unsigned char *)(gstack+(adr))) = (unsigned char)(vl))
#define StkW2(adr, vl)   \
  (*((glui16 *)(gstack+(adr))) = (glui16)(vl))
#define StkW4(adr, vl)   \
  (*((glui32 *)(gstack+(adr))) = (glui32)(vl))

/* Some useful structures. */

/* oparg_t:
   Represents one operand value to an instruction being executed. The
   code in exec.c assumes that no instruction has more than MAX_OPERANDS
   of these.
*/
typedef struct oparg_struct {
  glui32 desttype;
  glui32 value;
} oparg_t;

#define MAX_OPERANDS (8)

/* operandlist_t:
   Represents the operand structure of an opcode.
*/
typedef struct operandlist_struct {
  int num_ops; /* Number of operands for this opcode */
  int arg_size; /* Usually 4, but can be 1 or 2 */
  int *formlist; /* Array of values, either modeform_Load or modeform_Store */
} operandlist_t;
#define modeform_Load (1)
#define modeform_Store (2)

/* Some useful globals */

extern strid_t gamefile;
extern glui32 gamefile_start, gamefile_len;
extern char *ginit_err, *ginit_err2;

extern unsigned char *memmap;
extern unsigned char *gstack;

extern glui32 ramstart;
extern glui32 endgamefile;
extern glui32 origendmem;
extern glui32 stacksize;
extern glui32 startfuncaddr;
extern glui32 checksum;
extern glui32 stackptr;
extern glui32 frameptr;
extern glui32 pc;
extern glui32 origstringtable;
extern glui32 stringtable;
extern glui32 valstackbase;
extern glui32 localsbase;
extern glui32 endmem;
extern glui32 protectstart, protectend;

extern void (*stream_char_handler)(unsigned char ch);
extern void (*stream_unichar_handler)(glui32 ch);

/* main.c */
extern void fatal_error_handler(char *str, char *arg, int useval, glsi32 val);
extern void nonfatal_warning_handler(char *str, char *arg, int useval, glsi32 val);
#define fatal_error(s)  (fatal_error_handler((s), NULL, FALSE, 0))
#define fatal_error_2(s1, s2)  (fatal_error_handler((s1), (s2), FALSE, 0))
#define fatal_error_i(s, v)  (fatal_error_handler((s), NULL, TRUE, (v)))
#define nonfatal_warning(s) (nonfatal_warning_handler((s), NULL, FALSE, 0))
#define nonfatal_warning_2(s1, s2) (nonfatal_warning_handler((s1), (s2), FALSE, 0))
#define nonfatal_warning_i(s, v) (nonfatal_warning_handler((s), NULL, TRUE, (v)))

/* files.c */
extern int is_gamefile_valid(void);
extern int locate_gamefile(int isblorb);

/* vm.c */
extern void setup_vm(void);
extern void finalize_vm(void);
extern void vm_restart(void);
extern glui32 change_memsize(glui32 newlen, int internal);
extern glui32 *pop_arguments(glui32 count, glui32 addr);
extern int verify_address(glui32 addr, glui32 count);
extern int verify_address_write(glui32 addr, glui32 count);
extern int verify_array_addresses(glui32 addr, glui32 count, glui32 size);

/* exec.c */
extern void execute_loop(void);

/* operand.c */
extern operandlist_t *fast_operandlist[0x80];
extern void init_operands(void);
extern operandlist_t *lookup_operandlist(glui32 opcode);
extern void parse_operands(oparg_t *opargs, operandlist_t *oplist);
extern void store_operand(glui32 desttype, glui32 destaddr, glui32 storeval);
extern void store_operand_s(glui32 desttype, glui32 destaddr, glui32 storeval);
extern void store_operand_b(glui32 desttype, glui32 destaddr, glui32 storeval);

/* funcs.c */
extern void enter_function(glui32 addr, glui32 argc, glui32 *argv);
extern void leave_function(void);
extern void push_callstub(glui32 desttype, glui32 destaddr);
extern void pop_callstub(glui32 returnvalue);
extern glui32 pop_callstub_string(int *bitnum);

/* string.c */
extern void stream_num(glsi32 val, int inmiddle, int charnum);
extern void stream_string(glui32 addr, int inmiddle, int bitnum);
extern glui32 stream_get_table(void);
extern void stream_set_table(glui32 addr);
extern void stream_get_iosys(glui32 *mode, glui32 *rock);
extern void stream_set_iosys(glui32 mode, glui32 rock);
extern char *make_temp_string(glui32 addr);
extern glui32 *make_temp_ustring(glui32 addr);
extern void free_temp_string(char *str);
extern void free_temp_ustring(glui32 *str);

/* heap.c */
extern void heap_clear_glulxe(void);
extern int heap_is_active_glulxe(void);
extern glui32 heap_get_start_glulxe(void);
extern glui32 heap_alloc_glulxe(glui32 len);
extern void heap_free_glulxe(glui32 addr);
extern int heap_get_summary_glulxe(glui32 *valcount, glui32 **summary);
extern int heap_apply_summary_glulxe(glui32 valcount, glui32 *summary);
extern void heap_sanity_check_glulxe(void);

/* serial.c */
extern int init_serial(void);
typedef glui32 (*SaveClassesCallback)(int objectCount, void *objects);
glui32 saveToFileStrWithClasses_glulxe (strid_t fstr);
glui32 restoreClassesChunk_glulxe(strid_t file, glui32 chunkSize);

extern glui32 perform_save(strid_t str, int objectCount, void *objectsP, SaveClassesCallback saveClassesCallback);
extern glui32 perform_restore(strid_t str);
extern glui32 perform_saveundo(void);
extern glui32 perform_restoreundo(void);
extern glui32 perform_verify(void);

/* search.c */
extern glui32 linear_search(glui32 key, glui32 keysize, 
  glui32 start, glui32 structsize, glui32 numstructs, 
  glui32 keyoffset, glui32 options);
extern glui32 binary_search(glui32 key, glui32 keysize, 
  glui32 start, glui32 structsize, glui32 numstructs, 
  glui32 keyoffset, glui32 options);
extern glui32 linked_search(glui32 key, glui32 keysize, 
  glui32 start, glui32 keyoffset, glui32 nextoffset,
  glui32 options);

/* osdepend.c */
extern void *glulx_malloc(glui32 len);
extern void *glulx_realloc(void *ptr, glui32 len);
extern void glulx_free(void *ptr);
extern void glulx_setrandom(glui32 seed);
extern glui32 glulx_random(void);
extern void glulx_sort(void *addr, int count, int size, 
  int (*comparefunc)(void *p1, void *p2));

/* gestalt.c */
extern glui32 do_gestalt(glui32 val, glui32 val2);

/* glkop.c */
extern int init_dispatch(void);
void glulxe_shutdown_dispatch(void);
extern glui32 perform_glk(glui32 funcnum, glui32 numargs, glui32 *arglist);
extern strid_t find_stream_by_id(glui32 objid);

/* profile.c */
extern int init_profile(void);
#if VM_PROFILING
extern glui32 profile_opcount;
#define profile_tick() (profile_opcount++)
extern void profile_in(glui32 addr, int accel);
extern void profile_out(void);
extern void profile_fail(char *reason);
extern void profile_quit(void);
#else /* VM_PROFILING */
#define profile_tick()       (void)(0)
#define profile_in(addr, accel)  (void)(0)
#define profile_out()        (void)(0)
#define profile_fail(reason) (void)(0)
#define profile_quit()       (void)(0)
#endif /* VM_PROFILING */

/* accel.c */
typedef glui32 (*acceleration_func)(glui32 argc, glui32 *argv);
extern void init_accel_glulxe(void);
extern acceleration_func accel_find_func_glulxe(glui32 index);
extern acceleration_func accel_get_func_glulxe(glui32 addr);
extern void accel_set_func_glulxe(glui32 index, glui32 addr);
extern void accel_set_param_glulxe(glui32 index, glui32 val);

#ifdef FLOAT_SUPPORT

/* You may have to edit the definition of gfloat32 to make sure it's really
   a 32-bit floating-point type. */
typedef float gfloat32;

/* Uncomment this definition if your gfloat32 type is not a standard
   IEEE-754 single-precision (32-bit) format. Normally, Glulxe assumes
   that it can reinterpret-cast IEEE-754 int values into gfloat32
   values. If you uncomment this, Glulxe switches to lengthier
   (but safer) encoding and decoding functions. */
/* #define FLOAT_NOT_NATIVE (1) */

/* float.c */
extern int init_float(void);
extern glui32 encode_float(gfloat32 val);
extern gfloat32 decode_float(glui32 val);

#endif /* FLOAT_SUPPORT */

#endif /* _GLULXE_H */
