#pragma semicolon              1
#pragma newdecls               required

#include <steamworks>


public Plugin myinfo = {
    name        = "HoursLimiter",
    author      = "TouchMe",
    description = "The plugin prevents players with a certain number of hours from entering the server",
    version     = "build_0004",
    url         = "https://github.com/TouchMe-Inc/l4d2_hours_limiter"
};


#define APP_L4D2                550


int g_iClientTry[MAXPLAYERS + 1] = {0, ...};

ConVar
    g_cvMinPlayedHours = null, /**< sm_min_played_hours */
    g_cvMaxPlayedHours = null, /**< sm_max_played_hours */
    g_cvMaxTryCheckPlayerHours = null; /**< sm_max_try_check_player_hours */


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
    g_cvMinPlayedHours = CreateConVar("sm_min_played_hours", "10.0", "Minimum number of hours allowed to play");
    g_cvMaxPlayedHours = CreateConVar("sm_max_played_hours", "99999.0", "Maximum number of hours allowed to play");
    g_cvMaxTryCheckPlayerHours = CreateConVar("sm_max_try_check_player_hours", "3", "Maximum number of attempts to check the played time");
}

public void SteamWorks_OnValidateClient(int iOwnAuthId, int iAuthId) {
    SteamWorks_RequestStatsAuthID(iAuthId, APP_L4D2);
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

Action Timer_TryCheckPlayerHours(Handle hTimer, int iClient)
{
    if (!IsClientInGame(iClient) || IsFakeClient(iClient) ) {
        return Plugin_Stop;
    }

    TryCheckPlayerHours(iClient);
    return Plugin_Stop;
}

void TryCheckPlayerHours(int iClient)
{
    if (++ g_iClientTry[iClient] > GetConVarInt(g_cvMaxTryCheckPlayerHours))
    {
        ServerCommand("sm_kick #%i \"Attempt #%d to determine the time played was unsuccessful\"", GetClientUserId(iClient), g_iClientTry[iClient]);
        return;
    }

    int iPlayedTime;
    bool bRequestStats = SteamWorks_RequestStats(iClient, APP_L4D2);
    bool bGetStatCell = SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iPlayedTime);

    if (!bRequestStats || !bGetStatCell) {
        CreateTimer(1.0, Timer_TryCheckPlayerHours, iClient);
        return;
    }

    float fHours = SecToHours(iPlayedTime);
    float fMinPlayedHours = GetConVarFloat(g_cvMinPlayedHours);
    float fMaxPlayedHours = GetConVarFloat(g_cvMaxPlayedHours);

    if (fHours < fMinPlayedHours) {
        ServerCommand("sm_kick #%i \"Must have more than %.1f hours of play\"", GetClientUserId(iClient), fMinPlayedHours);
    }

    else if (fHours > fMaxPlayedHours) {
        ServerCommand("sm_kick #%i \"There should be no more than %.1f hours of play\"", GetClientUserId(iClient), fMaxPlayedHours);
    }
}

float SecToHours(int iSeconds) {
    return float(iSeconds) / 3600.0;
}
