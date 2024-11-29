#include <amxmodx>
#include <reapi>
#include <fakemeta>

new g_msgSyncHudAttacker;
new g_msgSyncHudLocal;

public plugin_init()
{
	register_plugin("Hasarci", "1.0", "qetelbeyza");

	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Post", true);

	g_msgSyncHudAttacker  = CreateHudSyncObj(); // HUD'da göstermesi gerek!
	g_msgSyncHudLocal  = CreateHudSyncObj();
}

stock bool:IsVictimVisible(attacker, victim)
{
	new ptr = create_tr2();
	new Float:fStart[3], Float:fDestination[3];

	pev(attacker, pev_origin, fStart);
	pev(attacker, pev_view_ofs, fDestination);

	fStart[0] += fDestination[0];
	fStart[1] += fDestination[1];
	fStart[2] += fDestination[2];

	pev(victim, pev_origin, fDestination);

	engfunc(EngFunc_TraceLine, fStart, fDestination, IGNORE_MONSTERS, victim, ptr); // ignoremonsters is evil!

	new Float:fraction;
	get_tr2(ptr, TR_flFraction, fraction);

	free_tr2(ptr);

	if (fraction == 1.0)
		return true; // Gözüm başım üstüne
	else
		return false; // Bişi var
}

public CBasePlayer_TakeDamage_Post(const id, pevInflictor, attacker, Float:flDamage)
{
	if(!(1 <= attacker <= MaxClients) || !(1 <= id <= MaxClients) || flDamage < 1.0 || !rg_is_player_can_takedamage(id, attacker)) // hasar ve istemci numarası
		return;

	if (!is_user_connected(id) || !is_user_connected(attacker)) // var mı?
		return;

	if(IsVictimVisible(attacker, id))
	{
		set_hudmessage(.red = 0, .green = 100, .blue = 200, .x = -1.0, .y = 0.55, .holdtime = 2.0, .channel = -1);
		ShowSyncHudMsg(attacker, g_msgSyncHudAttacker, "%.0f^n", flDamage);
	}

	set_hudmessage(.red = 255, .green = 0, .blue = 0, .x = 0.45, .y = 0.50, .holdtime = 2.0, .channel = -1);
	ShowSyncHudMsg(id, g_msgSyncHudLocal, "%.0f^n", flDamage);

	// spec'in görebilmesi gerek!
	static i, players[32], pnum, specid, iuser2;
	get_players(players, pnum, "bch");
	for(i = 0; i < pnum; i++)
	{
		specid = players[i];
		iuser2 = get_entvar(specid, var_iuser2);
		// buraya duvar kontrolü yapılmasına gerek yok, ölüler konuşamaz!
		if(iuser2 == attacker) // iuser2 izlenen oyuncunun ID'si!
		{
			set_hudmessage(.red = 0, .green = 100, .blue = 200, .x = -1.0, .y = 0.55, .holdtime = 2.0, .channel = -1);
			ShowSyncHudMsg(specid, g_msgSyncHudAttacker, "%.0f^n", flDamage);
		}
		else if(iuser2 == id)
		{
			set_hudmessage(.red = 255, .green = 0, .blue = 0, .x = 0.45, .y = 0.50, .holdtime = 2.0, .channel = -1);
			ShowSyncHudMsg(specid, g_msgSyncHudLocal, "%.0f^n", flDamage);
		}
	}
}
