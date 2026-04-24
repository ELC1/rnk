#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo =
{
    name = "RNK Quake Sounds",
    author = "RNK",
    description = "Sons estilo Quake para kills em sequencia",
    version = "1.1.0",
    url = ""
};

// Streaks a partir de 2 kills seguidas
static const char STREAK_SOUNDS[][] = {
    "rnk/quake/doublekill.wav",
    "rnk/quake/triplekill.wav",
    "rnk/quake/multikill.wav",
    "rnk/quake/killingspree.wav",
    "rnk/quake/rampage.wav",
    "rnk/quake/dominating.wav",
    "rnk/quake/unstoppable.wav",
    "rnk/quake/godlike.wav",
    "rnk/quake/monsterkill.wav",
    "rnk/quake/ludicrouskill.wav",
    "rnk/quake/holyshit.wav",
    "rnk/quake/wickedsick.wav"
};

static const char STREAK_MSGS[][] = {
    "Double Kill",
    "Triple Kill",
    "Multi Kill",
    "Killing Spree",
    "Rampage",
    "Dominating",
    "Unstoppable",
    "God Like",
    "Monster Kill",
    "Ludicrous Kill",
    "Holy Shit",
    "Wicked Sick"
};

static const char HEADSHOT_SOUND[]    = "rnk/quake/headshot.wav";
static const char FIRSTBLOOD_SOUND[]  = "rnk/quake/firstblood.wav";
static const char HUMILIATION_SOUND[] = "rnk/quake/humiliation.wav";
static const char TEAMKILL_SOUND[]    = "rnk/quake/teamkiller.wav";

// Sons extras precacheados para download mas nao usados em eventos proprios
static const char EXTRA_SOUNDS[][] = {
    "rnk/quake/excellent.wav",
    "rnk/quake/impressive.wav",
    "rnk/quake/ownage.wav",
    "rnk/quake/ultrakill.wav",
    "rnk/quake/massacre.wav",
    "rnk/quake/maniac.wav",
    "rnk/quake/assassination.wav",
    "rnk/quake/headshot2.wav",
    "rnk/quake/headshot3.wav",
    "rnk/quake/headshot4.wav"
};

int gKillStreak[MAXPLAYERS + 1];
bool gFirstBloodDone;

ConVar gCvarEnabled;
ConVar gCvarHeadshot;
ConVar gCvarTeamkill;
ConVar gCvarVolume;

public void OnPluginStart()
{
    gCvarEnabled   = CreateConVar("sm_rnk_quake_enabled",   "1",   "Ativa/desativa quake sounds.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarHeadshot  = CreateConVar("sm_rnk_quake_headshot",  "1",   "Ativa som de headshot.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarTeamkill  = CreateConVar("sm_rnk_quake_teamkill",  "1",   "Ativa som de teamkill.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarVolume    = CreateConVar("sm_rnk_quake_volume",    "0.7", "Volume dos sons (0.0-1.0).", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    AutoExecConfig(true, "rnk_quakesounds");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("round_start",  Event_RoundStart,  EventHookMode_Post);
}

public void OnMapStart()
{
    PrecacheAndAdd(HEADSHOT_SOUND);
    PrecacheAndAdd(FIRSTBLOOD_SOUND);
    PrecacheAndAdd(HUMILIATION_SOUND);
    PrecacheAndAdd(TEAMKILL_SOUND);

    for (int i = 0; i < sizeof(STREAK_SOUNDS); i++)
        PrecacheAndAdd(STREAK_SOUNDS[i]);

    for (int i = 0; i < sizeof(EXTRA_SOUNDS); i++)
        PrecacheAndAdd(EXTRA_SOUNDS[i]);
}

void PrecacheAndAdd(const char[] sound)
{
    // Apenas precache — cliente ja tem os arquivos localmente
    PrecacheSound(sound, true);
}

void PlaySound(const char[] sound)
{
    EmitSoundToAll(sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, gCvarVolume.FloatValue);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    gFirstBloodDone = false;
    for (int i = 1; i <= MaxClients; i++)
        gKillStreak[i] = 0;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!gCvarEnabled.BoolValue)
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));
    bool headshot = event.GetBool("headshot");

    if (victim >= 1 && victim <= MaxClients)
        gKillStreak[victim] = 0;

    if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker))
        return;

    // Suicidio
    if (attacker == victim)
    {
        PlaySound(HUMILIATION_SOUND);
        PrintToChatAll("\x04[RNK]\x01 \x03%N\x01 se matou! \x05Humiliation!", attacker);
        gKillStreak[attacker] = 0;
        return;
    }

    // Teamkill
    if (GetClientTeam(attacker) == GetClientTeam(victim))
    {
        if (gCvarTeamkill.BoolValue)
        {
            PlaySound(TEAMKILL_SOUND);
            PrintToChatAll("\x04[RNK]\x01 \x03%N\x01 matou o proprio time! \x05Team Killer!", attacker);
        }
        gKillStreak[attacker] = 0;
        return;
    }

    // First Blood
    if (!gFirstBloodDone)
    {
        gFirstBloodDone = true;
        PlaySound(FIRSTBLOOD_SOUND);
        PrintToChatAll("\x04[RNK]\x01 \x03%N\x01 fez o \x05First Blood\x01!", attacker);
    }

    // Headshot
    if (headshot && gCvarHeadshot.BoolValue)
    {
        PlaySound(HEADSHOT_SOUND);
        PrintToChatAll("\x04[RNK]\x01 \x03%N\x01 \x05Headshot\x01 em \x03%N\x01!", attacker, victim);
    }

    gKillStreak[attacker]++;

    int streak = gKillStreak[attacker];
    if (streak >= 2)
    {
        int idx = streak - 2;
        if (idx >= sizeof(STREAK_SOUNDS))
            idx = sizeof(STREAK_SOUNDS) - 1;

        PlaySound(STREAK_SOUNDS[idx]);
        PrintToChatAll("\x04[RNK]\x01 \x03%N\x01 - \x05%s\x01! (%d kills)", attacker, STREAK_MSGS[idx], streak);
    }
}
