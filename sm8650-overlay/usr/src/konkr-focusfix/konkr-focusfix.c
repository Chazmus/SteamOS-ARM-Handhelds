/*
 * konkr-focusfix — give games their controls back after the Steam overlay.
 *
 * Opening Quick Access / the Steam menu moves X focus to Steam's window;
 * closing it moves focus back to the game, but Proton's winex11 never
 * re-activates the game (no WM_TAKE_FOCUS), so games that ignore input while
 * inactive stay dead until a click (touchscreen) activates them.
 * This watches the X focus on gamescope's Xwayland and, whenever it returns
 * to the window gamescope has focused (a game, not Steam), repeats what a
 * window manager would do for a WM_TAKE_FOCUS client: send it WM_TAKE_FOCUS.
 *
 *   konkr-focusfix [:0]
 * Build: cc -O2 -o konkr-focusfix konkr-focusfix.c -lX11
 */
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define STEAM_APPID 769
/* At most one WM_TAKE_FOCUS per this many seconds: when focus bounces
 * between a game and Steam (GTA IV + Social Club opening Quick Access,
 * three bounces in 14 s), re-activating on every return can keep it going. */
#define MIN_INTERVAL_S 3

static double now(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

static unsigned long card(Display *d, Window w, Atom a)
{
	Atom t; int f; unsigned long n, r, v = 0; unsigned char *p = NULL;
	if (XGetWindowProperty(d, w, a, 0, 1, False, AnyPropertyType, &t, &f, &n, &r, &p) == Success
	    && p && n && f == 32)
		v = *(unsigned long *)p;
	if (p)
		XFree(p);
	return v;
}

static int ignore_errors(Display *d, XErrorEvent *e) { (void)d; (void)e; return 0; }

int main(int argc, char **argv)
{
	const char *name = argc > 1 ? argv[1] : NULL;
	Display *d;
	while (!(d = XOpenDisplay(name)))
		sleep(2);
	XSetErrorHandler(ignore_errors);   /* game windows come and go */
	Window root = DefaultRootWindow(d);
	Atom gs_win = XInternAtom(d, "GAMESCOPE_FOCUSED_WINDOW", False);
	Atom gs_app = XInternAtom(d, "GAMESCOPE_FOCUSED_APP", False);
	Atom proto = XInternAtom(d, "WM_PROTOCOLS", False);
	Atom take = XInternAtom(d, "WM_TAKE_FOCUS", False);
	Window last = None;
	double sent_at = -MIN_INTERVAL_S;

	for (;;) {
		usleep(250 * 1000);
		Window focus; int rev;
		XGetInputFocus(d, &focus, &rev);
		Window game = card(d, root, gs_win);
		unsigned long app = card(d, root, gs_app);
		if (game && focus == game && last != game && last != None
		    && app && app != STEAM_APPID && now() - sent_at >= MIN_INTERVAL_S) {
			usleep(100 * 1000);   /* let Steam finish handing focus back */
			/* Steam may have taken focus again meanwhile (Quick Access
			 * opening): then leave it alone. */
			XGetInputFocus(d, &focus, &rev);
			if (focus != game || card(d, root, gs_win) != game) {
				last = focus;
				continue;
			}
			sent_at = now();
			/* WM_TAKE_FOCUS only: Wine then activates the window and sets X focus
			 * itself. Also forcing XSetInputFocus + _NET_ACTIVE_WINDOW made Wine
			 * re-grab/warp the pointer -> endless camera spin in Dying Light. */
			XEvent e = { 0 };
			e.xclient.type = ClientMessage;
			e.xclient.window = game;
			e.xclient.message_type = proto;
			e.xclient.format = 32;
			e.xclient.data.l[0] = take;
			e.xclient.data.l[1] = CurrentTime;
			XSendEvent(d, game, False, NoEventMask, &e);
			XFlush(d);
			fprintf(stderr, "konkr-focusfix: re-activated 0x%lx (app %lu)\n", game, app);
		}
		last = focus;
	}
}
