#include <amxmisc>
#include <hamsandwich>
#include <engine>

public plugin_init() {
	RegisterHam(Ham_Use, "*", "fw_HamUse_Pre", true);
}

public fw_HamUse_Pre(iButton, id) {
	if (!is_valid_ent(iButton)) {
		return;
	}
	new class[50], target[50];

	entity_get_string(iButton, EV_SZ_classname, class, charsmax(class));
	entity_get_string(iButton, EV_SZ_targetname, target, charsmax(target));
	console_print(id, "classname %s - targetname %s", class, target);
}