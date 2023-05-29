/* gtwindow.c: Window objects
        for GlkIOS, iPhone/IOS implementation of the Glk API.
    Designed by Andrew Plotkin <erkyrath@eblong.com>
    http://www.eblong.com/zarf/glk/index.html
*/

#include "gtoption.h"
#include <stdio.h>
#include <stdlib.h>
#include <wctype.h>

#include "glk.h"
#include "glkios.h"
#include "ipw_pair.h"
#include "ipw_blnk.h"
#include "ipw_grid.h"
#include "ipw_buf.h"
#include "ipw_graphics.h"

#include "gi_blorb.h"
#include "iosfrotz.h"

/* Linked list of all windows */
static window_t *gli_windowlist = NULL; 
static window_t *gli_windowlistend = NULL;

window_t *gli_rootwin = NULL; /* The topmost window. */
window_t *gli_focuswin = NULL; /* The window selected by the player. 
    (This has nothing to do with the "current output stream", which is
    gli_currentstr in gtstream.c. In fact, the program doesn't know
    about gli_focuswin at all.) */

/* This is the screen region which is enclosed by the root window. */
grect_t content_box;

void (*gli_interrupt_handler)(void) = NULL;

static void compute_content_box(void);

int gli_window_has_stylehints(void);

int screen_size_changed;
static int has_stylehints = FALSE; // the game knows about style hints;


/* Set up the window system. This is called from main(). */
void gli_initialize_windows()
{
    int ix;
    
    gli_rootwin = NULL;
    gli_focuswin = NULL;
    
    for (ix = 0; ix < style_NUMSTYLES; ix++) {
        memset(&win_textgrid_styleattrs[ix], 0, sizeof(GLK_STYLE_HINTS));
        memset(&win_textbuffer_styleattrs[ix], 0, sizeof(GLK_STYLE_HINTS));
    }

    /* Figure out the screen size. */
    compute_content_box();
    
    if (!do_autosave)
        screen_size_changed = FALSE;
    has_stylehints = FALSE;
 
    /* Draw the initial setup (no windows) */
    gli_windows_redraw();
}

/* Get out fast. This is used by the ctrl-C interrupt handler, under Unix. 
    It doesn't pause and wait for a keypress, and it calls the Glk interrupt
    handler. Otherwise it's the same as glk_exit(). */
void gli_fast_exit()
{
    if (gli_interrupt_handler) {
        (*gli_interrupt_handler)();
    }

    gli_streams_close_all();
    putchar('\n');
    finished = 1;
}

static void compute_content_box()
{
    /* Set content_box to the entire screen, although one could also
        leave a border for messages or decoration. This is the only
        place where COLS and LINES are checked. All the rest of the
        layout code uses content_box. */
    int width, height;
    
    if (pref_screenwidth)
        width = pref_screenwidth;
    else
        width = iosif_screenwidth; // iosif_textview_width;
    if (pref_screenheight)
        height = pref_screenheight;
    else
        height = iosif_screenheight;//  iosif_textview_height;
    
    content_box.left = 0;
    content_box.top = 0;
    content_box.right = width * kIOSGlkScaleFactor;
    content_box.bottom = height * kIOSGlkScaleFactor;

}

window_t *gli_new_window(glui32 type, glui32 rock)
{
    window_t *win = (window_t *)malloc(sizeof(window_t));
    if (!win)
        return NULL;
    
    win->magicnum = MAGIC_WINDOW_NUM;
    win->rock = rock;
    win->type = type;
    
    win->parent = NULL; /* for now */
    win->data = NULL; /* for now */
    win->char_request = FALSE;
    win->line_request = FALSE;
    win->line_request_uni = FALSE;
    win->char_request_uni = FALSE;
    win->echo_line_input = TRUE;
    win->mouse_request = FALSE;
    win->hyper_request = FALSE;
    win->style = style_Normal;
    win->hyperlink = 0;
    win->store = 0;
    win->splitwin = 0;
    win->terminate_line_input = 0;

    win->str = gli_stream_open_window(win);
    win->echostr = NULL;

    win->prev = NULL;
    win->next = gli_windowlist;
    gli_windowlist = win;
    if (win->next) {
        win->next->prev = win;
    } else {
        gli_windowlistend = win;
    }
    
    if (gli_register_obj)
        win->disprock = (*gli_register_obj)(win, gidisp_Class_Window);
    
    win->iosif_glkViewNum = -1;

    if (!gli_focuswin) // bcs
        gli_focuswin = win;

    return win;
}

void gli_delete_window(window_t *win)
{
    window_t *prev, *next;
    
    gli_focuswin = gli_rootwin;

    if (gli_unregister_obj)
        (*gli_unregister_obj)(win, gidisp_Class_Window, win->disprock);

    if (win->type != wintype_Pair && win->type != wintype_Blank)
        iosif_destroy_glk_view(win->iosif_glkViewNum);

    win->magicnum = 0;
    
    win->echostr = NULL;
    if (win->str) {
        gli_delete_stream(win->str);
        win->str = NULL;
    }
    
    prev = win->prev;
    next = win->next;
    win->prev = NULL;
    win->next = NULL;

    if (prev)
        prev->next = next;
    else
        gli_windowlist = next;
    if (next)
        next->prev = prev;
    else
        gli_windowlistend = prev;
       
    free(win);
}

winid_t glk_window_open(winid_t splitwin, glui32 method, glui32 size, 
    glui32 wintype, glui32 rock)
{
    window_t *newwin, *pairwin, *oldparent;
    window_pair_t *dpairwin;
    grect_t box;
    glui32 val;
    
    if (!gli_rootwin) {
        if (splitwin) {
            gli_strict_warning(L"window_open: ref must be NULL");
            return 0;
        }
        /* ignore method and size now */
        oldparent = NULL;
        
        box = content_box;
    }
    else {
    
        if (!splitwin) {
            gli_strict_warning(L"window_open: ref must not be NULL");
            return 0;
        }
        
        val = (method & winmethod_DivisionMask);
        if (val != winmethod_Fixed && val != winmethod_Proportional) {
            gli_strict_warning(L"window_open: invalid method (not fixed or proportional)");
            return 0;
        }
        
        val = (method & winmethod_DirMask);
        if (val != winmethod_Above && val != winmethod_Below 
            && val != winmethod_Left && val != winmethod_Right) {
            gli_strict_warning(L"window_open: invalid method (bad direction)");
            return 0;
        }

        box = splitwin->bbox;
        
        oldparent = splitwin->parent;
        if (oldparent && oldparent->type != wintype_Pair) {
            gli_strict_warning(L"window_open: parent window is not Pair");
            return 0;
        }
    
    }
    
    newwin = gli_new_window(wintype, rock);
    if (!newwin) {
        gli_strict_warning(L"window_open: unable to create window");
        return 0;
    }
    newwin->splitwin = (intptr_t)splitwin;
    newwin->method = method;
    newwin->size = size;

    switch (wintype) {
        case wintype_Blank:
            newwin->data = win_blank_create(newwin);
            break;
        case wintype_TextGrid:
            newwin->data = win_textgrid_create(newwin);
            break;
        case wintype_TextBuffer:
            newwin->data = win_textbuffer_create(newwin);
            break;
        case wintype_Graphics:
            newwin->data = win_graphics_create(newwin);
            break;
        case wintype_Pair:
            gli_strict_warning(L"window_open: cannot open pair window directly");
            gli_delete_window(newwin);
            return 0;
        default:
            /* Unknown window type -- do not print a warning, just return 0
                to indicate that it's not possible. */
            gli_delete_window(newwin);
            return 0;
    }
    
    if (!newwin->data) {
        gli_strict_warning(L"window_open: unable to create window");
        return 0;
    }
    
    if (!splitwin) {
        gli_rootwin = newwin;
        if (wintype == wintype_TextGrid || wintype == wintype_TextBuffer || wintype == wintype_Graphics)
            newwin->iosif_glkViewNum = iosif_new_glk_view(newwin);

        gli_window_rearrange(newwin, &box);
        /* redraw everything, which is just the new first window */
        gli_windows_redraw();
    }
    else {
        /* create pairwin, with newwin as the key */
        pairwin = gli_new_window(wintype_Pair, 0);
        dpairwin = win_pair_create(pairwin, method, newwin, size);
        pairwin->data = dpairwin;
            
        dpairwin->child1 = splitwin;
        dpairwin->child2 = newwin;
        
        splitwin->parent = pairwin;
        newwin->parent = pairwin;
        pairwin->parent = oldparent;

        if (oldparent) {
            window_pair_t *dparentwin = oldparent->data;
            if (dparentwin->child1 == splitwin)
                dparentwin->child1 = pairwin;
            else
                dparentwin->child2 = pairwin;
        }
        else {
            gli_rootwin = pairwin;
        }
        if (wintype == wintype_TextGrid || wintype == wintype_TextBuffer || wintype == wintype_Graphics)
            newwin->iosif_glkViewNum = iosif_new_glk_view(newwin);

        gli_window_rearrange(pairwin, &box);
        /* redraw the new pairwin and all its contents */
        gli_window_redraw(pairwin);
    }
    
    return newwin;
}

static void gli_window_close(window_t *win, int recurse)
{
    window_t *wx;
    
    if (gli_focuswin == win) {
        gli_focuswin = NULL;
    }
    
    for (wx=win->parent; wx; wx=wx->parent) {
        if (wx->type == wintype_Pair) {
            window_pair_t *dwx = wx->data;
            if (dwx->key == win) {
                dwx->key = NULL;
                dwx->keydamage = TRUE;
            }
        }
    }
    
    switch (win->type) {
        case wintype_Blank: {
            window_blank_t *dwin = win->data;
            win_blank_destroy(dwin);
            }
            break;
        case wintype_Pair: {
            window_pair_t *dwin = win->data;
            if (recurse) {
                if (dwin->child1)
                    gli_window_close(dwin->child1, TRUE);
                if (dwin->child2)
                    gli_window_close(dwin->child2, TRUE);
            }
            win_pair_destroy(dwin);
            }
            break;
        case wintype_TextBuffer: {
            window_textbuffer_t *dwin = win->data;
            win_textbuffer_destroy(dwin);
            }
            break;
        case wintype_TextGrid: {
            window_textgrid_t *dwin = win->data;
            win_textgrid_destroy(dwin);
            }
            break;
        case wintype_Graphics: {
            window_graphics_t *dwin = win->data;
            win_graphics_destroy(dwin);
            }
            break;
    }
    
    gli_delete_window(win);
}

void glk_window_close(window_t *win, stream_result_t *result)
{
    if (!win) // we'll silently ignore this, it seems a lot of games do it
        return;
        
    if (win == gli_rootwin || win->parent == NULL) {
        /* close the root window, which means all windows. */
        
        gli_rootwin = 0;
        
        /* begin (simpler) closation */
        
        gli_stream_fill_result(win->str, result);
        gli_window_close(win, TRUE); 
        /* redraw everything */
        gli_windows_redraw();
    }
    else {
        /* have to jigger parent */
        grect_t box;
        window_t *pairwin, *sibwin, *grandparwin, *wx;
        window_pair_t *dpairwin, *dgrandparwin;
        int keydamage_flag;
        
        pairwin = win->parent;
        dpairwin = pairwin->data;
        if (win == dpairwin->child1) {
            sibwin = dpairwin->child2;
        }
        else if (win == dpairwin->child2) {
            sibwin = dpairwin->child1;
        }
        else {
            gli_strict_warning(L"window_close: window tree is corrupted");
            return;
        }
        
        box = pairwin->bbox;

        grandparwin = pairwin->parent;
        if (!grandparwin) {
            gli_rootwin = sibwin;
            sibwin->parent = NULL;
        }
        else {
            dgrandparwin = grandparwin->data;
            if (dgrandparwin->child1 == pairwin)
                dgrandparwin->child1 = sibwin;
            else
                dgrandparwin->child2 = sibwin;
            sibwin->parent = grandparwin;
        }
        
        /* Begin closation */
        
        gli_stream_fill_result(win->str, result);

        /* Close the child window (and descendants), so that key-deletion can
            crawl up the tree to the root window. */
        gli_window_close(win, TRUE); 
        
        /* This probably isn't necessary, but the child *is* gone, so just
            in case. */
        if (win == dpairwin->child1) {
            dpairwin->child1 = NULL;
        }
        else if (win == dpairwin->child2) {
            dpairwin->child2 = NULL;
        }
        
        /* Now we can delete the parent pair. */
        gli_window_close(pairwin, FALSE);

        keydamage_flag = FALSE;
        for (wx=sibwin; wx; wx=wx->parent) {
            if (wx->type == wintype_Pair) {
                window_pair_t *dwx = wx->data;
                if (dwx->keydamage) {
                    keydamage_flag = TRUE;
                    dwx->keydamage = FALSE;
                }
            }
        }
        
        if (keydamage_flag) {
            box = content_box;
            gli_window_rearrange(gli_rootwin, &box);
            gli_windows_redraw();
        }
        else {
            gli_window_rearrange(sibwin, &box);
            gli_window_redraw(sibwin);
        }
    }
}

void glk_window_get_arrangement(window_t *win, glui32 *method, glui32 *size, 
    winid_t *keywin)
{
    window_pair_t *dwin;
    glui32 val;
    
    if (!win) {
        gli_strict_warning(L"window_get_arrangement: invalid ref");
        return;
    }
    
    if (win->type != wintype_Pair) {
        gli_strict_warning(L"window_get_arrangement: not a Pair window");
        return;
    }
    
    dwin = win->data;
    
    val = dwin->dir | dwin->division;
    if (!dwin->hasborder)
        val |= winmethod_NoBorder;

    if (size)
        *size = dwin->size;
    if (keywin) {
        if (dwin->key)
            *keywin = dwin->key;
        else
            *keywin = NULL;
    }
    if (method)
        *method = val;
}

void glk_window_set_arrangement(window_t *win, glui32 method, glui32 size, 
    winid_t key)
{
    window_pair_t *dwin;
    glui32 newdir;
    grect_t box;
    int newvertical, newbackward;
    
    if (!win) {
        gli_strict_warning(L"window_set_arrangement: invalid ref");
        return;
    }
    
    if (win->type != wintype_Pair) {
        gli_strict_warning(L"window_set_arrangement: not a Pair window");
        return;
    }
    
    if (key) {
        window_t *wx;
        if (key->type == wintype_Pair) {
            gli_strict_warning(L"window_set_arrangement: keywin cannot be a Pair");
            return;
        }
        for (wx=key; wx; wx=wx->parent) {
            if (wx == win)
                break;
        }
        if (wx == NULL) {
            gli_strict_warning(L"window_set_arrangement: keywin must be a descendant");
            return;
        }
    }
    
    dwin = win->data;
    box = win->bbox;
    
    newdir = method & winmethod_DirMask;
    newvertical = (newdir == winmethod_Left || newdir == winmethod_Right);
    newbackward = (newdir == winmethod_Left || newdir == winmethod_Above);
    if (!key)
        key = dwin->key;

    if ((newvertical && !dwin->vertical) || (!newvertical && dwin->vertical)) {
        if (!dwin->vertical)
            gli_strict_warning(L"window_set_arrangement: split must stay horizontal");
        else
            gli_strict_warning(L"window_set_arrangement: split must stay vertical");
        return;
    }
    
    if (key && key->type == wintype_Blank 
        && (method & winmethod_DivisionMask) == winmethod_Fixed) {
        gli_strict_warning(L"window_set_arrangement: a Blank window cannot have a fixed size");
        return;
    }

    if ((newbackward && !dwin->backward) || (!newbackward && dwin->backward)) {
        /* switch the children */
        window_t *tmpwin = dwin->child1;
        dwin->child1 = dwin->child2;
        dwin->child2 = tmpwin;
    }
    
    /* set up everything else */
    dwin->dir = newdir;
    dwin->division = method & winmethod_DivisionMask;
    dwin->key = key;
    dwin->size = size;
    dwin->hasborder = ((method & winmethod_BorderMask) == winmethod_Border);

    dwin->vertical = (dwin->dir == winmethod_Left || dwin->dir == winmethod_Right);
    dwin->backward = (dwin->dir == winmethod_Left || dwin->dir == winmethod_Above);
    
    gli_window_rearrange(win, &box);
    gli_window_redraw(win);
}

winid_t glk_window_iterate(winid_t win, glui32 *rock)
{
    if (!win) {
        win = gli_windowlist;
    }
    else {
        win = win->next;
    }
    
    if (win) {
        if (rock)
            *rock = win->rock;
        return win;
    }
    
    if (rock)
        *rock = 0;
    return NULL;
}

window_t *gli_window_iterate_backward(winid_t win, glui32 *rock)
{
    if (!win) {
        win = gli_windowlistend;
    }
    else {
        win = win->prev;
    }
    
    if (win) {
        if (rock)
            *rock = win->rock;
        return win;
    }
    
    if (rock)
        *rock = 0;
    return NULL;
}

window_t *gli_window_iterate_treeorder(window_t *win)
{
    if (!win)
        return gli_rootwin;
    
    if (win->type == wintype_Pair) {
        window_pair_t *dwin = win->data;
        if (!dwin->backward)
            return dwin->child1;
        else
            return dwin->child2;
    }
    else {
        window_t *parwin;
        window_pair_t *dwin;
        
        while (win->parent) {
            parwin = win->parent;
            dwin = parwin->data;
            if (!dwin->backward) {
                if (win == dwin->child1)
                    return dwin->child2;
            }
            else {
                if (win == dwin->child2)
                    return dwin->child1;
            }
            win = parwin;
        }
        
        return NULL;
    }
}

glui32 glk_window_get_rock(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"window_get_rock: invalid ref.");
        return 0;
    }
    
    return win->rock;
}

winid_t glk_window_get_root()
{
    if (!gli_rootwin)
        return NULL;
    return gli_rootwin;
}

winid_t glk_window_get_parent(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"window_get_parent: invalid ref");
        return 0;
    }
    if (win->parent)
        return win->parent;
    else
        return 0;
}

winid_t glk_window_get_sibling(window_t *win)
{
    window_pair_t *dparwin;
    
    if (!win) {
        gli_strict_warning(L"window_get_sibling: invalid ref");
        return 0;
    }
    if (!win->parent)
        return 0;
    
    dparwin = win->parent->data;
    if (dparwin->child1 == win)
        return dparwin->child2;
    else if (dparwin->child2 == win)
        return dparwin->child1;
    return 0;
}

glui32 glk_window_get_type(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"window_get_parent: invalid ref");
        return 0;
    }
    return win->type;
}

void glk_window_get_size(window_t *win, glui32 *width, glui32 *height)
{
    glui32 wid = 0;
    glui32 hgt = 0;
    
    if (!win) {
        gli_strict_warning(L"window_get_size: invalid ref");
        return;
    }
    
    switch (win->type) {
        case wintype_Blank:
        case wintype_Pair:
            /* always zero */
            break;
        case wintype_TextGrid:
        case wintype_TextBuffer:
            wid = win->bbox.right - win->bbox.left;
            hgt = win->bbox.bottom - win->bbox.top;
            wid /= iosif_fixed_font_width * kIOSGlkScaleFactor;
            hgt /= iosif_fixed_font_height * kIOSGlkScaleFactor;
            break;
        case wintype_Graphics:
            wid = win->bbox.right - win->bbox.left;
            hgt = win->bbox.bottom - win->bbox.top;
	    break;
    }

    if (width)
        *width = wid;
    if (height)
        *height = hgt;
}

strid_t glk_window_get_stream(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"window_get_stream: invalid ref");
        return NULL;
    }
    
    return win->str;
}

strid_t glk_window_get_echo_stream(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"window_get_echo_stream: invalid ref");
        return 0;
    }
    
    if (win->echostr)
        return win->echostr;
    else
        return 0;
}

void glk_window_set_echo_stream(window_t *win, stream_t *str)
{
    if (!win) {
        gli_strict_warning(L"window_set_echo_stream: invalid window id");
        return;
    }
    
    win->echostr = str;
}

void glk_set_window(window_t *win)
{
    if (!win) {
        gli_stream_set_current(NULL);
    }
    else {
        gli_stream_set_current(win->str);
    }
}

void gli_windows_unechostream(stream_t *str)
{
    window_t *win;
    
    for (win=gli_windowlist; win; win=win->next) {
        if (win->echostr == str)
            win->echostr = NULL;
    }
}

/* Some trivial switch functions which make up for the fact that we're not
    doing this in C++. */

void gli_window_rearrange(window_t *win, grect_t *box)
{
    switch (win->type) {
        case wintype_Blank:
            win_blank_rearrange(win, box);
            break;
        case wintype_Pair:
            win_pair_rearrange(win, box);
            break;
        case wintype_TextGrid:
            win_textgrid_rearrange(win, box);
            break;
        case wintype_TextBuffer:
            win_textbuffer_rearrange(win, box);
            break;
        case wintype_Graphics:
            win_graphics_rearrange(win, box);
            break;
    }
    if (win->iosif_glkViewNum >= 0) {
        iosif_glk_view_rearrange(win->iosif_glkViewNum, win);
    }
}

void gli_windows_update()
{
    window_t *win;
    
    for (win=gli_windowlist; win; win=win->next) {
        switch (win->type) {
            case wintype_TextGrid:
                win_textgrid_update(win);
                break;
            case wintype_TextBuffer:
                win_textbuffer_update(win);
                break;
            case wintype_Graphics:
                win_graphics_update(win);
		break;
        }
    }
}

void gli_window_redraw(window_t *win)
{
    if (win->bbox.left >= win->bbox.right 
        || win->bbox.top >= win->bbox.bottom)
        return;
    
    switch (win->type) {
        case wintype_Blank:
            win_blank_redraw(win);
            break;
        case wintype_Pair:
            win_pair_redraw(win);
            break;
        case wintype_TextGrid:
            win_textgrid_redraw(win);
            break;
        case wintype_TextBuffer:
            win_textbuffer_redraw(win);
            break;
        case wintype_Graphics:
            win_graphics_redraw(win);
            break;
    }
}

void gli_windows_redraw()
{
    
    if (gli_rootwin) {
        /* We could draw a border around content_box, if we wanted. */
        gli_window_redraw(gli_rootwin);
    }
    else {
        /* There are no windows at all. */
        iosif_erase_screen();
#if 0
	int ix, jx;
        ix = (content_box.left+content_box.right) / 2 - 7;
        if (ix < 0)
            ix = 0;
        jx = (content_box.top+content_box.bottom) / 2;
        move(jx, ix);
        local_addwstr(L"Please wait...");
#endif
    }
}

void gli_windows_size_change()
{
    compute_content_box();
    if (gli_rootwin) {
        gli_window_rearrange(gli_rootwin, &content_box);
    }
    gli_windows_redraw();

    gli_event_store(evtype_Arrange, NULL, 0, 0);
}

void gli_windows_place_cursor()
{
    if (gli_rootwin && gli_focuswin) {
        int xpos, ypos;
        xpos = 0;
        ypos = 0;
        switch (gli_focuswin->type) {
            case wintype_TextGrid: 
                win_textgrid_place_cursor(gli_focuswin, &xpos, &ypos);
                break;
            case wintype_TextBuffer: 
                win_textbuffer_place_cursor(gli_focuswin, &xpos, &ypos);
                break;
            default:
                break;
        }

	cwin = gli_focuswin->iosif_glkViewNum;
	cursor_row = ypos;
	cursor_col = xpos;

//        move(gli_focuswin->bbox.top + ypos, gli_focuswin->bbox.left + xpos);
    }
    else {
//        move(content_box.bottom-1, content_box.right-1);
    }
}

void gli_windows_set_paging(int forcetoend)
{
    window_t *win;
    
    for (win=gli_windowlist; win; win=win->next) {
        switch (win->type) {
            case wintype_TextBuffer:
                win_textbuffer_set_paging(win, forcetoend);
                break;
        }
    }
}

void gli_windows_trim_buffers()
{
    window_t *win;
    
    for (win=gli_windowlist; win; win=win->next) {
        switch (win->type) {
            case wintype_TextBuffer:
                win_textbuffer_trim_buffer(win);
                break;
        }
    }
}

void glk_request_char_event(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"request_char_event: invalid ref");
        return;
    }
    
    if (win->char_request || win->line_request) {
        gli_strict_warning(L"request_char_event: window already has keyboard request");
        return;
    }
    
    switch (win->type) {
        case wintype_TextBuffer:
        case wintype_TextGrid:
            win->char_request = TRUE;
            win->char_request_uni = FALSE;
            break;
        default:
            gli_strict_warning(L"request_char_event: window does not support keyboard input");
            break;
    }
    
}

void glk_request_line_event(window_t *win, char *buf, glui32 maxlen, 
    glui32 initlen)
{
    if (!win) {
        gli_strict_warning(L"request_line_event: invalid ref");
        return;
    }
    
    if (win->char_request || win->line_request) {
        gli_strict_warning(L"request_line_event: window already has keyboard request");
        return;
    }
    
    switch (win->type) {
        case wintype_TextBuffer:
            win->line_request = TRUE;
            win->line_request_uni = FALSE;
            win_textbuffer_init_line(win, buf, FALSE, maxlen, initlen);
            break;
        case wintype_TextGrid:
            win->line_request = TRUE;
            win->line_request_uni = FALSE;
            win_textgrid_init_line(win, buf, FALSE, maxlen, initlen);
            break;
        default:
            gli_strict_warning(L"request_line_event: window does not support keyboard input");
            break;
    }
    
}

#ifdef GLK_MODULE_UNICODE

void glk_request_char_event_uni(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"request_char_event: invalid ref");
        return;
    }
    
    if (win->char_request || win->line_request) {
        gli_strict_warning(L"request_char_event: window already has keyboard request");
        return;
    }
    
    switch (win->type) {
        case wintype_TextBuffer:
        case wintype_TextGrid:
            win->char_request = TRUE;
            win->char_request_uni = TRUE;
            break;
        default:
            gli_strict_warning(L"request_char_event: window does not support keyboard input");
            break;
    }
    
}

void glk_request_line_event_uni(window_t *win, glui32 *buf, glui32 maxlen, 
    glui32 initlen)
{
    if (!win) {
        gli_strict_warning(L"request_line_event: invalid ref");
        return;
    }
    
    if (win->char_request || win->line_request) {
        gli_strict_warning(L"request_line_event: window already has keyboard request");
        return;
    }
    
    switch (win->type) {
        case wintype_TextBuffer:
            win->line_request = TRUE;
            win->line_request_uni = TRUE;
            win_textbuffer_init_line(win, buf, TRUE, maxlen, initlen);
            break;
        case wintype_TextGrid:
            win->line_request = TRUE;
            win->line_request_uni = TRUE;
            win_textgrid_init_line(win, buf, TRUE, maxlen, initlen);
            break;
        default:
            gli_strict_warning(L"request_line_event: window does not support keyboard input");
            break;
    }
    
}

#endif /* GLK_MODULE_UNICODE */

void glk_request_mouse_event(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"request_mouse_event: invalid ref");
        return;
    }
    switch (win->type)
    {
        case wintype_Graphics:
        case wintype_TextGrid:
            iosif_enable_tap(win->iosif_glkViewNum);
            win->mouse_request = TRUE;
            break;
        default:
            /* do nothing */
            break;
    }
    return;
}

void glk_cancel_char_event(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"cancel_char_event: invalid ref");
        return;
    }
    
    switch (win->type) {
        case wintype_TextBuffer:
        case wintype_TextGrid:
            win->char_request = FALSE;
            break;
        default:
            /* do nothing */
            break;
    }
}

void glk_cancel_line_event(window_t *win, event_t *ev)
{
    event_t dummyev;
    
    if (!ev) {
        ev = &dummyev;
    }

    gli_event_clearevent(ev);
    
    if (!win) {
        gli_strict_warning(L"cancel_line_event: invalid ref");
        return;
    }
    
    switch (win->type) {
        case wintype_TextBuffer:
            if (win->line_request) {
                win_textbuffer_cancel_line(win, ev);
            }
            break;
        case wintype_TextGrid:
            if (win->line_request) {
                win_textgrid_cancel_line(win, ev);
            }
            break;
        default:
            /* do nothing */
            break;
    }
}

void glk_cancel_mouse_event(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"cancel_mouse_event: invalid ref");
        return;
    }
    switch (win->type) {
        case wintype_Graphics:
        case wintype_TextGrid:
            if (!win->hyper_request)
                iosif_disable_tap(win->iosif_glkViewNum);
            break;
        default:
            /* do nothing */
            break;
    }
    win->mouse_request = FALSE;

    return;
}

void gli_window_put_char(window_t *win, glui32 ch)
{
    wchar_t wc = glui32_to_wchar(ch);

    /* In case the program hasn't checked gestalt for this character
     * we should filter it here for a legal value.
     */

    if ( gli_bad_latin_key(ch) /*|| (ch >= 0x100 && ! iswprint(wc))*/ )
        wc = L'?';

    switch (win->type) {
        case wintype_TextBuffer:
            win_textbuffer_putchar(win, wc);
            break;
        case wintype_TextGrid:
            win_textgrid_putchar(win, wc);
            break;
    }
}

void glk_window_clear(window_t *win)
{
    if (!win) {
        gli_strict_warning(L"window_clear: invalid ref");
        return;
    }
    
    if (win->line_request) {
        gli_strict_warning(L"window_clear: window has pending line request");
        win->line_request = 0;
    }

    switch (win->type) {
        case wintype_TextBuffer:
            win_textbuffer_clear(win);
            break;
        case wintype_TextGrid:
            win_textgrid_clear(win);
            break;
        case wintype_Graphics:
            iosif_glk_window_erase_rect(win->iosif_glkViewNum, win->bbox.left, win->bbox.top,
					 win->bbox.right-win->bbox.left, win->bbox.bottom-win->bbox.top);
            break;
    }
}

void glk_window_move_cursor(window_t *win, glui32 xpos, glui32 ypos)
{
    if (!win) {
        gli_strict_warning(L"window_move_cursor: invalid ref");
        return;
    }
    
    switch (win->type) {
        case wintype_TextGrid:
            win_textgrid_move_cursor(win, xpos, ypos);
            break;
        default:
            gli_strict_warning(L"window_move_cursor: not a TextGrid window");
            break;
    }
}

#ifdef GLK_MODULE_LINE_ECHO

void glk_set_echo_line_event(window_t *win, glui32 val)
{
    if (!win) {
        gli_strict_warning(L"set_echo_line_event: invalid ref");
        return;
    }
    
    win->echo_line_input = (val != 0);
}

#endif /* GLK_MODULE_LINE_ECHO */

#ifdef GLK_MODULE_LINE_TERMINATORS

void glk_set_terminators_line_event(window_t *win, glui32 *keycodes,
    glui32 count)
{
    int ix;
    glui32 res, val;

    if (!win) {
        gli_strict_warning(L"set_terminators_line_event: invalid ref");
        return;
    }

    /* We only allow escape and the function keys as line input terminators.
       We encode those in a bitmask. */
    res = 0;
    if (keycodes) {
        for (ix=0; ix<count; ix++) {
            if (keycodes[ix] == keycode_Escape) {
                res |= 0x10000;
            }
            else {
                val = keycode_Func1 + 1 - keycodes[ix];
                if (val >= 1 && val <= 12)
                    res |= (1 << val);
            }
        }
    }

    win->terminate_line_input = res;
}

#endif /* GLK_MODULE_LINE_TERMINATORS */

void gli_ios_set_focus(window_t *win) {
    gli_focuswin = win;
    gli_windows_place_cursor();    
}


/* Keybinding functions. */

void gcmd_win_change_focus(window_t *win, glui32 arg)
{
    win = gli_window_iterate_treeorder(gli_focuswin);
    while (win == NULL || win->type == wintype_Pair) {
        if (win == gli_focuswin)
            return;
        win = gli_window_iterate_treeorder(win);
    }
    
    gli_focuswin = win;
}

void gcmd_win_refresh(window_t *win, glui32 arg)
{
    gli_windows_redraw();
}



#ifdef GLK_MODULE_HYPERLINKS

void glk_set_hyperlink_stream(strid_t str, glui32 linkval)
{
    if (!str || !str->writable || !str->win)
        return;
        
    switch (str->type) {
        case strtype_Window:
            str->win->hyperlink = linkval;
            if (str->win->type == wintype_TextGrid || str->win->type == wintype_TextBuffer) {
                iosif_set_hyperlink_value(str->win->iosif_glkViewNum, linkval, TRUE);
            }
            if (str->win->echostr && str->win->echostr != str)
                glk_set_hyperlink_stream(str->win->echostr, linkval);
            break;
    }
}

void glk_request_hyperlink_event(winid_t win)
{
    if (!win) {
        gli_strict_warning(L"request_mouse_event: invalid ref");
        return;
    }
    switch (win->type)
    {
        case wintype_TextGrid:
        case wintype_TextBuffer:
            iosif_enable_tap(win->iosif_glkViewNum);
            win->hyper_request = TRUE;
            break;
        default:
            /* do nothing */
            break;
    }
    return;
}

void glk_cancel_hyperlink_event(winid_t win)
{
    if (!win) {
        gli_strict_warning(L"cancel_mouse_event: invalid ref");
        return;
    }
    switch (win->type) {
        case wintype_TextBuffer:
        case wintype_TextGrid:
            if (!win->mouse_request)
                iosif_disable_tap(win->iosif_glkViewNum);
            break;
        default:
            /* do nothing */
            break;
    }
    win->hyper_request  = FALSE;
}

#endif /* GLK_MODULE_HYPERLINKS */


int gli_window_has_stylehints(void)
{
    return has_stylehints;
}

void gli_stylehint_set(glui32 wintype, glui32 styl, glui32 hint, glsi32 val)
{
    switch (wintype) {
        case wintype_TextBuffer:
            win_textbuffer_stylehint_set(styl, hint, val);
            break;
        case wintype_TextGrid:
            win_textgrid_stylehint_set(styl, hint, val);
            break;
        case wintype_AllTypes:
            win_textbuffer_stylehint_set(styl, hint, val);
            win_textgrid_stylehint_set(styl, hint, val);
            break;
        default:
            break;
    }
    has_stylehints = TRUE;
}


glsi32 gli_stylehint_get(window_t *win, glui32 styl, glui32 hint)
{
    if (win)
        switch (win->type) {
            case wintype_TextBuffer:
                return win_textbuffer_stylehint_get(win, styl, hint);
                break;
            case wintype_TextGrid:
                return win_textgrid_stylehint_get(win, styl, hint);
                break;
            default:
                break;
        }
    return BAD_STYLE;
}

void gli_stylehint_clear(glui32 wintype, glui32 styl, glui32 hint)
{
    switch (wintype) {
        case wintype_TextBuffer:
            win_textbuffer_stylehint_clear(styl, hint);
            break;
        case wintype_TextGrid:
            win_textgrid_stylehint_clear(styl, hint);
            break;
        case wintype_AllTypes:
            win_textbuffer_stylehint_clear(styl, hint);
            win_textgrid_stylehint_clear(styl, hint);
            break;
        default:
            break;
    }
}

void gli_window_get_stylehints(winid_t win, GLK_STYLE_HINTS *hints)
{
    if (!win) {
        gli_strict_warning(L"gli_window_get_stylehints: invalid ref");
        return;
    }
    // it looks like a waste of good code, but we're avoid derefing the pointer
    if ((glui32)win == STYLEHINT_TEXT_BUFFER) {
        win_textbuffer_get_stylehints(win, hints);
        return;
    }
    if ((glui32)win == STYLEHINT_TEXT_GRID) {
        win_textgrid_get_stylehints(win, hints);        
        return;
    }
    if (win->type == wintype_TextBuffer) {
        win_textbuffer_get_stylehints(win, hints);
        return;
    }
    if (win->type == wintype_TextGrid) {
        win_textgrid_get_stylehints(win, hints);        
        return;
    }
    return;
}

void gli_window_set_stylehints(winid_t win, GLK_STYLE_HINTS *hints)
{
    int succ = FALSE;

    if (!win) {
        gli_strict_warning(L"gli_window_set_stylehints: invalid ref");
        return;
    }
    // it looks like a waste of good code, but we're avoid derefing the pointer
    if ((glui32)win == STYLEHINT_TEXT_BUFFER) {
        win_textbuffer_set_stylehints(win, hints);
        succ = TRUE;
    } else if ((glui32)win == STYLEHINT_TEXT_GRID) {
        win_textgrid_set_stylehints(win, hints);        
        succ = TRUE;
    } else if (win->type == wintype_TextBuffer) {
        win_textbuffer_set_stylehints(win, hints);
        succ = TRUE;
    } else if (win->type == wintype_TextGrid) {
        win_textgrid_set_stylehints(win, hints);        
        succ = TRUE;
    }
    has_stylehints = succ;
    return;
}

glui32 gli_window_style_distinguish(winid_t win, glui32 styl1, glui32 styl2)
{
    if (!win) {
        gli_strict_warning(L"glk_style_distinguish: invalid ref");
        return FALSE;
    }

    switch (win->type) {
        case wintype_TextBuffer:
            return win_textbuffer_style_distinguish(win, styl1, styl2);
        case wintype_TextGrid:
            return win_textgrid_style_distinguish(win, styl1, styl2);
        default:
            return FALSE;
    }
    return FALSE;
}

void glk_game_loaded() {
    iosif_glk_game_loaded();
}
