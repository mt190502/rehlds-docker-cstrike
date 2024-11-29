#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

new pcvar_Display

public plugin_init()
{
	register_plugin("Reset Score", "1.0", "Silenttt")
	
	register_clcmd("say /resetscore", "reset_score")
	register_clcmd("say /restartscore", "reset_score")
	register_clcmd("say /rs", "reset_score")

	pcvar_Display = register_cvar("sv_rsdisplay", "1")
}

public reset_score(id)
{
	cs_set_user_deaths(id, 0)
	set_user_frags(id, 0)

	cs_set_user_deaths(id, 0)
	set_user_frags(id, 0)
	
	if(get_pcvar_num(pcvar_Display) == 1)
	{
		new name[33]
		get_user_name(id, name, 32)
		client_print(0, print_chat, "%s has just reset his score", name)
	}
	else
	{
		client_print(id, print_chat, "You have just reset your score")
	}

	return PLUGIN_HANDLED
}
