#ifndef LUASOCKET_API
#ifdef _WIN32
#define LUASOCKET_API __declspec(dllexport)
#else
#define LUASOCKET_API __attribute__ ((visibility ("default")))
#endif
#endif

#include <libwebsockets.h>
#include <string.h>
#include <signal.h>

#include "lua.h"
#include "lauxlib.h"

#define LWS_PLUGIN_STATIC
#include "protocol_keyhunter.c"

#define KEYHUNTER_VERSION "KH 0.0.1"

static struct lws_protocols protocols[] = {
	LWS_PLUGIN_PROTOCOL_KEYHUNTER,
	{ NULL, NULL, 0, 0 }
};

static int interrupted, options;
static struct lws_context *context;

/* pass pointers to shared vars to the protocol */

static const struct lws_protocol_vhost_options pvo_options = {
	NULL,
	NULL,
	"options",		/* pvo name */
	(void *)&options	/* pvo value */
};

static const struct lws_protocol_vhost_options pvo_interrupted = {
	&pvo_options,
	NULL,
	"interrupted",		/* pvo name */
	(void *)&interrupted	/* pvo value */
};

static const struct lws_protocol_vhost_options pvo = {
	NULL,				/* "next" pvo linked-list */
	&pvo_interrupted,		/* "child" pvo linked-list */
	"lws-keyhunter",	/* protocol name we belong to on this vhost */
	""				/* ignored */
};
static const struct lws_extension extensions[] = {
	{
		"permessage-deflate",
		lws_extension_callback_pm_deflate,
		"permessage-deflate"
		 "; client_no_context_takeover"
		 "; client_max_window_bits"
	},
	{ NULL, NULL, NULL /* terminator */ }
};

void sigint_handler(int sig)
{
	interrupted = 1;
}


void testA() {
	printf("TESTA\n");
}

void startServer(int port) {
	struct lws_context_creation_info info;
	memset(&info, 0, sizeof info); /* otherwise uninitialized garbage */
	info.port = port;
	info.protocols = protocols;
	info.pvo = &pvo;
	info.pt_serv_buf_size = 32 * 1024;
	info.options = LWS_SERVER_OPTION_VALIDATE_UTF8;
	//info.options |= LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT;
	//info.ssl_cert_filepath = "localhost-100y.cert";
	//info.ssl_private_key_filepath = "localhost-100y.key";

	context = lws_create_context(&info);
	return;
}

int step() {
	int n;
	if (!interrupted && context) {
		//lwsl_user("looping...\n");
		if (__testfunc) {
			//lwsl_user("DEFINED!...\n");
			//(*__testfunc)();
		}
		n = lws_service(context, -1);
	}

	if (n < 0) {
		lws_context_destroy(context);

		lwsl_user("Completed %s\n", interrupted == 2 ? "OK" : "failed");

		return interrupted != 2;
	} else {
		return 0;
	}
}

void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
  luaL_checkstack(L, nup+1, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    lua_pushstring(L, l->name);
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -(nup+1));
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_settable(L, -(nup + 3));
  }
  lua_pop(L, nup);  /* remove upvalues */
}



void lua_void(lua_State *L) {
	printf("VOID");
}

void lua_startServer(lua_State *L) {
	if (lua_gettop(L) != 1) {
		luaL_error(L, "expecting port as argument");
	}
	
	int port = lua_tointeger(L, 1);
	if (port <= 0) {
		luaL_error(L, "expecting valid port number as argument");
	}

	startServer(port);
	if (context) lua_prints(L, "successfully started server.");
}

void lua_step(lua_State *L) {
	_L = L;
	int error = step();

	//flush
	while(lua_gettop(L) > 0) lua_pop(_L, 1);
	if (error) {
		lua_prints(L, "error:");
		lua_printi(L, error);
	}
}

/*
void lua_send(lua_State *L) {
	struct msg amsg;
	
	amsg.first = lws_is_first_fragment(wsi);
	amsg.final = lws_is_final_fragment(wsi);
	amsg.binary = lws_frame_is_binary(wsi);
	n = (int)lws_ring_get_count_free_elements(pss->ring);
	if (!n) {
		lwsl_user("dropping!\n");
		break;
	}

	if (amsg.final) pss->msglen = 0;
	else            pss->msglen += len;

	amsg.len = len;
	// notice we over-allocate by LWS_PRE
	amsg.payload = malloc(LWS_PRE + len);
	if (!amsg.payload) {
		lwsl_user("OOM: dropping\n");
		break;
	}

	printf("got msg:\n");
	printf("%.*s\n", len, in);

	memcpy((char *)amsg.payload + LWS_PRE, in, len);
	if (!lws_ring_insert(pss->ring, &amsg, 1)) {
		__keyhunter_destroy_message(&amsg);
		lwsl_user("dropping!\n");
		break;
	}
	lws_callback_on_writable(wsi);

	if (n < 3 && !pss->flow_controlled) {
		pss->flow_controlled = 1;
		lws_rx_flow_control(wsi, 0);
	}
}
*/



static const luaL_Reg mod[] = {
	{NULL, NULL}
};

static luaL_Reg func[] = {
	{"testA", lua_void},
	{"testB", lua_void},
	{"startServer", lua_startServer},
	{"step", lua_step},
	{NULL, NULL}
};





int main(int argc, const char **argv) {
	const char *p;
	int logs = LLL_USER | LLL_ERR | LLL_WARN | LLL_NOTICE;
	int port = 7681;

	signal(SIGINT, sigint_handler);

	lws_set_log_level(logs, NULL);
	lwsl_user("LWS Keyhunter + permessage-deflate + multifragment bulk message\n");
	lwsl_user("   lws-Keyhunter [-p port]\n");


	if ((p = lws_cmdline_option(argc, argv, "-p")))
		port = atoi(p);

	startServer(port);

	if (!context) {
		lwsl_err("lws init failed\n");
		return 1;
	}

	__testfunc = &testA;

	while (1) {
		step(context);
	}

	return 0;
}







static int base_open(lua_State *L) {
	lua_prints(L, "LOADING LIB :D");

	/* export functions (and leave namespace table on top of stack) */
	lua_newtable(L);
	luaL_setfuncs(L, func, 0);
	/* make version string available to scripts */
	lua_pushstring(L, "_VERSION");
	lua_pushstring(L, KEYHUNTER_VERSION);
	lua_rawset(L, -3);
	return 1;
}


LUASOCKET_API int luaopen_keyhunter_core(lua_State *L) {
	int i;
	base_open(L);
	for (i = 0; mod[i].name; i++) mod[i].func(L);
	return 1;
}