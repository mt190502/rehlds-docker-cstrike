#include <amxmodx>
#include <fakemeta>

#pragma semicolon 1

#define USE_CHECK_VISIBLE_ENT // «акомментируйте эту строку, если не хотите использовать проверку видимости игрока перед отображением урона

#if !defined USE_CHECK_VISIBLE_ENT
	#define CONSIDER_MEAT_MAPS // «акомментируйте эту строку, если не хотите принудительно активировать проверку видимости игрока на "м€сных" картах
	
	new bool:g_bMeatMap;
#endif

new g_pHudSyncObj1;
new g_pHudSyncObj2;

public plugin_init()
{
	register_plugin("Damager", "0.1b", "Subb98");
	register_event("Damage", "EventDamage", "b", "2!0", "3=0", "4!0");
	g_pHudSyncObj1 = CreateHudSyncObj();
	g_pHudSyncObj2 = CreateHudSyncObj();
}

#if defined CONSIDER_MEAT_MAPS
public plugin_cfg()
{
	new const szMapTypes[][] = {"aim_", "awp_", "fy_"}; // “ипы карт, которые будут считатьс€ "м€сными" (по умолчанию "aim_", "awp_", "fy_")
	new szMapname[32];
	get_mapname(szMapname, charsmax(szMapname));
	for(new i; i < sizeof szMapTypes; i++)
	{
		if(equali(szMapname, szMapTypes[i], strlen(szMapTypes[i])))
		{
			g_bMeatMap = true;
			break;
		}
	}
}
#endif

public EventDamage(const id)
{
	static pAttacker, iDamage;
	pAttacker = get_user_attacker(id), iDamage = read_data(2);
	#if defined USE_CHECK_VISIBLE_ENT
	if(is_user_connected(pAttacker) && pAttacker != id && fm_is_ent_visible(pAttacker, id))
	#else
	if(is_user_connected(pAttacker) && pAttacker != id && g_bMeatMap ? fm_is_ent_visible(pAttacker, id) : 1>0)
	#endif
	{
		set_hudmessage(0, _, 200, _, 0.55, _, _, 1.0, _, 0.0, -1);
		ShowSyncHudMsg(pAttacker, g_pHudSyncObj1, "%d", iDamage);
	}
	if(is_user_connected(id))
	{
		set_hudmessage(255, 0, _, 0.45, -1.0, _, _, 1.0, _, 0.0, -1);
		ShowSyncHudMsg(id, g_pHudSyncObj2, "%s%d", id == pAttacker ? "-" : "", iDamage);
	}
}

// Thanks to ConnorMcLeod (https://forums.alliedmods.net/showpost.php?p=1580992&postcount=10)
stock bool:fm_is_ent_visible(const id, const pEnt, const bool:bIgnoreMonsters = false)
{
	new Float:fStart[3], Float:fDestination[3], Float:fFraction;
	pev(id, pev_origin, fStart);
	pev(id, pev_view_ofs, fDestination);
	fStart[0] += fDestination[0];
	fStart[1] += fDestination[1];
	fStart[2] += fDestination[2];
	pev(pEnt, pev_origin, fDestination);
	engfunc(EngFunc_TraceLine, fStart, fDestination, bIgnoreMonsters, id, 0);
	get_tr2(0, TR_flFraction, fFraction);
	if(fFraction > 0.97)
	{
		return true;
	}
	return false;
}