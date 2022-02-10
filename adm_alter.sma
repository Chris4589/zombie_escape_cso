#include <admin_panel>

/*
	native get_roleUser(id, dest[], len);
*/

var const authUser[] = "admin"; //cambiar
var const authPassword[] = "obidiotapia"; //cambiar

var const urlBase[] = "https://admin.svlmexico.com";

var const kickReason[] = "Contraseña Invalida!";

var authToken[400], idServer;

var bool:authLoged;

var Trie:trieVencimiento, Trie:trieRole;

var fechaVencimiento[33][32], roleUser[33][32];

function plugin_end() {
    TrieDestroy(trieVencimiento);
    TrieDestroy(trieRole);
}

function accessUser(id)
{
	remove_user_flags(id);

	var userAuthid[32], userName[32], userPassword[50], index = -1;

	get_user_authid(id, userAuthid, charsmax(userAuthid));
	get_user_name(id, userName, charsmax(userName));
	get_user_info(id, "_pw", userPassword, charsmax(userPassword));

	static flags;
	static authid[44];
	static access;
	static password[32];
	static role[32];
	static vencimiento[32];

	for(var i = 0; i < admins_num(); i++)
	{
		flags = admins_lookup(i, AdminProp_Flags);

 		admins_lookup(i, AdminProp_Auth, authid, charsmax(authid));

 		if (flags & FLAG_AUTHID) {
 			if (equal(authid, userAuthid)) {

 				if (TrieGetString(trieRole, userAuthid, role, charsmax(role))) {
 					copy(roleUser[id], charsmax(roleUser[]), role);
				}

				if (TrieGetString(trieVencimiento, userAuthid, vencimiento, charsmax(vencimiento))) {
 					copy(fechaVencimiento[id], charsmax(fechaVencimiento[]), vencimiento);
				}

 				index = i;
 				break;
 			}
 		}
 		else if (flags & FLAG_TAG) {
 			if (equal(authid, userName)) {

 				if (TrieGetString(trieRole, userName, role, charsmax(role))) {
 					copy(roleUser[id], charsmax(roleUser[]), role);
				}

				if (TrieGetString(trieVencimiento, userName, vencimiento, charsmax(vencimiento))) {
 					copy(fechaVencimiento[id], charsmax(fechaVencimiento[]), vencimiento);
				}

 				index = i;
 				break;
 			}
 		}
	}

	if (index != -1) {
		access = admins_lookup(index, AdminProp_Access);

		var userFlags[32];
 		get_flags(access, userFlags, charsmax(userFlags));

		server_print("[gRIP] flags: %s", userFlags);
		server_print("[gRIP] role: %s", roleUser[id]);
		server_print("[gRIP] vencimiento: %s", fechaVencimiento[id]);

	 	if (flags & FLAG_NOPASS) {
			set_user_flags(id, read_flags(userFlags));

			server_print("[gRIP] Admin: %s", userName);
		} else {
			admins_lookup(index, AdminProp_Password, password, charsmax(password));

			if (equal(password, userPassword)) {
				set_user_flags(id, read_flags(userFlags));
				server_print("[gRIP] Admin Pass: %s", userName);
			} else {
				if (flags & FLAG_KICK) {
					server_print("[gRIP] Kick: %s", userName);
					server_cmd("kick #%i ^"(%s)^"", get_user_userid(id), kickReason);
					return PLUGIN_HANDLED;
				}
			}
		}
		
	} else {
		server_print("[gRIP] User: %s", userName);
		set_user_flags(id, read_flags("z"));
	}

	return PLUGIN_CONTINUE;
} 

/*
function client_authorized(id) {
	return accessUser(id);
}
*/
function give_admins() {
	var GripResponseState:responseState = grip_get_response_state();
	if (responseState != GripResponseStateSuccessful) {
		server_print("Response Status Failed: [ %d ]", responseState);
		return;
	}

	var GripHTTPStatus:status = grip_get_response_status_code();

	if (!(GripHTTPStatusOk <= status <= GripHTTPStatusPartialContent)) {
		server_print("Code Status [ %d ]", status);
		return;
	}

	var responses[1024];
	var GripJSONValue:body = grip_json_parse_response_body(responses, charsmax(responses));

	if (body == Invalid_GripJSONValue) {
		server_print("La respuesta esperada no es un JSON: %s", responses);
		return;
	}

	if (isError(body)) {
		server_print("Hubo un error en la peticion a node.");
		return;
	}

	var GripJSONValue:msg = grip_json_object_get_value(body, "msg");

	if (!isArrayValid(msg)) {
		server_print("No hay admins creados");
		return;
	}

	var role[32], authid[32], flags[32], createdAt[50], password[50], vencimiento[50], bool:is_steam;

	for(var i = 0; i < grip_json_array_get_count(msg); i++)
	{
		var GripJSONValue:value = grip_json_array_get_value(msg, i);
		grip_json_object_get_string(value, "role", role, charsmax(role));
		grip_json_object_get_string(value, "authid", authid, charsmax(authid));
		grip_json_object_get_string(value, "password", password, charsmax(password));
		grip_json_object_get_string(value, "flags", flags, charsmax(flags));
		grip_json_object_get_string(value, "createdAt", createdAt, charsmax(createdAt));
		grip_json_object_get_string(value, "vencimiento", vencimiento, charsmax(vencimiento));

		is_steam = grip_json_object_get_bool(value, "steam");

		admins_push(authid, password, read_flags(flags), read_flags( is_steam ? "ce" : "ab"));

		TrieSetString(trieVencimiento, authid, vencimiento);
		TrieSetString(trieRole, authid, role);

		server_print("/*******************************************/");
		server_print("Admin cargado.");
		server_print("role: [ %s ]", role);
		server_print("authid: [ %s ]", authid);
		server_print("flags: [ %s ]", flags);
		server_print("type: [ %s ]", is_steam ? "ce" : "ab");
		server_print("createdAt: [ %s ]", createdAt);
		server_print("/*******************************************/");
		
		grip_destroy_json_value(value);
	}

	grip_destroy_json_value(msg);
	grip_destroy_json_value(body);
}

function getAllAdmins() {
	if (!authLoged) {
		server_print("No te haz logueado a tu cuenta en %s.", urlBase);
		return;
	}

	var url[200];
	formatex(url, charsmax(url), "%s/admins/?fk_ServerId=%d", urlBase, idServer);

	var GripRequestOptions:options = grip_create_default_options();
	grip_options_add_header(options, "Content-Type", "application/json");
	grip_options_add_header(options, "token", authToken);

	grip_request(url, Empty_GripBody, GripRequestTypeGet, "give_admins", options);

	grip_destroy_options(options);
}

function handlerAuth() {
	var GripHTTPStatus:status = grip_get_response_status_code();

	if (!(GripHTTPStatusOk <= status <= GripHTTPStatusPartialContent)) {
		server_print("Code Status [ %d ]", status);
		return;
	}

	var responses[1024];
	var GripJSONValue:body = grip_json_parse_response_body(responses, charsmax(responses));

	if (body == Invalid_GripJSONValue) {
		server_print("La respuesta esperada no es un JSON: %s", responses);
		return;
	}

	if (isError(body)) {
		server_print("Hubo un error en la peticion a node.");
		return;
	}

	var GripJSONValue:msg = grip_json_object_get_value(body, "msg");

	if (msg == Invalid_GripJSONValue) {
		server_print("La respuesta de msg no es un JSON");
		return;
	}

	grip_json_object_get_string(msg, "token", authToken, charsmax(authToken));
	server_print("your server token is [ %s ]", authToken);

	if (!authLoged) {
		getServer();
	}
	authLoged = true;

	grip_destroy_json_value(msg);
	grip_destroy_json_value(body);
}

function renew_token() {

	if (!authLoged) {
		server_print("No te haz logueado a tu cuenta en %s.", urlBase);
		return;
	}
	
	var url[200];
	formatex(url, charsmax(url), "%s/auth/renew/", urlBase);

	var GripRequestOptions:options = grip_create_default_options();
	grip_options_add_header(options, "Content-Type", "application/json");
	grip_options_add_header(options, "token", authToken);

	grip_request(url, Empty_GripBody, GripRequestTypeGet, "handlerAuth", options);

	grip_destroy_options(options);
}

function auth() {
	var url[200];
	formatex(url, charsmax(url), "%s/auth/", urlBase);
	server_print("%s", url);

	var GripJSONValue:object = grip_json_init_object();
	grip_json_object_set_string(object, "user", authUser);
	grip_json_object_set_string(object, "password", authPassword);

	var GripBody:body = object != Invalid_GripJSONValue ? grip_body_from_json(object) : Empty_GripBody;

	var GripRequestOptions:options = grip_create_default_options();
	grip_options_add_header(options, "Content-Type", "application/json");
	grip_options_add_header(options, "User-Agent", "Grip");

	grip_request(url, body, GripRequestTypePost, "handlerAuth", options);

	grip_destroy_body(body);
	grip_destroy_options(options);
	grip_destroy_json_value(object);
}


function client_putinserver(id) {
	roleUser[id][0] = EOS;

	return accessUser(id);
}

function handlerServer() {
	var GripHTTPStatus:status = grip_get_response_status_code();

	if (!(GripHTTPStatusOk <= status <= GripHTTPStatusPartialContent)) {
		server_print("Code Status [ %d ]", status);
		return;
	}

	var responses[1024];
	var GripJSONValue:body = grip_json_parse_response_body(responses, charsmax(responses));

	if (body == Invalid_GripJSONValue) {
		server_print("La respuesta esperada no es un JSON: %s", responses);
		return;
	}

	if (isError(body)) {
		server_print("Hubo un error en la peticion a node.");
		return;
	}

	var GripJSONValue:msg = grip_json_object_get_value(body, "msg");

	if (msg == Invalid_GripJSONValue) {
		server_print("La respuesta de msg no es un JSON");
		return;
	}

	idServer = grip_json_object_get_number(msg, "id");
	server_print("your server id is [ %d ]", idServer);

	grip_destroy_json_value(msg);
	grip_destroy_json_value(body);

	getAllAdmins();
}

function getServer() {
	var url[200], address[50];
	get_cvar_string("net_address", address, charsmax(address));
	formatex(url, charsmax(url), "%s/servers/Ip?ipServer=%s", urlBase, address);
	server_print("%s", url);

	var GripRequestOptions:options = grip_create_default_options();
	grip_options_add_header(options, "Content-Type", "application/json");
	grip_options_add_header(options, "token", authToken);

	grip_request(url, Empty_GripBody, GripRequestTypeGet, "handlerServer", options);

	grip_destroy_options(options);
}

function OnStart() {
	admin_init(param1, param2, param3);

	trieVencimiento = TrieCreate( );
	trieRole = TrieCreate( );

	authLoged = false;

	auth();
	set_task(120.0, "renew_token", _, _, _, "d");
}


function CreateNatives() {
	register_native("get_roleUser", "handler_roleUser", 0);// get_roleUser(id, dest[], len);
}

public handler_roleUser(plugin, params)
{
	set_string(2, roleUser[get_param(1)], get_param(3));
	return -1;
}