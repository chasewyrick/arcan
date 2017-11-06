/*
 * NOTES:
 *  Missing/investigate -
 *   a. Should pointer event coordinates be clamped against surface?
 *   b. We need to track surface rotate state and transform coordinates
 *      accordingly, as there's no 'rotate state' in arcan
 *   c. Also have grabstate to consider (can only become a MESSAGE and
 *      wl-specific code in the lua layer)
 *   d. scroll- wheel are in some float- version, so we need to deal
 *      with subid 3,4 for analog events and subid 3 for digital
 *      events (there's also something with AXIS_SOURCE, ...)
 *   e. it seems like we're supposed to keep a list of all pointer
 *      resources and iterate them.
 *
 *  Touch - not used at all right now
 */
static void update_mxy(struct comp_surf* cl, unsigned long long pts)
{
	if (!cl->client->pointer)
		return;

	trace(TRACE_ANALOG, "mouse@%d,%d", cl->acc_x, cl->acc_y);
	if (cl->client->last_cursor != cl->res){
		if (cl->client->last_cursor){
			trace(TRACE_DIGITAL,
				"leave: %"PRIxPTR, (uintptr_t)cl->client->last_cursor);
			wl_pointer_send_leave(
				cl->client->pointer, STEP_SERIAL(), cl->client->last_cursor);
		}

		trace(TRACE_DIGITAL, "enter: %"PRIxPTR, (uintptr_t)cl->res);
		cl->client->last_cursor = cl->res;

		wl_pointer_send_enter(cl->client->pointer,
			STEP_SERIAL(), cl->res,
			wl_fixed_from_int(cl->acc_x),
			wl_fixed_from_int(cl->acc_y)
		);
	}
	else
		wl_pointer_send_motion(cl->client->pointer, pts,
			wl_fixed_from_int(cl->acc_x), wl_fixed_from_int(cl->acc_y));

	if (wl_resource_get_version(cl->client->pointer) >=
		WL_POINTER_FRAME_SINCE_VERSION){
		wl_pointer_send_frame(cl->client->pointer);
	}
}

static void get_keyboard_states(struct wl_array* dst)
{
	wl_array_init(dst);
/* FIXME: track press/release so we can send the right ones */
}

static void update_mbtn(struct comp_surf* cl,
	unsigned long long pts, int ind, bool active)
{
	trace(TRACE_DIGITAL,
		"mouse-btn(ind: %d:%d, @%d,%d)", ind,(int) active, cl->acc_x, cl->acc_y);

/* 0x110 == BTN_LEFT in evdev parlerance, ignore 0 index as it is used
 * to convey gestures and that's a separate unstable protocol */
	if (ind > 0)
		wl_pointer_send_button(cl->client->pointer, STEP_SERIAL(),
			pts, 0x10f + ind, active ?
			WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED
		);
}

static void update_kbd(struct comp_surf* cl, arcan_ioevent* ev)
{
	if (!cl->client->keyboard)
		return;

	trace(TRACE_DIGITAL,
		"button (%d:%d)", (int)ev->subid, (int)ev->input.translated.scancode);

/* keyboard not acknowledged on this surface?
 * send focus and possibly leave on previous one */
	if (cl->client->last_kbd != cl->res){
		if (cl->client->last_kbd){
			trace(TRACE_DIGITAL,
				"leave: %"PRIxPTR, (uintptr_t) cl->client->last_kbd);
			wl_keyboard_send_leave(
				cl->client->keyboard, STEP_SERIAL(), cl->client->last_kbd);
		}

		trace(TRACE_DIGITAL, "enter: %"PRIxPTR, (uintptr_t) cl->res);
		cl->client->last_kbd = cl->res;
		struct wl_array states;
		get_keyboard_states(&states);
			wl_keyboard_send_enter(
				cl->client->keyboard, STEP_SERIAL(), cl->res, &states);
		wl_array_release(&states);
	}

/* This is, politely put, batshit insane - every time the modifier mask has
 * changed from the last time we were here, we either have to allocate and
 * rebuild a new xkb_state as the structure is opaque, and they provide no
 * reset function - then rebuild it by converting our modifier mask back to
 * linux keycodes and reinsert them into the state machine but that may not
 * work for each little overcomplicated keymap around. The other option,
 * is that each wayland seat gets its own little state-machine that breaks
 * every input feature we have server-side.
 * The other panic option is to fake/guess/estimate the different modifiers
 * and translate that way.
 */
	struct xkb_state* state = cl->client->kbd_state.state;
	xkb_state_update_key(state,
		ev->subid + 8, ev->input.translated.active ? XKB_KEY_DOWN : XKB_KEY_UP);
	uint32_t depressed = xkb_state_serialize_mods(state,XKB_STATE_MODS_DEPRESSED);
	uint32_t latched = xkb_state_serialize_mods(state, XKB_STATE_MODS_LATCHED);
	uint32_t locked = xkb_state_serialize_mods(state, XKB_STATE_MODS_LOCKED);
	uint32_t group = xkb_state_serialize_mods(state, XKB_STATE_MODS_EFFECTIVE);
	wl_keyboard_send_modifiers(cl->client->keyboard,
		STEP_SERIAL(), depressed, latched, locked, group);
	wl_keyboard_send_key(cl->client->keyboard,
		STEP_SERIAL(),
		ev->pts,
		ev->subid,
		ev->input.translated.active /* WL_KEYBOARD_KEY_STATE_PRESSED == 1*/
	);
}

static bool relative_sample(struct wl_resource* res, uint64_t ts, int x, int y)
{
	if (!res)
		return false;

	uint32_t lo = (ts * 1000) >> 32;
	uint32_t hi = ts * 1000;
	zwp_relative_pointer_v1_send_relative_motion(res, hi, lo, x, y, x, y);
	return true;
}

static void translate_input(struct comp_surf* cl, arcan_ioevent* ev)
{
	if (ev->devkind == EVENT_IDEVKIND_TOUCHDISP){
		trace(TRACE_ANALOG, "touch");
	}
/* motion would/should always come before digital */
	else if (ev->devkind == EVENT_IDEVKIND_MOUSE && cl->client->pointer){
		if (ev->datatype == EVENT_IDATATYPE_DIGITAL){
			update_mbtn(cl, ev->pts, ev->subid, ev->input.digital.active);
		}
		else if (ev->datatype == EVENT_IDATATYPE_ANALOG){
/* both samples */
			if (ev->subid == 2){
				if (ev->input.analog.gotrel){
					cl->acc_x += ev->input.analog.axisval[0];
					cl->acc_y += ev->input.analog.axisval[2];
					if (relative_sample(cl->client->got_relative,
						ev->pts, ev->input.analog.axisval[0], ev->input.analog.axisval[1]))
						return;
				}
				else{
					cl->acc_x = ev->input.analog.axisval[0];
					cl->acc_y = ev->input.analog.axisval[2];
				}
				update_mxy(cl, ev->pts);
			}
/* one sample at a time, we need history - either this will introduce
 * small or variable script defined latencies and require an event lookbehind
 * or double the sample load, go with the latter */
			else {
				if (ev->input.analog.gotrel){
					if (ev->subid == 0)
						cl->acc_x += ev->input.analog.axisval[0];
					else if (ev->subid == 1)
						cl->acc_y += ev->input.analog.axisval[0];
				}
				else {
					if (ev->subid == 0){
						cl->acc_x = ev->input.analog.axisval[0];
						if (relative_sample(cl->client->got_relative, ev->pts,
							ev->input.analog.axisval[0], 0))
							return;
					}
					else if (ev->subid == 1){
						cl->acc_y = ev->input.analog.axisval[0];
						if (relative_sample(cl->client->got_relative, ev->pts,
							0, ev->input.analog.axisval[0]))
							return;
					}
				}
				update_mxy(cl, ev->pts);
			}
		}
		else
			;
	}
	else if (ev->datatype ==
		EVENT_IDATATYPE_TRANSLATED && cl->client && cl->client->keyboard)
			update_kbd(cl, ev);
	else
		;
}

static void try_frame_callback(
	struct comp_surf* surf, struct arcan_shmif_cont* acon)
{
/* still synching? */
	if (!acon || acon->addr->vready){
		return;
	}

	for (size_t i = 0; i < COUNT_OF(surf->scratch) && surf->frames_pending; i++){
		if (surf->scratch[i].type == 1){
			surf->scratch[i].type = 0;
			wl_callback_send_done(surf->scratch[i].res, surf->scratch[i].id);
			wl_resource_destroy(surf->scratch[i].res);
			surf->scratch[i].res = NULL;
			surf->frames_pending--;
		}
	}

	trace(TRACE_SURF, "reply callback: %"PRIu32, surf->cb_id);
}

/*
 * update the state table for surf and return if it would result in visible
 * state change that should be propagated
 */
static bool displayhint_handler(struct comp_surf* surf, struct arcan_tgtevent* ev)
{
	struct surf_state states = {
		.drag_resize = !!(ev->ioevs[2].iv & 1),
		.hidden = !!(ev->ioevs[2].iv & 2),
		.unfocused = !!(ev->ioevs[2].iv & 4),
		.maximized = !!(ev->ioevs[2].iv & 8),
		.minimized = !!(ev->ioevs[2].iv & 16)
	};

	bool change = memcmp(&surf->states, &states, sizeof(struct surf_state)) != 0;
	surf->states = states;
	return change;
}

static void flush_surface_events(struct comp_surf* surf)
{
	struct arcan_event ev;
/* rcon is set as redirect-con when there's a shared connection or similar */
	struct arcan_shmif_cont* acon = surf->rcon ? surf->rcon : &surf->acon;

	while (arcan_shmif_poll(acon, &ev) > 0){
		if (surf->dispatch && surf->dispatch(surf, &ev))
			continue;

		if (ev.category == EVENT_IO){
			translate_input(surf, &ev.io);
			continue;
		}
		else if (ev.category != EVENT_TARGET)
			continue;

		switch(ev.tgt.kind){
/* translate to configure events */
		case TARGET_COMMAND_OUTPUTHINT:{
/* have we gotten reconfigured to a different display? */
		}
/* we might get a migrate reset induced by the client-bridge connection,
 * if so, update viewporting hints at least, and possibly active input-
 * etc. regions as well */
		case TARGET_COMMAND_RESET:{
			if (ev.tgt.ioevs[0].iv == 0){
				trace(TRACE_ALLOC, "surface-reset client rebuild test");
				rebuild_client(surf->client);
			}
		}
		case TARGET_COMMAND_STEPFRAME:
			try_frame_callback(surf, acon);
		break;

/* in the 'generic' case, there's litle we can do that match
 * 'EXIT' behavior. It's up to the shell-subprotocols to swallow
 * the event and map to the correct surface teardown. */
		case TARGET_COMMAND_EXIT:
		break;

		default:
		break;
		}
	}
}

static void flush_client_events(
	struct bridge_client* cl, struct arcan_event* evs, size_t nev)
{
/* same dispatch, different path if we're dealing with 'ev' or 'nev' */
	struct arcan_event ev;

	while (arcan_shmif_poll(&cl->acon, &ev) > 0){
		if (ev.category != EVENT_TARGET)
			continue;
		switch(ev.tgt.kind){
		case TARGET_COMMAND_EXIT:
			trace(TRACE_ALLOC, "shmif-> kill client");
/*		this just murders us, should possibly send some 'die' event
 *		wl_client_destroy(cl->client);
			trace("shmif-> kill client");
 */
		break;
		case TARGET_COMMAND_DISPLAYHINT:
			trace(TRACE_ALLOC, "shmif-> target update visibility or size");
			if (ev.tgt.ioevs[0].iv && ev.tgt.ioevs[1].iv){
			}
		break;

/*
 * destroy / re-request all surfaces tied to this client as the underlying
 * connection primitive might have been changed, when stable, this should only
 * need to be done for reset state 3 though, but it helps testing.
 */
		case TARGET_COMMAND_RESET:
			trace(TRACE_ALLOC, "reset-rebuild client");
			rebuild_client(cl);

/* in state 3, we also need to extract the descriptor and swap it out in the
 * pollset or we'll spin 100% */
		break;
		case TARGET_COMMAND_REQFAIL:
		break;
		case TARGET_COMMAND_NEWSEGMENT:
		break;

/* if selection status change, send wl_surface_
 * if type: wl_shell, send _send_configure */
		break;
		case TARGET_COMMAND_OUTPUTHINT:
		break;
		default:
		break;
		}
	}
}

static bool flush_bridge_events(struct arcan_shmif_cont* con)
{
	struct arcan_event ev;
	while (arcan_shmif_poll(con, &ev) > 0){
		if (ev.category == EVENT_TARGET){
		switch (ev.tgt.kind){
		case TARGET_COMMAND_EXIT:
			return false;
		default:
		break;
		}
		}
	}
	return true;
}
