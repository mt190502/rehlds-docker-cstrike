#include <amxmod>
#include <fun>
#include <vexdum>
#include <reapi>

new const PLUGIN_NAME[] = "[ReAPI] Advanced Kill Assists"

new const g_iVersionRequired_RH[2]   = {1, 3}
new const g_iVersionRequired_RGCS[2] = {5, 21}

#define NAMES_LENGTH      29
#define is_user_valid(%1) (1 <= %1 <= g_iMaxClients)

/*enum {
	CSSTATSX,
	ADVANCED
}*/

enum _:CVARS_DATA {
	CVAR_DAMAGE,
	CVAR_FRAG,
	CVAR_MONEY,
}

new g_pCVars[CVARS_DATA]
new g_pCVar_MPFriendlyFire, g_pCVar_MPFreeForAll 
/*#if ASSIST_ALGORITHM == CSSTATSX
new g_pCVar_AssistHp
#endif*/
new g_iMaxClients

new g_pAMXHook_SV_WriteFullClUPD, g_pAMXHook_CBP_Killed_Post2

new g_ePlayerData_DMGON[33][33]
new Float:g_ePlayerData_DMGONTIME[33][33]
new g_ePlayerData_NAME[33][32]
new g_szDeathString[32], g_iAssistAttackerID
new g_iOldClientHealth

public plugin_init() {
	register_plugin(PLUGIN_NAME, "2.0.1", "Xelson")

	switch(ReAPI_BF_HasBinaryRunning(ReAPI_BT_ReHLDS, true, g_iVersionRequired_RH[0], g_iVersionRequired_RH[1], true, true)) {
		case ReAPI_HBRRT_NoReBinary: {
			log_amx("[%s] Unable to use the plugin, the %s's API is unavailable (the %s game binary is probably not running).", PLUGIN_NAME, "ReHLDS", "ReHLDS")
			//pause("ae")
			return
		}
		case ReAPI_HBRRT_InternalCheckFailed: {
			log_amx("[%s] Unable to use the plugin, the %s's API version is different than the one required internally by the module.", PLUGIN_NAME, "ReHLDS")
			//pause("ae")
			return
		}
		case ReAPI_HBRRT_ExternalCheckFailed: {
			new iMajorVersion = -1, iMinorVersion = -1
			ReAPI_BF_GetBinaryInformations(ReAPI_BT_ReGameDLL_CS, iMajorVersion, iMinorVersion)
			log_amx("[%s] Unable to use the plugin, the %s's API version is lower than the one required (current: v%d.%d, required: v%d.%d).", PLUGIN_NAME, "ReHLDS", iMajorVersion, iMinorVersion, g_iVersionRequired_RH[0], g_iVersionRequired_RH[1])
			//pause("ae")
			return
		}
	}

	switch(ReAPI_BF_HasBinaryRunning(ReAPI_BT_ReGameDLL_CS, true, g_iVersionRequired_RGCS[0], g_iVersionRequired_RGCS[1], true, true)) {
		case ReAPI_HBRRT_NoReBinary: {
			log_amx("[%s] Unable to use the plugin, the %s's API is unavailable (the %s game binary is probably not running).", PLUGIN_NAME, "ReGameDLL_CS", "ReGameDLL_CS")
			//pause("ae")
			return
		}
		case ReAPI_HBRRT_InternalCheckFailed: {
			log_amx("[%s] Unable to use the plugin, the %s's API version is different than the one required internally by the module.", PLUGIN_NAME, "ReGameDLL_CS")
			//pause("ae")
			return
		}
		case ReAPI_HBRRT_ExternalCheckFailed: {
			new iMajorVersion = -1, iMinorVersion = -1
			ReAPI_BF_GetBinaryInformations(ReAPI_BT_ReGameDLL_CS, iMajorVersion, iMinorVersion)
			log_amx("[%s] Unable to use the plugin, the %s's API version is lower than the one required (current: v%d.%d, required: v%d.%d).", PLUGIN_NAME, "ReGameDLL_CS", iMajorVersion, iMinorVersion, g_iVersionRequired_RGCS[0], g_iVersionRequired_RGCS[1])
			//pause("ae")
			return
		}
	}

	g_pCVars[CVAR_DAMAGE] = register_cvar("reapi_aka_damage", "30")
	g_pCVars[CVAR_FRAG]   = register_cvar("reapi_aka_frag",  "1")
	g_pCVars[CVAR_MONEY]  = register_cvar("reapi_aka_money",  "100")

	g_pCVar_MPFriendlyFire = get_cvar_pointer("mp_friendlyfire")
	g_pCVar_MPFreeForAll   = get_cvar_pointer("mp_freeforall")

	/*#if ASSIST_ALGORITHM == CSSTATSX
	g_pCVar_AssistHp = get_cvar_pointer("csstats_sql_assisthp")
	#endif*/

	g_iMaxClients = get_maxplayers()

	ReAPI_HM_AddHookByTypeName(ReAPI_BT_ReHLDS, "SV_WriteFullClientUpdate", ReAPI_AHCT_Pre2_Unalterable, ReAPI_AHPT_Middle, "HOOK_SV_WriteFullClientUPD_Pre2", g_pAMXHook_SV_WriteFullClUPD)
	ReAPI_HM_SwitchHookStatusByHandle(g_pAMXHook_SV_WriteFullClUPD, false)

	ReAPI_HM_AddHookByTypeName(ReAPI_BT_ReGameDLL_CS, "CBasePlayer::Spawn", ReAPI_AHCT_Post2_Unalterable, ReAPI_AHPT_Middle, "HOOK_CBP_Spawn_Post2")
	ReAPI_HM_AddHookByTypeName(ReAPI_BT_ReGameDLL_CS, "CBasePlayer::TakeDamage", ReAPI_AHCT_Pre2_Unalterable, ReAPI_AHPT_Middle, "HOOK_CBP_TakeDamage_Pre2")
	ReAPI_HM_AddHookByTypeName(ReAPI_BT_ReGameDLL_CS, "CBasePlayer::TakeDamage", ReAPI_AHCT_Post2_Unalterable, ReAPI_AHPT_Middle, "HOOK_CBP_TakeDamage_Post2")
	ReAPI_HM_AddHookByTypeName(ReAPI_BT_ReGameDLL_CS, "CBasePlayer::Killed", ReAPI_AHCT_Pre2_Unalterable, ReAPI_AHPT_Middle, "HOOK_CBP_Killed_Pre2")
	ReAPI_HM_AddHookByTypeName(ReAPI_BT_ReGameDLL_CS, "CBasePlayer::Killed", ReAPI_AHCT_Post2_Unalterable, ReAPI_AHPT_Middle, "HOOK_CBP_Killed_Post2", g_pAMXHook_CBP_Killed_Post2)
	ReAPI_HM_SwitchHookStatusByHandle(g_pAMXHook_CBP_Killed_Post2, false)

	register_message(get_user_msgid("DeathMsg"), "Message_DeathMsg")
}

public client_infochanged(iClientID) {
	get_user_info(iClientID, "name", g_ePlayerData_NAME[iClientID], charsmax(g_ePlayerData_NAME[]))
}

public client_disconnect(iClientID) {
	arraysetfloat(g_ePlayerData_DMGONTIME[iClientID], 0.0, sizeof(g_ePlayerData_DMGONTIME[]))
}

public HOOK_SV_WriteFullClientUPD_Pre2(iTargetClientID, szInfoBuffer[], iInfoBufferLength, pSizeBufferHandle, iReceiverClientID) {
	if((ReAPI_HM_GetHookReturn(true, false) & ReAPI_AHRVF_Supercede)
	|| !is_user_connected(iReceiverClientID))
		return ReAPI_AHRVF_Ignored

	if(iTargetClientID != g_iAssistAttackerID || g_szDeathString[0] == EOS)
		return ReAPI_AHRVF_Ignored

	ReAPI_ES_SetKeyValue(0, "name", g_szDeathString)

	return ReAPI_AHRVF_Handled // Indirect parameter modification!
}

public HOOK_CBP_Spawn_Post2(iClientID) {
	// Reset the damage that client did to others.
	//arrayset(g_ePlayerData_DMGON[iClientID], 0, sizeof(g_ePlayerData_DMGON[]))

	for(new iTempClientID = 1; iTempClientID <= g_iMaxClients; iTempClientID++) {
		// Reset the damage that client did to others.
		g_ePlayerData_DMGON[iClientID][iTempClientID] = 0

		// Reset the damage the others did to that client.
		g_ePlayerData_DMGON[iTempClientID][iClientID]     = 0
		g_ePlayerData_DMGONTIME[iTempClientID][iClientID] = 0.0
	}
}

public HOOK_CBP_TakeDamage_Pre2(iClientID, iInflictorID, iAttackerID, Float:flDamage, iDamageBits) {
	g_iOldClientHealth = -454247614 // Or enable/disable the hook?

	if((ReAPI_HM_GetHookReturn(true, false) & ReAPI_AHRVF_Supercede)
	|| !is_user_valid(iAttackerID)
	|| iClientID == iAttackerID
	|| !CGameRules_FPlayerCanTakeDamage(iClientID, iAttackerID))
		return ReAPI_AHRVF_Ignored

	g_iOldClientHealth = get_user_health(iClientID)

	return ReAPI_AHRVF_Ignored
}

public HOOK_CBP_TakeDamage_Post2(iClientID, iInflictorID, iAttackerID, Float:flDamage, iDamageBits) {
	if(g_iOldClientHealth == -454247614)
		return ReAPI_AHRVF_Ignored

	// Use "final" damage.
	flDamage = entity_get_float(iClientID, EV_FL_dmg_take)

	if(flDamage <= 0.0)
		return ReAPI_AHRVF_Ignored

	//#if ASSIST_ALGORITHM == ADVANCED
	new iHealth = g_iOldClientHealth
	if(flDamage > iHealth) {
		flDamage = iHealth * 1.0
	}
	//#endif

	g_ePlayerData_DMGON[iAttackerID][iClientID]     += floatround(flDamage)
	g_ePlayerData_DMGONTIME[iAttackerID][iClientID] = get_gametime()

	return ReAPI_AHRVF_Ignored
}

public HOOK_CBP_Killed_Pre2(iClientID, iAttackerID, iGib) {
	if((ReAPI_HM_GetHookReturn(true, false) & ReAPI_AHRVF_Supercede)
	|| iAttackerID == iClientID)
		return ReAPI_AHRVF_Ignored

	new iClientsIDs[32], iClientsNum
	get_players(iClientsIDs, iClientsNum)

	if(iClientsNum <= 2) // Guy is alone or killed an anemy alone too! But will not happen when attacker is client!
		return ReAPI_AHRVF_Ignored

	new iAssistantID, iTempClientID
	new iMaxDamage
	new Float:flDamageForAssist = floatmax(get_cvarptr_float(g_pCVars[CVAR_DAMAGE]), 0.0)

	//#if ASSIST_ALGORITHM == ADVANCED
	new iTotalDamage

	for(new a = 0; a < iClientsNum; a++) {
		iTempClientID = iClientsIDs[a]

		if(iTempClientID != iAttackerID && g_ePlayerData_DMGON[iTempClientID][iClientID] > 0) {
			if(g_ePlayerData_DMGON[iTempClientID][iClientID] > iMaxDamage) {
				iAssistantID = iTempClientID
				iMaxDamage   = g_ePlayerData_DMGON[iTempClientID][iClientID]
			}
			else if(g_ePlayerData_DMGON[iTempClientID][iClientID] == iMaxDamage) {
				iAssistantID = g_ePlayerData_DMGONTIME[iTempClientID][iClientID] > g_ePlayerData_DMGONTIME[iAssistantID][iClientID] ? iTempClientID : iAssistantID
			}
		}

		iTotalDamage += g_ePlayerData_DMGON[iTempClientID][iClientID]
	}

	if((float(iMaxDamage) / float(iTotalDamage)) * 100.0 < flDamageForAssist) {
		iAssistantID = 0
	}

	/*//#else#if ASSIST_ALGORITHM == CSSTATSX
		new iNeedDamage = g_pCVar_AssistHp ? get_cvarptr_num(g_pCVar_AssistHp) : floatround(flDamageForAssist)

		for(new a = 0; a < iClientsNum; a++) {
			iTempClientID = iClientsIDs[a]

			if(iTempClientID != iAttackerID && g_ePlayerData_DMGON[iTempClientID][iClientID] > iMaxDamage) {
				if(g_ePlayerData_DMGON[iTempClientID][iClientID] > iNeedDamage) {
					iAssistantID = iTempClientID
					iMaxDamage = g_ePlayerData_DMGON[iTempClientID][iClientID]
				}
				else if(g_ePlayerData_DMGON[iTempClientID][iClientID] == iNeedDamage) {
					iAssistantID = g_ePlayerData_DMGONTIME[iTempClientID][iClientID] > g_ePlayerData_DMGONTIME[iAssistantID][iClientID] ? iTempClientID : iAssistantID
				}
			}
		}
	#endif*/

	if(!iAssistantID/* || iAssistantID == iAttackerID*/)
		return ReAPI_AHRVF_Ignored

	ReAPI_HM_SwitchHookStatusByHandle(g_pAMXHook_SV_WriteFullClUPD, true)

	new szName[2][32], iLen[2], iExcess
	copy(szName[1], charsmax(szName[]), g_ePlayerData_NAME[iAssistantID])
	iLen[1] = strlen(szName[1])

	new bool:bIsAssistantConnected = bool:is_user_connected(iAssistantID)

	// TO DO: Improve this part with custom attackers (triggers, custom weapons, vehicles, etc.)?
	if(!is_user_valid(iAttackerID)) {
		if(bIsAssistantConnected == true) {
			static const szWorldName[] = "world"

			iExcess = iLen[1] - NAMES_LENGTH - (sizeof szWorldName)
			if(iExcess > 0) {
				strclip(szName[1], iExcess)
			}
			formatex(g_szDeathString, charsmax(g_szDeathString), "%s + %s", szWorldName, szName[1])

			g_iAssistAttackerID = iAssistantID
			ReAPI_FC_CallFunctionByTypeName(ReAPI_CFGT_RH_ReHLDSFuncs, "SV_UpdateUserInfo", 0, iAssistantID)
		}
	}
	else if(is_user_connected(iAttackerID)) {
		g_ePlayerData_DMGON[iAttackerID][iClientID] = 0

		copy(szName[0], charsmax(szName[]), g_ePlayerData_NAME[iAttackerID])
		iLen[0] = strlen(szName[0])

		new iLenSum = (iLen[0] + iLen[1])
		iExcess = iLenSum - NAMES_LENGTH

		if(iExcess > 0) {
			new iLongest  = iLen[0] > iLen[1] ? 0 : 1
			new iShortest = iLongest == 1 ? 0 : 1

			if(float(iExcess) / float(iLen[iLongest]) > 0.60) {
				new iNewLongest = floatround(float(iLen[iLongest]) / float(iLenSum) * float(iExcess))
				strclip(szName[iLongest], iNewLongest)
				strclip(szName[iShortest], iExcess - iNewLongest)
			}
			else {
				strclip(szName[iLongest], iExcess)
			}
		}

		formatex(g_szDeathString, charsmax(g_szDeathString), "%s + %s", szName[0], szName[1])

		g_iAssistAttackerID = iAttackerID
		ReAPI_FC_CallFunctionByTypeName(ReAPI_CFGT_RH_ReHLDSFuncs, "SV_UpdateUserInfo", 0, iAttackerID)
	}

	if(bIsAssistantConnected) {   
		g_ePlayerData_DMGON[iAssistantID][iClientID] = 0

		if(get_cvarptr_num(g_pCVars[CVAR_FRAG]) >= 1) {
			set_user_frags(iAssistantID, get_user_frags(iAssistantID) + 1)
		}

		new iAddMoney = get_cvarptr_num(g_pCVars[CVAR_MONEY])
		if(iAddMoney >= 1) {
			ReAPI_FC_CallFunctionByTypeName(ReAPI_CFGT_RGCS_CCSPlayer, "AddAccount", 0, iAssistantID, iAddMoney, _:RT_NONE, true)
		}
	}

	ReAPI_HM_SwitchHookStatusByHandle(g_pAMXHook_CBP_Killed_Post2, true)
	return ReAPI_AHRVF_Ignored
}

public HOOK_CBP_Killed_Post2(iVictim, iKiller, iGib) {
	ReAPI_HM_SwitchHookStatusByHandle(g_pAMXHook_SV_WriteFullClUPD, false)
	ReAPI_HM_SwitchHookStatusByHandle(g_pAMXHook_CBP_Killed_Post2, false)

	new iAssistAttackerID = g_iAssistAttackerID

	g_iAssistAttackerID = 0
	g_szDeathString[0]  = EOS

	ReAPI_FC_CallFunctionByTypeName(ReAPI_CFGT_RH_ReHLDSFuncs, "SV_UpdateUserInfo", 0, iAssistAttackerID)
}

public Message_DeathMsg() {
	if(get_msg_arg_int(1) == 0 && g_iAssistAttackerID) {
		set_msg_arg_int(1, g_iAssistAttackerID)
	}
}

// Notes:
//   Bad to hardcode, as this will not apply the possible custom modifications we might do on an hook of that function.
//   But my current AMX Mod version & ReAPI module do not have such function available as "call", so use this for now.
CGameRules_FPlayerCanTakeDamage(iClientID, iAttackerID) {
	if(!is_user_valid(iClientID) || !is_user_valid(iAttackerID))
		return true

	// Custom addition.
	/*if(get_user_godmode(iClientID))
		return false*/

	if(iClientID == iAttackerID)
		return true

	if(get_cvarptr_num(g_pCVar_MPFreeForAll))
		return true
		//return false // Adjustement for the plugin, should the assistant system work in FFA?

	if(get_user_team(iClientID) != get_user_team(iAttackerID))
		return true

	if(get_cvarptr_num(g_pCVar_MPFriendlyFire))
		return true

	return false
}

// Note: More than one successive "dot" (..) are not taken in account in the names.
strclip(szString[], iClip, szEnding[] = ".etc.") {
	new iLen = strlen(szString) - 1 - strlen(szEnding) - iClip
	format(szString[iLen], iLen, szEnding)
}
