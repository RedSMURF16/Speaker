/*
*
*	Speaker by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*       say /speaker                    "Opens the Speaker menu."
*       say_team /speaker               "Opens the Speaker menu."
*       speaker_reload                  "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT                         32
#define ADMIN_ACCESS                    ADMIN_RCON
#define PDATA_NEXT_ATTACK               83
#define XO_CBASEPLAYER                  5
#define XO_CBASEPLAYERWEAPON            4
#define SPEAKER_KEY                     512231
#define SPEAKER_ARRAY_ITEM              pev_iuser1
#define VOLUME_STEP                     10.0
#define REFRESH_RATE                    0.9
#define SOUND_NAV                       "buttons/blip1.wav"
#define SOUND_REMOVE                    "buttons/button10.wav"
#define SOUND_ALERT                     "buttons/bell1.wav"

new const PLUGIN_VERSION[]          = "1.0"
new const Float:DELAY_ON_LOAD       = 2.5
new const ERROR_FILE[]              = "Speaker_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_SPEAKER
}

enum
{
    DTYPE_INT,
    DTYPE_FLOAT,
    DTYPE_FLAGS,
    DTYPE_ARRAY_STRING,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_MODEL_ID
}

enum
{
    FLAG_SHAKE              = (1 << 0),

    FLAG_SHOW               = (1 << 1),
    FLAG_GHOST              = (1 << 2),
    FLAG_GROUND             = (1 << 3),
    FLAG_ACTIVE             = (1 << 4)
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    TARGET_GHOST,
    TARGET_SELECT,
    TARGET_HIDE,
    TARGET_CLEAR
}

enum
{
    MODE_LOOP,
    MODE_SEQUENTIAL,
    MODE_RANDOM
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_MODE,
    SETTING_DEFAULT_USE_FLAGS,
    SETTING_DEFAULT_USE_TEAM,
    Float:SETTING_DEFAULT_ATTENUATION,
    Float:SETTING_DEFAULT_SHAKE_DISTANCE,
    SETTING_DEFAULT_SHAKE_AMPLITUDE,
    SETTING_DEFAULT_SHAKE_FREQUENCY,
    SETTING_DEFAULT_SHAKE_DURATION,

    Float:SETTING_MINS[3],
    Float:SETTING_MAXS[3],

    bool:SETTING_SPEAKER_LOAD,
    Float:SETTING_SPEAKER_CHECK,
    Float:SETTING_SPEAKER_TASK,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    SETTING_GHOST_ALPHA,
    Float:SETTING_ROTATION_STEP
}

enum _:SPEAKER
{
    SPEAKER_ID,
    SPEAKER_ITEM,
    SPEAKER_FLAGS,
    SPEAKER_MODE,
    SPEAKER_USE_FLAGS,
    SPEAKER_USE_TEAM,
    Float:SPEAKER_ATTENUATION,
    Float:SPEAKER_CURRENT_VOLUME,
    SPEAKER_CURRENT_SONG[MAX_VALUE_LENGTH],
    SPEAKER_CURRENT_SONG_ID,
    SPEAKER_NAME[MAX_VALUE_LENGTH],
    SPEAKER_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:SPEAKER_ORIGIN[3],
    Float:SPEAKER_ANGLES[3],
    Float:SPEAKER_MINS[3],
    Float:SPEAKER_MAXS[3],
    Array:SPEAKER_SONG,
    Array:SPEAKER_SONG_DURATION,
    SPEAKER_SONG_COUNT,

    Float:SPEAKER_NEXT_SONG
}

enum _:PLAYER_DATA
{
    PDATA_SPEAKER_GHOST,
    PDATA_SPEAKER_MENU,
    bool:PDATA_SPEAKER_ACTION,
    PDATA_SPEAKER_ID,
    bool:PDATA_SPEAKER_REFRESH,
    bool:PDATA_SPEAKER_REFRESHING,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,

    PDATA_MENU_TYPE,
    bool:PDATA_MENU_TRACE,
    Float:PDATA_NEXT_REFRESH
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_EDIT,
    MENU_REMOVE,
    MENU_SHOW,
    MENU_STATUS,
    MENU_ROTATE,
    MENU_SPEAKER,
    MENU_SPEAKER_SONG,
    MENU_SPEAKER_VOLUME
}

enum
{
    ROOT_CREATE,
    ROOT_EDIT,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    EDIT_SHOW,
    EDIT_STATUS
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SHOW_NEXT,
    SHOW_BACK,

    SHOW_CURRENT = 3,
    SHOW_ALL_SHOW,
    SHOW_ALL_HIDE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    ROTATE_UP,
    ROTATE_DOWN,

    ROTATE_GROUND = 3,
    ROTATE_PLACE
}

enum
{
    SPEAKER_SPEAKER_SONG = 2,
    SPEAKER_SPEAKER_VOLUME,
    SPEAKER_SPEAKER_MODE,
    SPEAKER_SPEAKER_POWER
}

enum
{
    VOLUME_UP = 2,
    VOLUME_DOWN
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerEdit",
    "menuHandlerRemove",
    "menuHandlerShow",
    "menuHandlerStatus",
    "menuHandlerRotate",
    "menuHandlerSpeaker",
    "menuHandlerSpeakerSong",
    "menuHandlerSpeakerVolume"
}

new g_szCN[] = "speaker"

new Array:g_aSpeaker,
    Array:g_aSpeakerConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead, g_iActivePlayers,
    g_iFwdEmitSound, HamHook:g_iFwdUse, HamHook:g_iFwdObjectCaps, HamHook:g_iFwdPreThink,
    g_iSpeaker, g_iSpeakerConfig, g_iSongCallback, g_iScreenShake, g_iMaxPlayers

new const g_iColorActive[] = { 0, 255, 0 }
new const g_iColorInactive[] = { 255, 0, 0 }
new g_szSpeakerMode[][] = {"SPEAKER_LOOP", "SPEAKER_SEQUENTIAL", "SPEAKER_RANDOM"}

public plugin_init()
{
    register_plugin("Speaker", PLUGIN_VERSION, "RedSMURF")
    register_cvar("RedSMURF_Speaker", PLUGIN_VERSION, ADMIN_ACCESS)

    register_clcmd("say /speaker",       "cmdMenu", ADMIN_ACCESS, "-- Opens the Speaker menu.")
    register_clcmd("say_team /speaker",  "cmdMenu", ADMIN_ACCESS, "-- Opens the Speaker menu.")
    register_concmd("speaker_reload",  "cmdReload", ADMIN_ACCESS, "-- Reloads the configuration file")
    register_dictionary("Speaker.txt")

    g_iFwdEmitSound = register_forward(FM_EmitSound, "fwdEmitSound")
    g_iFwdUse = RegisterHam(Ham_Use, "info_target", "fwdUse")
    g_iFwdObjectCaps = RegisterHam(Ham_ObjectCaps, "info_target", "fwdObjectCaps")
    g_iFwdPreThink = RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    g_iScreenShake = get_user_msgid("ScreenShake")
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    DisableForward()
    DisableSpeaker()

    speakerInit()
    g_iSongCallback = menu_makecallback("menuHandlerSpeakerSongItem")
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aSpeaker = ArrayCreate(SPEAKER)
    g_aSpeakerConfig = ArrayCreate(SPEAKER)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aSpeaker)
    ArrayDestroy(g_aSpeakerConfig)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public eventRoundStart()
{
    speakerReset()
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        ArrayClear(g_aSpeakerConfig)
        g_iSpeakerConfig = 0
    }

    new szFile[MAX_RESOURCE_PATH_LENGTH], iFile
    get_configsdir(szFile, charsmax(szFile))
    add(szFile, charsmax(szFile), "/Speaker.ini")
    iFile = fopen(szFile, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH], szValue[MAX_VALUE_LENGTH],
        eSpeaker[SPEAKER], iSection = SECTION_NONE, iLine, iPos

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax(szData), "[", "")
                    replace(szData, charsmax(szData), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iSpeakerConfig )
                            ArrayPushArray(g_aSpeakerConfig, eSpeaker)

                        copy(eSpeaker[SPEAKER_NAME], charsmax(eSpeaker[SPEAKER_NAME]), szData)
                        eSpeaker[SPEAKER_FLAGS]                     = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eSpeaker[SPEAKER_MODE]                      = g_eSettings[SETTING_DEFAULT_MODE]
                        eSpeaker[SPEAKER_USE_FLAGS]                 = g_eSettings[SETTING_DEFAULT_USE_FLAGS]
                        eSpeaker[SPEAKER_USE_TEAM]                  = g_eSettings[SETTING_DEFAULT_USE_TEAM]
                        eSpeaker[SPEAKER_ATTENUATION]               = g_eSettings[SETTING_DEFAULT_ATTENUATION]
                        eSpeaker[SPEAKER_SONG]                      = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
                        eSpeaker[SPEAKER_SONG_DURATION]             = ArrayCreate(1)
                        eSpeaker[SPEAKER_SONG_COUNT]                = 0

                        iSection = SECTION_SPEAKER
                        g_iSpeakerConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_MODE") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODE], charsmax(g_eSettings[SETTING_DEFAULT_MODE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_USE_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_USE_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_USE_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_USE_TEAM") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_USE_TEAM], charsmax(g_eSettings[SETTING_DEFAULT_USE_TEAM]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ATTENUATION") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ATTENUATION], charsmax(g_eSettings[SETTING_DEFAULT_ATTENUATION]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SHAKE_DISTANCE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SHAKE_DISTANCE], charsmax(g_eSettings[SETTING_DEFAULT_SHAKE_DISTANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SHAKE_AMPLITUDE") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SHAKE_AMPLITUDE], charsmax(g_eSettings[SETTING_DEFAULT_SHAKE_AMPLITUDE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SHAKE_FREQUENCY") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SHAKE_FREQUENCY], charsmax(g_eSettings[SETTING_DEFAULT_SHAKE_FREQUENCY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SHAKE_DURATION") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SHAKE_DURATION], charsmax(g_eSettings[SETTING_DEFAULT_SHAKE_DURATION]))
                        else if ( equali(szKey, "SETTING_MINS") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_MINS], charsmax(g_eSettings[SETTING_MINS]))
                        else if ( equali(szKey, "SETTING_MAXS") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_MAXS], charsmax(g_eSettings[SETTING_MAXS]))
                        else if ( equali(szKey, "SETTING_SPEAKER_LOAD") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_SPEAKER_LOAD], charsmax(g_eSettings[SETTING_SPEAKER_LOAD]))
                        else if ( equali(szKey, "SETTING_SPEAKER_CHECK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_SPEAKER_CHECK], charsmax(g_eSettings[SETTING_SPEAKER_CHECK]))
                        else if ( equali(szKey, "SETTING_SPEAKER_TASK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_SPEAKER_TASK], charsmax(g_eSettings[SETTING_SPEAKER_TASK]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_ROTATION_STEP") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_ROTATION_STEP], charsmax(g_eSettings[SETTING_ROTATION_STEP]))
                    }
                    case SECTION_SPEAKER:
                    {
                        if ( equali(szKey, "SPEAKER_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), eSpeaker[SPEAKER_FLAGS], charsmax(eSpeaker[SPEAKER_FLAGS]))
                        else if ( equali(szKey, "SPEAKER_MODE") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), eSpeaker[SPEAKER_MODE], charsmax(eSpeaker[SPEAKER_MODE]))
                        else if ( equali(szKey, "SPEAKER_USE_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), eSpeaker[SPEAKER_USE_FLAGS], charsmax(eSpeaker[SPEAKER_USE_FLAGS]))
                        else if ( equali(szKey, "SPEAKER_USE_TEAM") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), eSpeaker[SPEAKER_USE_TEAM], charsmax(eSpeaker[SPEAKER_USE_TEAM]))
                        else if ( equali(szKey, "SPEAKER_ATTENUATION") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), eSpeaker[SPEAKER_ATTENUATION], charsmax(eSpeaker[SPEAKER_ATTENUATION]))
                        else if ( equali(szKey, "SPEAKER_SONG") )
                        {
                            parseSetting(DTYPE_ARRAY_SOUND, szValue, charsmax(szValue), eSpeaker[SPEAKER_SONG], charsmax(eSpeaker[SPEAKER_SONG]))
                            parseDuration(eSpeaker, szValue)
                        }
                    }
                }
            }
        }
    }

    if ( g_iSpeakerConfig )
        ArrayPushArray(g_aSpeakerConfig, eSpeaker)
    else
        set_fail_state("No Speakers were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_disconnected(id)
{
    new eSpeaker[SPEAKER], iItem
    if ( g_ePlayerData[id][PDATA_SPEAKER_GHOST]
    && (iItem = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_GHOST])) != -1 )
    {
        speakerKill(eSpeaker[SPEAKER_ID])
        speakerRemove(iItem)
    }

    DisableAction(id)
    g_ePlayerData[id][PDATA_SPEAKER_GHOST]  = 0
    g_ePlayerData[id][PDATA_SPEAKER_MENU]   = 0
}

stock speakerInit()
{
    if ( g_eSettings[SETTING_SPEAKER_LOAD] )
        set_task(DELAY_ON_LOAD, "loadData")
}

stock speakerMenu(id, iType)
{
    if ( !is_user_connected(id) )
        return PLUGIN_HANDLED

    new szData[256], iMenu
    formatex(szData, charsmax(szData), "%L", id, "SPEAKER_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])
    switch( iType )
    {
        case MENU_ROOT:             { menuRoot(id, iMenu); }
        case MENU_CREATE:           { menuCreate(iMenu);            format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_CREATE"); }
        case MENU_EDIT:             { menuEdit(id, iMenu);          format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_EDIT"); }
        case MENU_REMOVE:           { menuRemove(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_REMOVE"); }
        case MENU_SHOW:             { menuShow(id, iMenu);          format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_SHOW"); }
        case MENU_STATUS:           { menuStatus(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_STATUS"); }
        case MENU_ROTATE:           { menuRotate(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_ROTATE"); }
        case MENU_SPEAKER:          { menuSpeaker(id, iMenu);       format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_SPEAKER"); }
        case MENU_SPEAKER_SONG:     { menuSpeakerSong(id, iMenu);   format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_SPEAKER_SONG"); }
        case MENU_SPEAKER_VOLUME:   { menuSpeakerVolume(id, iMenu); format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_ROOT_SPEAKER_VOLUME"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "SPEAKER_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROOT_EDIT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROOT_NOCLIP", id, get_user_noclip(id) ? "SPEAKER_ON" : "SPEAKER_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROOT_GODMODE", id, get_user_godmode(id) ? "SPEAKER_ON" : "SPEAKER_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iSpeaker >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_LIMIT", MAX_ENT)

                speakerSound(id, SOUND_MENU_REMOVE)
                speakerMenu(id, MENU_ROOT)
            }
            else
            {
                speakerSound(id, SOUND_MENU_NAV)
                speakerMenu(id, MENU_CREATE)
            }
        }
        case ROOT_EDIT:
        {
            if ( !g_iSpeaker )
            {
                client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_NO_SPEAKER")

                speakerSound(id, SOUND_MENU_REMOVE)
                speakerMenu(id, MENU_ROOT)
            }
            else
            {
                speakerSound(id, SOUND_MENU_NAV)
                speakerMenu(id, MENU_EDIT)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iSpeaker )
            {
                client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_NO_SPEAKER")

                speakerSound(id, SOUND_MENU_REMOVE)
                speakerMenu(id, MENU_ROOT)
            }
            else
            {
                speakerSound(id, SOUND_MENU_REMOVE)
                speakerMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            speakerNoClip(id)
        }
        case ROOT_GODMODE:
        {
            speakerGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
{
    new eSpeaker[SPEAKER], szItem[64]
    for ( new i = 0; i < g_iSpeakerConfig; i ++ )
    {
        ArrayGetArray(g_aSpeakerConfig, i, eSpeaker)

        copy(szItem, charsmax(szItem), eSpeaker[SPEAKER_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    else if ( item == MENU_EXIT )
    {
        speakerSound(id, SOUND_MENU_NAV)
        speakerMenu(id, MENU_ROOT)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    speakerCreate(id, item)
    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuEdit(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_EDIT_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_EDIT_STATUS")
    menu_additem(iMenu, szItem)
}

public menuHandlerEdit(id, menu, item)
{
    switch( item )
    {
        case EDIT_SHOW:
        {
            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SHOW)
        }
        case EDIT_STATUS:
        {
            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_ROOT)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eSpeaker[SPEAKER]
    menuNav(id, iMenu)
    ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_REMOVE_CURRENT", eSpeaker[SPEAKER_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    speakerSelect(eSpeaker, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    ArraySetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
}

public menuHandlerRemove(id, menu, item)
{
    new eSpeaker[SPEAKER]
    ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        speakerSelect(eSpeaker, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_SPEAKER_MENU] >= g_iSpeaker - 1 )
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_SPEAKER_MENU] ++

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_SPEAKER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = g_iSpeaker - 1
            else
                g_ePlayerData[id][PDATA_SPEAKER_MENU] --

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            eSpeaker[SPEAKER_FLAGS] &= ~FLAG_ACTIVE
            speakerSetState(eSpeaker)
            speakerKill(eSpeaker[SPEAKER_ID])
            speakerRemove(g_ePlayerData[id][PDATA_SPEAKER_MENU])

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_REMOVE_CURRENT", eSpeaker[SPEAKER_NAME])
            g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0

            speakerSound(id, g_iSpeaker > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            speakerMenu(id, g_iSpeaker > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iSpeaker )
            {
                ArrayGetArray(g_aSpeaker, 0, eSpeaker)
                eSpeaker[SPEAKER_FLAGS] &= ~FLAG_ACTIVE

                speakerSetState(eSpeaker)
                speakerKill(eSpeaker[SPEAKER_ID])
                speakerRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0

            speakerSound(id, SOUND_MENU_ALERT)
            speakerMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                speakerSound(id, SOUND_MENU_NAV)
                speakerMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuShow(id, iMenu)
{
    new szItem[64], eSpeaker[SPEAKER]
    menuNav(id, iMenu)
    ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SHOW_CURRENT",
    eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? "\y" : "\r", eSpeaker[SPEAKER_NAME], id, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? "SPEAKER_SHOWN" : "SPEAKER_HIDDEN")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SHOW_ALL_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SHOW_ALL_HIDE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    speakerSelect(eSpeaker, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_SHOW
    ArraySetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
}

public menuHandlerShow(id, menu, item)
{
    new eSpeaker[SPEAKER]
    ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        speakerSelect(eSpeaker, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

    switch( item )
    {
        case SHOW_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_SPEAKER_MENU] >= g_iSpeaker - 1 )
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_SPEAKER_MENU] ++

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SHOW)
        }
        case SHOW_BACK:
        {
            if ( g_ePlayerData[id][PDATA_SPEAKER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = g_iSpeaker - 1
            else
                g_ePlayerData[id][PDATA_SPEAKER_MENU] --

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SHOW)
        }
        case SHOW_CURRENT:
        {
            eSpeaker[SPEAKER_FLAGS] ^= FLAG_SHOW
            if ( eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW )
                eSpeaker[SPEAKER_FLAGS] |= FLAG_ACTIVE
            else
                eSpeaker[SPEAKER_FLAGS] &= ~FLAG_ACTIVE
            speakerSetState(eSpeaker)

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_SHOW_CURRENT",
            eSpeaker[SPEAKER_NAME], id, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? "SPEAKER_CHAT_SHOWN" : "SPEAKER_CHAT_HIDDEN")
            ArraySetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_SHOW:
        {
            for ( new i = 0; i < g_iSpeaker; i ++ )
            {
                ArrayGetArray(g_aSpeaker, i, eSpeaker)
                eSpeaker[SPEAKER_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
                speakerSetState(eSpeaker)

                ArraySetArray(g_aSpeaker, i, eSpeaker)
            }

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_SHOW_ALL_SHOWN")
            speakerSound(id, SOUND_MENU_ALERT)
            speakerMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_HIDE:
        {
            for ( new i = 0; i < g_iSpeaker; i ++ )
            {
                ArrayGetArray(g_aSpeaker, i, eSpeaker)
                eSpeaker[SPEAKER_FLAGS] &= ~(FLAG_SHOW | FLAG_ACTIVE)
                speakerSetState(eSpeaker)

                ArraySetArray(g_aSpeaker, i, eSpeaker)
            }

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_SHOW_ALL_HIDDEN")
            speakerSound(id, SOUND_MENU_ALERT)
            speakerMenu(id, MENU_SHOW)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                speakerSound(id, SOUND_MENU_NAV)
                speakerMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eSpeaker[SPEAKER]
    menuNav(id, iMenu)
    ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_STATUS_CURRENT",
    eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE ? "\y" : "\r", eSpeaker[SPEAKER_NAME], id, eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE ? "SPEAKER_ENABLED" : "SPEAKER_DISABLED")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    speakerSelect(eSpeaker, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_STATUS
    ArraySetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
}

public menuHandlerStatus(id, menu, item)
{
    new eSpeaker[SPEAKER]
    ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        speakerSelect(eSpeaker, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_SPEAKER_MENU] >= g_iSpeaker - 1 )
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_SPEAKER_MENU] ++

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_SPEAKER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = g_iSpeaker - 1
            else
                g_ePlayerData[id][PDATA_SPEAKER_MENU] --

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            eSpeaker[SPEAKER_FLAGS] ^= FLAG_ACTIVE
            speakerSetState(eSpeaker)

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_STATUS_CURRENT",
            eSpeaker[SPEAKER_NAME], id, eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE ? "SPEAKER_CHAT_ENABLED" : "SPEAKER_CHAT_DISABLED")
            ArraySetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iSpeaker; i ++ )
            {
                ArrayGetArray(g_aSpeaker, i, eSpeaker)
                eSpeaker[SPEAKER_FLAGS] |= FLAG_ACTIVE
                speakerSetState(eSpeaker)

                ArraySetArray(g_aSpeaker, i, eSpeaker)
            }

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_STATUS_ALL_ENABLED")
            speakerSound(id, SOUND_MENU_ALERT)
            speakerMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iSpeaker; i ++ )
            {
                ArrayGetArray(g_aSpeaker, i, eSpeaker)
                eSpeaker[SPEAKER_FLAGS] &= ~FLAG_ACTIVE
                speakerSetState(eSpeaker)

                ArraySetArray(g_aSpeaker, i, eSpeaker)
            }

            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_STATUS_ALL_DISABLED")
            speakerSound(id, SOUND_MENU_ALERT)
            speakerMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                speakerSound(id, SOUND_MENU_NAV)
                speakerMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64], eSpeaker[SPEAKER]
    if ( speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_GHOST]) == -1 )
    {
        menu_destroy(iMenu)
        return
    }

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROTATE_UP")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROTATE_DOWN")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROTATE_GROUND",
    id, eSpeaker[SPEAKER_FLAGS] & FLAG_GROUND ? "SPEAKER_ON" : "SPEAKER_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new eSpeaker[SPEAKER], iItem
    if ( (iItem = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROTATE_UP:
        {
            pev(eSpeaker[SPEAKER_ID], pev_angles, eSpeaker[SPEAKER_ANGLES])
            eSpeaker[SPEAKER_ANGLES][1] -= g_eSettings[SETTING_ROTATION_STEP]
            if ( eSpeaker[SPEAKER_ANGLES][1] < -180.0 ) eSpeaker[SPEAKER_ANGLES][1] += 360.0

            set_pev(eSpeaker[SPEAKER_ID], pev_angles, eSpeaker[SPEAKER_ANGLES])
            ArraySetArray(g_aSpeaker, iItem, eSpeaker)

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_ROTATE)
        }
        case ROTATE_DOWN:
        {
            pev(eSpeaker[SPEAKER_ID], pev_angles, eSpeaker[SPEAKER_ANGLES])
            eSpeaker[SPEAKER_ANGLES][1] += g_eSettings[SETTING_ROTATION_STEP]
            if ( eSpeaker[SPEAKER_ANGLES][1] > 180.0 ) eSpeaker[SPEAKER_ANGLES][1] -= 360.0

            set_pev(eSpeaker[SPEAKER_ID], pev_angles, eSpeaker[SPEAKER_ANGLES])
            ArraySetArray(g_aSpeaker, iItem, eSpeaker)

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_ROTATE)
        }
        case ROTATE_GROUND:
        {
            eSpeaker[SPEAKER_FLAGS] ^= FLAG_GROUND
            ArraySetArray(g_aSpeaker, iItem, eSpeaker)

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            speakerTrace(eSpeaker, id)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_SPEAKER_GHOST] = 0

            eSpeaker[SPEAKER_FLAGS] &= ~FLAG_GHOST
            eSpeaker[SPEAKER_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
            eSpeaker[SPEAKER_ANGLES][0] = -eSpeaker[SPEAKER_ANGLES][0]
            speakerSetSize(eSpeaker)
            speakerSetState(eSpeaker)
            client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_CREATE_NEW", eSpeaker[SPEAKER_NAME])

            ArraySetArray(g_aSpeaker, iItem, eSpeaker)
            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_CREATE)
        }
        case MENU_EXIT:
        {
            speakerKill(eSpeaker[SPEAKER_ID])
            speakerRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_SPEAKER_GHOST] = 0

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_CREATE)
        }
        default:
        {
            speakerKill(eSpeaker[SPEAKER_ID])
            speakerRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_SPEAKER_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuSpeaker(id, iMenu)
{
    new eSpeaker[SPEAKER], szItem[64], iItem
    if ( (iItem = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID])) == -1 )
        return

    new Float:fElapsed, Float:fDuration
    fDuration = Float:ArrayGetCell(eSpeaker[SPEAKER_SONG_DURATION], iItem)
    fElapsed  = floatclamp(fDuration - (Float:eSpeaker[SPEAKER_NEXT_SONG] - get_gametime()), 0.0, fDuration)

    formatex(szItem, charsmax(szItem), "\d%d:%02d / %d:%02d",
    floatround(fElapsed) / 60, floatround(fElapsed) % 60, floatround(fDuration) / 60, floatround(fDuration) % 60)
    menu_addtext2(iMenu, szItem)
    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SPEAKER_SONG")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SPEAKER_VOLUME")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SPEAKER_MODE", id, g_szSpeakerMode[eSpeaker[SPEAKER_MODE]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_SPEAKER_POWER", id, eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE ? "SPEAKER_ON" : "SPEAKER_OFF")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_SPEAKER_REFRESH] = true
}

public menuHandlerSpeaker(id, menu, item)
{
    new eSpeaker[SPEAKER], iItem
    if ( (iItem = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case SPEAKER_SPEAKER_SONG:
        {
            g_ePlayerData[id][PDATA_SPEAKER_REFRESH] = false

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SPEAKER_SONG)
        }
        case SPEAKER_SPEAKER_VOLUME:
        {
            g_ePlayerData[id][PDATA_SPEAKER_REFRESH] = false

            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SPEAKER_VOLUME)
        }
        case SPEAKER_SPEAKER_MODE:
        {
            if ( ++ eSpeaker[SPEAKER_MODE] > MODE_RANDOM )
                eSpeaker[SPEAKER_MODE] = MODE_LOOP

            ArraySetArray(g_aSpeaker, iItem, eSpeaker)
            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SPEAKER)
        }
        case SPEAKER_SPEAKER_POWER:
        {
            eSpeaker[SPEAKER_FLAGS] ^= FLAG_ACTIVE
            speakerSetState(eSpeaker)

            ArraySetArray(g_aSpeaker, iItem, eSpeaker)
            speakerSound(id, SOUND_MENU_NAV)
            speakerMenu(id, MENU_SPEAKER)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_SPEAKER_REFRESHING] )
                g_ePlayerData[id][PDATA_SPEAKER_REFRESH] = false
        }
        default:
        {
            if ( !g_ePlayerData[id][PDATA_SPEAKER_REFRESHING] )
                g_ePlayerData[id][PDATA_SPEAKER_REFRESH] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuSpeakerSong(id, iMenu)
{
    new eSpeaker[SPEAKER]
    if ( speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID]) == -1 )
        return

    new szSound[MAX_RESOURCE_PATH_LENGTH], szName[MAX_VALUE_LENGTH], szItem[128], iPos
    for ( new i = 0; i < eSpeaker[SPEAKER_SONG_COUNT]; i ++ )
    {
        ArrayGetString(eSpeaker[SPEAKER_SONG], i, szSound, charsmax(szSound))
        iPos = strlen(szSound)
        while ( -- iPos >= 0 && szSound[iPos] != '/' ) { }

        copy(szName, charsmax(szName), szSound[iPos + 1])
        if ( (iPos = containi(szName, ".wav")) != -1 )
            szName[iPos] = EOS

        formatex(szItem, charsmax(szItem), "%s \d(%.1fs)", szName, Float:ArrayGetCell(eSpeaker[SPEAKER_SONG_DURATION], i))
        menu_additem(iMenu, szItem, .callback = g_iSongCallback)
    }
}

public menuHandlerSpeakerSongItem(id, menu, item)
{
    new eSpeaker[SPEAKER]
    if ( speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID]) == -1 )
        return ITEM_IGNORE

    return item == eSpeaker[SPEAKER_CURRENT_SONG_ID] ? ITEM_DISABLED : ITEM_IGNORE
}

public menuHandlerSpeakerSong(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        speakerSound(id, SOUND_MENU_NAV)
        speakerMenu(id, MENU_SPEAKER)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new eSpeaker[SPEAKER], iItem
    if ( (iItem = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    eSpeaker[SPEAKER_CURRENT_SONG_ID] = item
    engfunc(EngFunc_EmitAmbientSound, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN], eSpeaker[SPEAKER_CURRENT_SONG], eSpeaker[SPEAKER_CURRENT_VOLUME] / 100.0, eSpeaker[SPEAKER_ATTENUATION], SND_STOP, 120)
    speakerSpeaker(eSpeaker)
    ArraySetArray(g_aSpeaker, iItem, eSpeaker)

    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_SPEAKER_SONG)
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuSpeakerVolume(id, iMenu)
{
    new eSpeaker[SPEAKER]
    if ( speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID]) == -1 )
        return

    new szItem[64], szBar[32] = "\y", iBars = floatround(eSpeaker[SPEAKER_CURRENT_VOLUME] / VOLUME_STEP)
    for ( new i = 0; i < 100 / VOLUME_STEP; i ++ )
    {
        if ( i == iBars )
            add(szBar, charsmax(szBar), "\d|")
        else
            add(szBar, charsmax(szBar), "|")
    }

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_VOLUME_CURRENT", szBar, eSpeaker[SPEAKER_CURRENT_VOLUME])
    menu_addtext2(iMenu, szItem)
    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_VOLUME_UP")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "SPEAKER_VOLUME_DOWN")
    menu_additem(iMenu, szItem)
}

public menuHandlerSpeakerVolume(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        speakerSound(id, SOUND_MENU_NAV)
        speakerMenu(id, MENU_SPEAKER)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new eSpeaker[SPEAKER], iSpeaker
    if ( (iSpeaker = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_ID])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    eSpeaker[SPEAKER_CURRENT_VOLUME] = floatclamp(eSpeaker[SPEAKER_CURRENT_VOLUME] + (item == VOLUME_UP ? VOLUME_STEP : -VOLUME_STEP), 0.0, 100.0)
    ArraySetArray(g_aSpeaker, iSpeaker, eSpeaker)
    if ( eSpeaker[SPEAKER_CURRENT_SONG][0] )
        engfunc(EngFunc_EmitAmbientSound, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN], eSpeaker[SPEAKER_CURRENT_SONG], eSpeaker[SPEAKER_CURRENT_VOLUME] / 100.0, eSpeaker[SPEAKER_ATTENUATION], SND_CHANGE_VOL, 120)

    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_SPEAKER_VOLUME)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public speakerTask()
{
    new eSpeaker[SPEAKER], bool:bModified, Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new i = 0; i < g_iSpeaker; i ++ )
    {
        ArrayGetArray(g_aSpeaker, i, eSpeaker)
        bModified = false

        if ( eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE )
        {
            if ( eSpeaker[SPEAKER_FLAGS] & FLAG_SHAKE )
                speakerShake(eSpeaker)

            if ( fCurrentTime >= eSpeaker[SPEAKER_NEXT_SONG] )
            {
                if ( eSpeaker[SPEAKER_MODE] != MODE_LOOP )
                    if ( ++ eSpeaker[SPEAKER_CURRENT_SONG_ID] >= eSpeaker[SPEAKER_SONG_COUNT] )
                        eSpeaker[SPEAKER_CURRENT_SONG_ID] = 0

                engfunc(EngFunc_EmitAmbientSound, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN], eSpeaker[SPEAKER_CURRENT_SONG], eSpeaker[SPEAKER_CURRENT_VOLUME] / 100.0, eSpeaker[SPEAKER_ATTENUATION], SND_STOP, 120)
                speakerSpeaker(eSpeaker)
                bModified = true
            }
        }

        if ( bModified )
            ArraySetArray(g_aSpeaker, i, eSpeaker)
    }

    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id)
        || !g_ePlayerData[id][PDATA_SPEAKER_REFRESH]
        || fCurrentTime < g_ePlayerData[id][PDATA_NEXT_REFRESH] )
            continue

        g_ePlayerData[id][PDATA_SPEAKER_REFRESHING] = true
        speakerMenu(id, MENU_SPEAKER)
        g_ePlayerData[id][PDATA_SPEAKER_REFRESHING] = false
        g_ePlayerData[id][PDATA_NEXT_REFRESH] = fCurrentTime + REFRESH_RATE
    }
}

stock speakerCreate(id, iItem)
{
    new iEnt = cs_create_entity("info_target")
    if ( !pev_valid(iEnt) )
        return

    new eSpeaker[SPEAKER]
    ArrayGetArray(g_aSpeakerConfig, iItem, eSpeaker)
    eSpeaker[SPEAKER_ID] = iEnt
    eSpeaker[SPEAKER_ITEM] = iItem
    eSpeaker[SPEAKER_SONG] = ArrayClone(eSpeaker[SPEAKER_SONG])
    eSpeaker[SPEAKER_SONG_DURATION] = ArrayClone(eSpeaker[SPEAKER_SONG_DURATION])
    if ( id )
    {
        EnableAction(id)
        g_ePlayerData[id][PDATA_SPEAKER_GHOST] = eSpeaker[SPEAKER_ID]
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]

        eSpeaker[SPEAKER_FLAGS] |= FLAG_GHOST
        eSpeaker[SPEAKER_CURRENT_VOLUME] = 100.0
    }

    speakerSelect(eSpeaker, TARGET_GHOST)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_impulse, SPEAKER_KEY)
    set_pev(iEnt, SPEAKER_ARRAY_ITEM, g_iSpeaker)
    dllfunc(DLLFunc_Spawn, iEnt)
    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_DEFAULT_MODEL])

    ArrayPushArray(g_aSpeaker, eSpeaker)
    if ( ++ g_iSpeaker == 1 )
    {
        set_task(g_eSettings[SETTING_SPEAKER_TASK], "speakerTask", SPEAKER_KEY, .flags = "b")
        EnableSpeaker()
    }
}

public speakerRemove(iItem)
{
    new eSpeaker[SPEAKER]
    ArrayGetArray(g_aSpeaker, iItem, eSpeaker)
    ArrayDestroy(eSpeaker[SPEAKER_SONG])
    ArrayDestroy(eSpeaker[SPEAKER_SONG_DURATION])
    ArrayDeleteItem(g_aSpeaker, iItem)

    if ( -- g_iSpeaker == 0 )
    {
        remove_task(SPEAKER_KEY)
        DisableSpeaker()
    }

    for ( new i = iItem; i < g_iSpeaker; i ++ )
    {
        ArrayGetArray(g_aSpeaker, i, eSpeaker)
        set_pev(eSpeaker[SPEAKER_ID], SPEAKER_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eSpeaker[SPEAKER],
        szFile[128], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_Speaker.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iSpeaker; i ++ )
    {
        ArrayGetArray(g_aSpeaker, i, eSpeaker)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eSpeaker[SPEAKER_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "flags = %d^n", eSpeaker[SPEAKER_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "volume = %.2f^n", eSpeaker[SPEAKER_CURRENT_VOLUME])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eSpeaker[SPEAKER_ORIGIN][0], eSpeaker[SPEAKER_ORIGIN][1], eSpeaker[SPEAKER_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        eSpeaker[SPEAKER_ANGLES][0], eSpeaker[SPEAKER_ANGLES][1], eSpeaker[SPEAKER_ANGLES][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "SPEAKER_CHAT_TAG", id, "SPEAKER_CHAT_SAVE", szFile)
    fclose(iFile)

    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem, iFlags, Float:fVolume, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_Speaker.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                LoadDataSpeaker(iItem, iFlags, fVolume, fOrigin, fAngles, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
            else if ( equal(szKey, "volume") )
            {
                fVolume = str_to_float(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
        }
    }

    if ( iCount != -1 )
        LoadDataSpeaker(iItem, iFlags, fVolume, fOrigin, fAngles, iCount)

    fclose(iFile)
}

stock LoadDataSpeaker(iItem, iFlags, Float:fVolume, Float:fOrigin[3], Float:fAngles[3], iCount)
{
    new eSpeaker[SPEAKER]
    speakerCreate(0, iItem)
    ArrayGetArray(g_aSpeaker, iCount, eSpeaker)

    eSpeaker[SPEAKER_FLAGS] = iFlags
    eSpeaker[SPEAKER_CURRENT_VOLUME] = fVolume
    fAngles[0] = -fAngles[0]
    xs_vec_copy(fOrigin, eSpeaker[SPEAKER_ORIGIN])
    xs_vec_copy(fAngles, eSpeaker[SPEAKER_ANGLES])

    speakerSetBox(eSpeaker)
    speakerSetSize(eSpeaker)
    speakerSetState(eSpeaker)
    ArraySetArray(g_aSpeaker, iCount, eSpeaker)
}

public speakerNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_ROOT)
}

public speakerGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    speakerSound(id, SOUND_MENU_NAV)
    speakerMenu(id, MENU_ROOT)
}

public fwdEmitSound(iEnt, iChannel, const szSample[])
{
    return FMRES_IGNORED
}

public fwdUse(iEnt, iCaller, iActivator, iType, Float:fValue)
{
    if ( !isSpeaker(iEnt)
    || !is_user_alive(iActivator) )
        return HAM_IGNORED

    new eSpeaker[SPEAKER]
    if ( speakerGet(eSpeaker, iEnt) == -1
    || !(eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE)
    || !(get_user_flags(iActivator) & eSpeaker[SPEAKER_USE_FLAGS])
    || !(CsTeams:eSpeaker[SPEAKER_USE_TEAM] & cs_get_user_team(iActivator)) )
        return HAM_IGNORED

    g_ePlayerData[iActivator][PDATA_SPEAKER_ID] = iEnt
    speakerMenu(iActivator, MENU_SPEAKER)
    return HAM_IGNORED
}

public fwdObjectCaps(iEnt)
{
    if ( !isSpeaker(iEnt) )
        return GetHamReturnStatus() == HAM_SUPERCEDE ? HAM_SUPERCEDE : HAM_IGNORED

    SetHamReturnInteger(FCAP_IMPULSE_USE)
    return HAM_SUPERCEDE
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eSpeaker[SPEAKER], iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_GHOST]) != -1 )
    {
        if ( g_ePlayerData[id][PDATA_SPEAKER_GHOST] )
        {
            if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
            {
                if ( iButton & IN_ATTACK )
                {
                    g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                    g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                    g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
                }
                else if ( iButton & IN_ATTACK2 )
                {
                    g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                    g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                    g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
                }
            }

            set_pdata_float(id, PDATA_NEXT_ATTACK, fCurrentTime + 0.1, XO_CBASEPLAYER, XO_CBASEPLAYER)
            iButton &= ~(IN_ATTACK | IN_ATTACK2)
            set_pev(id, pev_button, iButton)

            speakerTrace(eSpeaker, id)
        }
    }
    else if ( g_ePlayerData[id][PDATA_SPEAKER_ACTION] )
    {
        speakerCheck(id)
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    DisableAction(id)
    g_ePlayerData[id][PDATA_SPEAKER_MENU] = 0
    if ( g_ePlayerData[id][PDATA_SPEAKER_GHOST] )
    {
        new eSpeaker[SPEAKER], iItem
        if ( (iItem = speakerGet(eSpeaker, g_ePlayerData[id][PDATA_SPEAKER_GHOST])) != -1 )
        {
            speakerKill(eSpeaker[SPEAKER_ID])
            speakerRemove(iItem)
        }

        g_ePlayerData[id][PDATA_SPEAKER_GHOST] = 0
    }
}

stock speakerTrace(eSpeaker[SPEAKER], id)
{
    new Float:fVec1[3]
    pev(id, pev_origin, eSpeaker[SPEAKER_ORIGIN])
    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eSpeaker[SPEAKER_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eSpeaker[SPEAKER_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eSpeaker[SPEAKER_ORIGIN])

    speakerSetBox(eSpeaker)
    speakerSetOffset(eSpeaker)
    set_pev(eSpeaker[SPEAKER_ID], pev_origin, eSpeaker[SPEAKER_ORIGIN])
}

stock speakerCheck(id)
{
    new eSpeaker[SPEAKER], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3], Float:fMins[3], Float:fMaxs[3], Float:fNearest[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = g_eSettings[SETTING_SPEAKER_CHECK]
    for ( new i = 0; i < g_iSpeaker; i ++ )
    {
        ArrayGetArray(g_aSpeaker, i, eSpeaker)
        xs_vec_sub(eSpeaker[SPEAKER_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        pev(eSpeaker[SPEAKER_ID], pev_absmin, fMins)
        pev(eSpeaker[SPEAKER_ID], pev_absmax, fMaxs)
        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)

        fNearest[0] = floatclamp(fVec3[0], fMins[0], fMaxs[0])
        fNearest[1] = floatclamp(fVec3[1], fMins[1], fMaxs[1])
        fNearest[2] = floatclamp(fVec3[2], fMins[2], fMaxs[2])
        fDist = get_distance_f(fVec3, fNearest)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_SPEAKER_MENU] != iBest )
    {
        ArrayGetArray(g_aSpeaker, g_ePlayerData[id][PDATA_SPEAKER_MENU], eSpeaker)
        speakerSelect(eSpeaker, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

        g_ePlayerData[id][PDATA_MENU_TRACE] = true
        g_ePlayerData[id][PDATA_SPEAKER_MENU] = iBest
        speakerMenu(id, g_ePlayerData[id][PDATA_MENU_TYPE])
    }
}

stock speakerShake(eSpeaker[SPEAKER])
{
    new Float:fOrigin[3]
    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        pev(id, pev_origin, fOrigin)
        if ( xs_vec_distance(fOrigin, eSpeaker[SPEAKER_ORIGIN]) > g_eSettings[SETTING_DEFAULT_SHAKE_DISTANCE] )
            continue

        message_begin(MSG_ONE_UNRELIABLE, g_iScreenShake, .player = id)
        write_short(g_eSettings[SETTING_DEFAULT_SHAKE_AMPLITUDE] * 4096)
        write_short(g_eSettings[SETTING_DEFAULT_SHAKE_DURATION] * 4096)
        write_short(g_eSettings[SETTING_DEFAULT_SHAKE_FREQUENCY] * 4096)
        message_end()
    }
}

stock speakerSetBox(eSpeaker[SPEAKER])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    eSpeaker[SPEAKER_ANGLES][0] = -eSpeaker[SPEAKER_ANGLES][0]
    engfunc(EngFunc_AngleVectors, eSpeaker[SPEAKER_ANGLES], fForward, fRight, fUp)
    xs_vec_copy(g_eSettings[SETTING_MINS], fMins)
    xs_vec_copy(g_eSettings[SETTING_MAXS], fMaxs)

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
        fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
        fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]

        boxRotate(fCorners[i], fForward, fRight, fUp)
    }

    xs_vec_copy(fCorners[0], fMins)
    xs_vec_copy(fCorners[0], fMaxs)
    for ( new i = 1; i < 8; i ++ )
    {
        fMins[0] = floatmin(fMins[0], fCorners[i][0])
        fMins[1] = floatmin(fMins[1], fCorners[i][1])
        fMins[2] = floatmin(fMins[2], fCorners[i][2])

        fMaxs[0] = floatmax(fMaxs[0], fCorners[i][0])
        fMaxs[1] = floatmax(fMaxs[1], fCorners[i][1])
        fMaxs[2] = floatmax(fMaxs[2], fCorners[i][2])
    }

    xs_vec_copy(fMins, eSpeaker[SPEAKER_MINS])
    xs_vec_copy(fMaxs, eSpeaker[SPEAKER_MAXS])
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] - fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] - fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] - fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock speakerSetOffset(eSpeaker[SPEAKER])
{
    new Float:fGaps[6], Float:fVec1[3], Float:fCurrentGap
    fGaps[0] = -eSpeaker[SPEAKER_MINS][0]
    fGaps[1] = eSpeaker[SPEAKER_MAXS][0]
    fGaps[2] = -eSpeaker[SPEAKER_MINS][1]
    fGaps[3] = eSpeaker[SPEAKER_MAXS][1]
    fGaps[4] = -eSpeaker[SPEAKER_MINS][2]
    fGaps[5] = eSpeaker[SPEAKER_MAXS][2]

    if ( eSpeaker[SPEAKER_FLAGS] & FLAG_GROUND )
    {
        xs_vec_sub(eSpeaker[SPEAKER_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
        engfunc(EngFunc_TraceLine, eSpeaker[SPEAKER_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eSpeaker[SPEAKER_ID], 0)
        get_tr2(0, TR_vecEndPos, eSpeaker[SPEAKER_ORIGIN])
    }

    for ( new i = 5; i >= 0; i -- )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eSpeaker[SPEAKER_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eSpeaker[SPEAKER_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eSpeaker[SPEAKER_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eSpeaker[SPEAKER_ORIGIN], fVec1)

        if ( fCurrentGap < fGaps[i] )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, fGaps[i] - fCurrentGap, fVec1)
            xs_vec_add(eSpeaker[SPEAKER_ORIGIN], fVec1, eSpeaker[SPEAKER_ORIGIN])
        }
    }
}

stock speakerSetSize(eSpeaker[SPEAKER])
{
    speakerSelect(eSpeaker, TARGET_CLEAR)
    engfunc(EngFunc_SetOrigin, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN])
    set_pev(eSpeaker[SPEAKER_ID], pev_angles, eSpeaker[SPEAKER_ANGLES])
    set_pev(eSpeaker[SPEAKER_ID], pev_solid, eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW ? SOLID_BBOX : SOLID_NOT)
    set_pev(eSpeaker[SPEAKER_ID], pev_movetype, MOVETYPE_NONE)

    engfunc(EngFunc_SetSize, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_MINS], eSpeaker[SPEAKER_MAXS])
    speakerSpeaker(eSpeaker)
}

stock speakerSetState(eSpeaker[SPEAKER])
{
    if ( eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW )
    {
        set_pev(eSpeaker[SPEAKER_ID], pev_solid, SOLID_BBOX)
        speakerSelect(eSpeaker, TARGET_CLEAR)

        if ( !(eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE) )
        {
            eSpeaker[SPEAKER_NEXT_SONG] = 0.0
            engfunc(EngFunc_EmitAmbientSound, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN], eSpeaker[SPEAKER_CURRENT_SONG], eSpeaker[SPEAKER_CURRENT_VOLUME] / 100.0, eSpeaker[SPEAKER_ATTENUATION], SND_STOP, 120)
        }
        else if ( !eSpeaker[SPEAKER_NEXT_SONG] )
            speakerSpeaker(eSpeaker)
    }
    else
    {
        set_pev(eSpeaker[SPEAKER_ID], pev_solid, SOLID_NOT)
        speakerSelect(eSpeaker, TARGET_HIDE)

        eSpeaker[SPEAKER_NEXT_SONG] = 0.0
        engfunc(EngFunc_EmitAmbientSound, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN], eSpeaker[SPEAKER_CURRENT_SONG], eSpeaker[SPEAKER_CURRENT_VOLUME] / 100.0, eSpeaker[SPEAKER_ATTENUATION], SND_STOP, 120)
    }
}

stock speakerSelect(eSpeaker[SPEAKER], iAction)
{
    new iRenderColor[3]
    if ( iAction == TARGET_SELECT )
    {
        if ( eSpeaker[SPEAKER_FLAGS] & FLAG_ACTIVE )    { iRenderColor[0] = g_iColorActive[0];    iRenderColor[1] = g_iColorActive[1];    iRenderColor[2] = g_iColorActive[2]; }
        else                                            { iRenderColor[0] = g_iColorInactive[0];  iRenderColor[1] = g_iColorInactive[1];  iRenderColor[2] = g_iColorInactive[2]; }

        set_ent_rendering(eSpeaker[SPEAKER_ID], kRenderFxGlowShell, iRenderColor[0], iRenderColor[1], iRenderColor[2], kRenderTransAlpha, 16)
    }
    else if ( iAction == TARGET_GHOST )
    {
        set_ent_rendering(eSpeaker[SPEAKER_ID], kRenderFxNone, 255, 255, 255, kRenderTransAlpha, g_eSettings[SETTING_GHOST_ALPHA])
    }
    else if ( iAction == TARGET_HIDE )
    {
        set_ent_rendering(eSpeaker[SPEAKER_ID], kRenderFxNone, 255, 255, 255, kRenderTransAlpha, 0)
    }
    else if ( iAction == TARGET_CLEAR )
    {
        set_ent_rendering(eSpeaker[SPEAKER_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
    }
}

stock speakerSound(iEnt, iSound, bool:bPlayer = true)
{
    new szSample[64]
    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), SOUND_NAV)
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), SOUND_REMOVE)
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), SOUND_ALERT)
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, 120)
}

stock speakerSpeaker(eSpeaker[SPEAKER])
{
    new szSound[MAX_RESOURCE_PATH_LENGTH], iIndex, Float:fDuration
    iIndex = eSpeaker[SPEAKER_MODE] == MODE_RANDOM ? random_num(0, eSpeaker[SPEAKER_SONG_COUNT] - 1) : eSpeaker[SPEAKER_CURRENT_SONG_ID]
    ArrayGetString(eSpeaker[SPEAKER_SONG], iIndex, szSound, charsmax(szSound))
    fDuration = Float:ArrayGetCell(eSpeaker[SPEAKER_SONG_DURATION], iIndex)
    if ( fDuration <= 0.0 )
        fDuration = 1.0

    copy(eSpeaker[SPEAKER_CURRENT_SONG], charsmax(eSpeaker[SPEAKER_CURRENT_SONG]), szSound)
    engfunc(EngFunc_EmitAmbientSound, eSpeaker[SPEAKER_ID], eSpeaker[SPEAKER_ORIGIN], szSound, eSpeaker[SPEAKER_CURRENT_VOLUME] / 100.0, eSpeaker[SPEAKER_ATTENUATION], 0, PITCH_NORM)
    eSpeaker[SPEAKER_NEXT_SONG] = get_gametime() + fDuration
}

stock speakerReset()
{
    new eSpeaker[SPEAKER]
    for ( new i = 0; i < g_iSpeaker; i ++ )
    {
        ArrayGetArray(g_aSpeaker, i, eSpeaker)
        ArraySetArray(g_aSpeaker, i, eSpeaker)
    }

    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
        g_ePlayerData[id][PDATA_NEXT_REFRESH] = 0.0
}

stock speakerGet(eSpeaker[SPEAKER], iEnt)
{
    if ( !isSpeaker(iEnt) )
        return -1

    new iItem
    iItem = pev(iEnt, SPEAKER_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iSpeaker )
        return -1

    ArrayGetArray(g_aSpeaker, iItem, eSpeaker)
    return iItem
}

stock bool:isSpeaker(iEnt)
{
    return pev_valid(iEnt) && pev(iEnt, pev_impulse) == SPEAKER_KEY
}

stock speakerKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szValue[], iValueLen, any:aOutput[], iOutputLength)
{
    switch ( iType )
    {
        case DTYPE_INT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_num(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLOAT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_float(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLAGS:
        {
            aOutput[0] = read_flags(szValue)
        }
        case DTYPE_ARRAY_STRING:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(aOutput[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                aOutput[0] = precache_model(szValue)
        }
    }
}

stock parseDuration(eSpeaker[SPEAKER], const szFile[])
{
    new szPath[128], iFile
    formatex(szPath, charsmax(szPath), "sound/%s", szFile)
    static const szPathIds[][] = { "GAME", "GAME_FALLBACK", "DEFAULTGAME", "BASE" }

    for ( new i; i < sizeof szPathIds; i++ )
    {
        if ( (iFile = fopen(szPath, "rb", true, szPathIds[i])) )
            break
    }

    if ( !iFile )
    {
        server_print("[Speaker] can't open %s in any game folder", szPath)
        return
    }

    fseek(iFile, 0, SEEK_END)
    new iSize = ftell(iFile)
    fseek(iFile, 0, SEEK_SET)
    new szId[5], szWave[5]
    ReadFourCC(iFile, szId)
    ReadLE32(iFile)
    ReadFourCC(iFile, szWave)
    if ( iSize < 12 || !equal(szId, "RIFF") || !equal(szWave, "WAVE") )
    {
        server_print("[Speaker] %s: not RIFF/WAVE (id='%s', form='%s')", szPath, szId, szWave)
    	fclose(iFile)
    	return
    }

    new iPos = 12, iChunk, iFormat, iByteRate, iDataSize, bool:bFmt
    while ( iPos + 8 <= iSize )
    {
    	fseek(iFile, iPos, SEEK_SET)
    	ReadFourCC(iFile, szId)
    	iChunk = ReadLE32(iFile)
    	iPos += 8

    	if ( iChunk < 0 || iChunk > iSize - iPos )
    	{
    		server_print("[Speaker] %s: bad/truncated chunk '%s' (size %d, %d left)", szPath, szId, iChunk, iSize - iPos)
    		break
    	}

    	if ( equal(szId, "fmt ") )
    	{
    		if ( iChunk < 16 ) break;
    		iFormat = ReadLE16(iFile)
    		ReadLE16(iFile)        // channels
    		ReadLE32(iFile)        // sample rate
    		iByteRate = ReadLE32(iFile)
    		bFmt = true
    		if ( iFormat != 1 )
    		{
    			server_print("[Speaker] %s: unsupported format %d (PCM only)", szPath, iFormat)
    			break
    		}
    	}
    	else if ( equal(szId, "data") )
    	{
    		if ( bFmt ) iDataSize = iChunk
    		break
    	}

    	iPos += iChunk + (iChunk & 1)  // skip unknown chunk + pad byte
    }

    fclose(iFile)
    if ( iByteRate <= 0 || iDataSize <= 0 )
    {
        server_print("[Speaker] %s: no valid fmt/data (byte rate %d, data %d)", szPath, iByteRate, iDataSize)
    	return
    }

    eSpeaker[SPEAKER_SONG_COUNT] ++
    ArrayPushCell(eSpeaker[SPEAKER_SONG_DURATION], float(iDataSize) / float(iByteRate))
}

ReadFourCC(iFile, szId[5])
{
	new iByte
	for ( new i; i < 4; i++ )
	{
		iByte = 0
		fread(iFile, iByte, BLOCK_BYTE)
		szId[i] = iByte & 0xFF
	}
	szId[4] = 0
}

ReadLE16(iFile)
{
	new iLow, iHigh
	fread(iFile, iLow, BLOCK_BYTE)
	fread(iFile, iHigh, BLOCK_BYTE)
	return (iLow & 0xFF) | ((iHigh & 0xFF) << 8)
}

ReadLE32(iFile)
{
	new iValue, iByte;
	for ( new i; i < 4; i++ )
	{
		iByte = 0;
		fread(iFile, iByte, BLOCK_BYTE);
		iValue |= (iByte & 0xFF) << (i * 8);
	}
	return iValue;
}

stock EnableAction(id)
{
    if ( !g_ePlayerData[id][PDATA_SPEAKER_ACTION] )
    {
        new eSpeaker[SPEAKER]
        for ( new i = 0; i < g_iSpeaker; i ++ )
        {
            ArrayGetArray(g_aSpeaker, i, eSpeaker)
            if ( eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW )
                continue

            speakerSelect(eSpeaker, TARGET_GHOST)
        }

        g_ePlayerData[id][PDATA_SPEAKER_ACTION] = true
        if ( ++ g_iActivePlayers == 1 )
            EnableForward()
    }
}

stock DisableAction(id)
{
    if ( g_ePlayerData[id][PDATA_SPEAKER_ACTION] )
    {
        new eSpeaker[SPEAKER]
        for ( new i = 0; i < g_iSpeaker; i ++ )
        {
            ArrayGetArray(g_aSpeaker, i, eSpeaker)
            if ( eSpeaker[SPEAKER_FLAGS] & FLAG_SHOW )
                continue

            speakerSelect(eSpeaker, TARGET_HIDE)
        }

        g_ePlayerData[id][PDATA_SPEAKER_ACTION] = false
        if ( -- g_iActivePlayers == 0 )
            DisableForward()
    }
}

stock EnableForward()
{
    EnableHamForward(g_iFwdPreThink)
}

stock DisableForward()
{
    DisableHamForward(g_iFwdPreThink)
}

stock EnableSpeaker()
{
    g_iFwdEmitSound = register_forward(FM_EmitSound, "fwdEmitSound")
    EnableHamForward(g_iFwdUse)
    EnableHamForward(g_iFwdObjectCaps)
}

stock DisableSpeaker()
{
    unregister_forward(FM_EmitSound, g_iFwdEmitSound)
    DisableHamForward(g_iFwdUse)
    DisableHamForward(g_iFwdObjectCaps)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}