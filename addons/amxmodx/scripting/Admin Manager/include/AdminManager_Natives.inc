#if defined _AdminManager_Natives_included
	#endinput
#endif
#define _AdminManager_Natives_included

// Devuelve si es administrador o no
native bool:am_is_admin(id)

// Devuelve si el administrador está suspendido/castigado o no
native bool:am_is_punished(id)

// Devuelve el tipo de administrador del mismo
native am_get_type(id, output[], len)