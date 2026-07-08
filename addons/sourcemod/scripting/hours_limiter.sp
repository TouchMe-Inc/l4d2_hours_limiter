#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <steamworks>


public Plugin myinfo = {
    name        = "HoursLimiter",
    author      = "TouchMe",
    description = "The plugin prevents players with a certain number of hours from entering the server",
    version     = "build_0005",
    url         = "https://github.com/TouchMe-Inc/l4d2_hours_limiter"
};


#define APP_L4D2                550


int g_iClientTry[MAXPLAYERS + 1] = {0, ...};

ConVar
    g_cvAppId = null,                 /**< sm_hours_limiter_appid */
    g_cvMinPlayedHours = null,        /**< sm_min_played_hours */
    g_cvMaxPlayedHours = null,        /**< sm_max_played_hours */
    g_cvMaxTryCheckPlayerHours = null,/**< sm_max_try_check_player_hours */
    g_cvKickHiddenHours = null;       /**< sm_kick_hidden_hours */


/**
  * Called before OnPluginStart.
  */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("hours_limiter.phrases");

    g_cvAppId                  = CreateConVar("sm_hours_limiter_appid", "550", "AppId of the game you want to check the played time of");
    g_cvMinPlayedHours         = CreateConVar("sm_min_played_hours", "10.0", "Minimum number of hours allowed to play");
    g_cvMaxPlayedHours         = CreateConVar("sm_max_played_hours", "99999.0", "Maximum number of hours allowed to play");
    g_cvMaxTryCheckPlayerHours = CreateConVar("sm_max_try_check_player_hours", "3", "Maximum number of attempts to check the played time");
    g_cvKickHiddenHours        = CreateConVar("sm_kick_hidden_hours", "1", "Kick hidden hours");
}

public void OnClientPostAdminCheck(int iClient)
{
    if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return;
    }

    if (!SteamWorks_IsConnected())
    {
        LogError("Steamworks: No Steam Connection!");
        return;
    }

    g_iClientTry[iClient] = 0;

    TryCheckPlayerHours(iClient);
}

Action Timer_TryCheckPlayerHours(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);

    if (!iClient) {
        return Plugin_Stop;
    }

    TryCheckPlayerHours(iClient);
    return Plugin_Stop;
}

void TryCheckPlayerHours(int iClient)
{
    if (++ g_iClientTry[iClient] > GetConVarInt(g_cvMaxTryCheckPlayerHours))
    {
        if (GetConVarBool(g_cvKickHiddenHours)) {
            KickClient(iClient, "%T", "MAX_ATTEMPT", iClient, g_iClientTry[iClient]);
        }
        return;
    }

    int iPlayedTime = 0;
    bool bRequestStats = SteamWorks_RequestStats(iClient, GetConVarInt(g_cvAppId));
    bool bGetStatCell = SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iPlayedTime);

    if (!bRequestStats || !bGetStatCell) {
        CreateTimer(1.0, Timer_TryCheckPlayerHours, GetClientUserId(iClient));
        return;
    }

    if (!iPlayedTime && GetConVarBool(g_cvKickHiddenHours))
    {
        KickClient(iClient, "%T", "KICK_HIDDEN_HOURS", iClient);
        return;
    }

    float fHours = SecToHours(iPlayedTime);

    float fMinPlayedHours = GetConVarFloat(g_cvMinPlayedHours);
    if (fHours < fMinPlayedHours) {
        KickClient(iClient, "%T", "MIN_HOURS_LIMIT", iClient, fMinPlayedHours);
        return;
    }

    float fMaxPlayedHours = GetConVarFloat(g_cvMaxPlayedHours);
    if (fHours > fMaxPlayedHours) {
        KickClient(iClient, "%T", "MAX_HOURS_LIMIT", iClient, fMaxPlayedHours);
    }
}

float SecToHours(int iSeconds) {
    return float(iSeconds) / 3600.0;
}
