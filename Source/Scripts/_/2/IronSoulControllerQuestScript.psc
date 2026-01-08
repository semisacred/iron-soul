Scriptname IronSoulControllerQuestScript extends Quest

Import JsonUtil
Import StorageUtil

;===========================

;== CONFIGURABLE PROPERTIES ==

;===========================

Quest Property RespawnQuest Auto
Spell Property ReviveCloakSpell Auto
Spell Property DragonSoulVFXSpell Auto
Spell Property ReviveStaggerSpell Auto

; PapyrusUtil JsonUtil paths (StorageUtilData/<path>.json)
String Property SharedPath = "Iron Soul/sharedfunctions_runtimeutils" Auto
String Property MirrorPath = "PapyrusUtil/Helpers/constantfunctions_papyrusmonitor" Auto
String Property VisibleLogPath = "Iron Soul" Auto

; Tuning
Float Property ReviveDelaySeconds = 0.25 Auto
Bool  Property ShowDragonSoulPopup = True Auto
Float Property DisableRespawnPollSeconds = 0.50 Auto
Float Property PostResurrectRecastDelay = 0.10 Auto
Float Property LoadMessageDelay = 2.00 Auto
Float Property StartupMessageDelaySeconds = 4.0 Auto ; delay after gameplay ready before showing startup popup
Float Property RespawnWarningDelaySeconds = 4.0 Auto ; delay after free respawn completes before showing warning

; Continuous bleedout poll (keeps the monitor alive even when OnDying never fires)
Float Property BleedoutPollSeconds = 0.50 Auto


; Sync throttle (heals drift without constant disk writes)
Float Property SyncMinIntervalSeconds = 30.0 Auto
Float Property CurrentSyncMinIntervalSeconds = 300.0 Auto ; current-character sync throttle (event-driven + rare fallback)


;===========================

;== LOGGING + GAMEPLAY CONFIG (JSON) ==

;===========================

; Stored at: Data\SKSE\Plugins\StorageUtilData\Iron Soul\config.json
String Property LogConfigPath = "Iron Soul/config" Auto
String Property LogPrefix = "[IronSoul]" Auto

Bool _logEnabled = False
Int  _logLevel = 2 ; 1=Errors, 2=Info, 3=Debug

Int _maxLives = 10
Bool _disableStartupMessage = False
Bool _disableLoadMessage = False
Bool _disableFatalReminderMessage = False
Bool _enableCharacterSheetCompatibility = False

Int _respawnCooldownSeconds = 3600 ; seconds of real-time play required to regain free respawn
Float _cooldownTickAt = 0.0

;===========================

;== MESSAGE TEXT (JSON) ==

;===========================


String Property RespawnFlavorPath = "Iron Soul/respawnmessagetext" Auto

String Property RegistrySharedPath = "Iron Soul/registry" Auto
String Property RegistryMirrorPath = "Runtime/rtcache_m" Auto
Int Property RegistryMaxNames = 128 Auto

String Property RegistrySharedCheckPath = "Iron Soul/registry.chk" Auto
String Property RegistryMirrorCheckPath = "Runtime/rtcache_m.chk" Auto
Int Property RegistryFormatVersion = 1 Auto






; log level constants
Int Property LOG_ERR_VALUE = 1 Auto
Int Property LOG_INFO_VALUE = 2 Auto
Int Property LOG_DBG_VALUE = 3 Auto
Int Function LOG_ERR()
    return LOG_ERR_VALUE
EndFunction
Int Function LOG_INFO()
    return LOG_INFO_VALUE
EndFunction
Int Function LOG_DBG()
    return LOG_DBG_VALUE
EndFunction

Function LoadLogConfig()
	; Defaults
	_logEnabled = False
	_logLevel = 2
	_maxLives = 10
	_disableStartupMessage = False
	_disableLoadMessage = False
	_disableFatalReminderMessage = False
	_enableCharacterSheetCompatibility = False

	; Read config
	int enabled = JsonUtil.GetIntValue(LogConfigPath, "EnableLogging", 0)
	_logEnabled = (enabled == 1)
	_logLevel = JsonUtil.GetIntValue(LogConfigPath, "LogLevel", 2)

	_maxLives = JsonUtil.GetIntValue(LogConfigPath, "MaxLives", 10)
	if _maxLives < 1
		_maxLives = 1
	endif

	_disableStartupMessage = (JsonUtil.GetIntValue(LogConfigPath, "DisableStartupMessage", 0) == 1)
	_disableLoadMessage = (JsonUtil.GetIntValue(LogConfigPath, "DisableLoadMessage", 0) == 1)
	_disableFatalReminderMessage = (JsonUtil.GetIntValue(LogConfigPath, "DisableFatalReminderMessage", 0) == 1)

	_enableCharacterSheetCompatibility = (JsonUtil.GetIntValue(LogConfigPath, "EnableCharacterSheetCompatibility", 0) == 1)


	_respawnCooldownSeconds = JsonUtil.GetIntValue(LogConfigPath, "RespawnCooldownSeconds", 3600)
	if _respawnCooldownSeconds < 0
		_respawnCooldownSeconds = 0
	endif
	; Create file with defaults if missing (makes it easy to edit)
	bool wroteDefaults = False

	if !JsonUtil.HasIntValue(LogConfigPath, "EnableLogging")
		JsonUtil.SetIntValue(LogConfigPath, "EnableLogging", 0)
		wroteDefaults = True
	endif
	if !JsonUtil.HasIntValue(LogConfigPath, "LogLevel")
		JsonUtil.SetIntValue(LogConfigPath, "LogLevel", 2)
		wroteDefaults = True
	endif
	if !JsonUtil.HasIntValue(LogConfigPath, "MaxLives")
		JsonUtil.SetIntValue(LogConfigPath, "MaxLives", 10)
		wroteDefaults = True
	endif

	if !JsonUtil.HasIntValue(LogConfigPath, "DisableStartupMessage")
		JsonUtil.SetIntValue(LogConfigPath, "DisableStartupMessage", 0)
		wroteDefaults = True
	endif
	if !JsonUtil.HasIntValue(LogConfigPath, "DisableLoadMessage")
		JsonUtil.SetIntValue(LogConfigPath, "DisableLoadMessage", 0)
		wroteDefaults = True
	endif
	if !JsonUtil.HasIntValue(LogConfigPath, "DisableFatalReminderMessage")
		JsonUtil.SetIntValue(LogConfigPath, "DisableFatalReminderMessage", 0)
		wroteDefaults = True
	endif
if !JsonUtil.HasIntValue(LogConfigPath, "EnableCharacterSheetCompatibility")
		JsonUtil.SetIntValue(LogConfigPath, "EnableCharacterSheetCompatibility", 0)
		wroteDefaults = True
	endif
	if !JsonUtil.HasIntValue(LogConfigPath, "RespawnCooldownSeconds")
		JsonUtil.SetIntValue(LogConfigPath, "RespawnCooldownSeconds", 3600)
		wroteDefaults = True
	endif
	if wroteDefaults
		JsonUtil.Save(LogConfigPath)
	endif
EndFunction

Function LogMsg(Int level, String msg)
	if !_logEnabled
		return
	endif
	if level > _logLevel
		return
	endif

	; Level 3 (debug) stays in Papyrus log only.
	; Levels 1-2 are also shown in the on-screen notification area.
	if level != LOG_DBG()
		Debug.Notification(LogPrefix + " " + msg)
	endif
	Debug.Trace(LogPrefix + " " + msg)
EndFunction

;===========================

;== IN-GAME DEBUG HELPERS ==

;===========================

Function LogPropsOnce()
	LogMsg(LOG_INFO(), "Props: RespawnQuest=" + (RespawnQuest != None) + " Running=" + (RespawnQuest != None && RespawnQuest.IsRunning()))
	LogMsg(LOG_INFO(), "Props: VFX=" + (DragonSoulVFXSpell != None) + " Stagger=" + (ReviveStaggerSpell != None) + " Cloak=" + (ReviveCloakSpell != None))
	LogMsg(LOG_INFO(), "Config: MaxLives=" + _maxLives + " Logging=" + _logEnabled + " Level=" + _logLevel)
EndFunction

;=================================================================
;== UTILITY HELPERS
;=================================================================

; EnsureJsonDefault writes an empty string to the given path/key if
; the key does not already exist.  This helper consolidates the
; logic previously duplicated in EnsureMessageTextDefaults and
; EnsureRespawnFlavorDefaults.  It does not automatically save
; the JSON; callers decide when to save.
Function EnsureJsonDefault(String jsonPath, String fieldKey)
    ; If the given JSON path does not have the specified key, initialise it to an empty string.
    if !JsonUtil.HasStringValue(jsonPath, fieldKey)
        JsonUtil.SetStringValue(jsonPath, fieldKey, "")
    endif
EndFunction

; MakeKey builds a storage or JSON key by concatenating a prefix
; and a GUID with a colon separator.  All key-building helpers
; delegate to this to ensure consistent formatting.
String Function MakeKey(String prefix, String guid)
    return prefix + ":" + guid
EndFunction


;===========================

;== INTERNAL STATE KEYS ==

;===========================

; New per-character keys (use stable CharacterGUID)
String Function GetDeathKeyById(String charId)
    return MakeKey("PapyrusError", charId)
EndFunction
String Function GetRespawnKeyById(String charId)
    return MakeKey("GameStateHelper", charId)
EndFunction
String Function GetStartupShownKeyById(String charId)
    return MakeKey("StartupShown", charId)
EndFunction
String Function GetPoemShownKeyById(String charId)
    return MakeKey("PoemShown", charId)
EndFunction
String Function GetCooldownPlayedKeyById(String charId)
    return MakeKey("CooldownPlayed", charId)
EndFunction
String Function GetCooldownLastKeyById(String charId)
    return MakeKey("CooldownLast", charId)
EndFunction

;===========================

;== STORAGEUTIL AUTHORITY ==

;===========================

; Promote StorageUtil (SKSE co-save) to the authoritative store.
; JSON (Shared/Mirror) remain as mirrors + fallback for recovery/migration.

Int _AUTH_INT_SENTINEL = -2147483647

String Function _DeathsStorageKey(String guid)
    return MakeKey("IronSoul:Deaths", guid)
EndFunction
String Function _RespawnUsedStorageKey(String guid)
    return MakeKey("IronSoul:RespawnUsed", guid)
EndFunction
String Function _CooldownPlayedStorageKey(String guid)
    return MakeKey("IronSoul:CooldownPlayed", guid)
EndFunction
String Function _CooldownLastStorageKey(String guid)
    return MakeKey("IronSoul:CooldownLast", guid)
EndFunction
String Function _PoemShownStorageKey(String guid)
    return MakeKey("IronSoul:PoemShown", guid)
EndFunction
Int Function _GetAuthInt(Actor player, String storageKey, String jsonKey, Int defaultValue)
	if !player
		return defaultValue
	endif

	; Read all three stores (co-save + Shared JSON + Mirror JSON).
	Int vStore = StorageUtil.GetIntValue(player, storageKey, _AUTH_INT_SENTINEL)
	Bool hasStore = (vStore != _AUTH_INT_SENTINEL)

	Bool hasS = JsonUtil.HasIntValue(SharedPath, jsonKey)
	Bool hasM = JsonUtil.HasIntValue(MirrorPath, jsonKey)
	Int vS = JsonUtil.GetIntValue(SharedPath, jsonKey, defaultValue)
	Int vM = JsonUtil.GetIntValue(MirrorPath, jsonKey, defaultValue)

	; Max-wins reconciliation across all available sources.
	Int v = defaultValue
	if hasStore
		v = vStore
	endif
	if hasS && vS > v
		v = vS
	endif
	if hasM && vM > v
		v = vM
	endif

	; Self-heal: write the max back to all stores to make them mutually redundant.
	Bool drift = False
	if !hasStore || vStore != v
		StorageUtil.SetIntValue(player, storageKey, v)
		drift = True
	endif

	; Rebuild JSON mirrors even if missing (deletion recovery).
	if !hasS || vS != v
		JsonUtil.SetIntValue(SharedPath, jsonKey, v)
		drift = True
	endif
	if !hasM || vM != v
		JsonUtil.SetIntValue(MirrorPath, jsonKey, v)
		drift = True
	endif

	; Avoid heavy disk writes on hot paths: save only occasionally when we repaired drift.
	if drift
		Float now = Utility.GetCurrentRealTime()
		if (now - _lastAuthHealSaveAt) >= SyncMinIntervalSeconds
			JsonUtil.Save(SharedPath)
			JsonUtil.Save(MirrorPath)
			_lastAuthHealSaveAt = now
		endif
	endif

	return v
EndFunction

Function _SetAuthInt(Actor player, String storageKey, String jsonKey, Int value, Bool saveNow = True)
	if player
		StorageUtil.SetIntValue(player, storageKey, value)
	endif

	JsonUtil.SetIntValue(SharedPath, jsonKey, value)
	JsonUtil.SetIntValue(MirrorPath, jsonKey, value)

	if saveNow
		JsonUtil.Save(SharedPath)
		JsonUtil.Save(MirrorPath)
	endif

EndFunction

;===========================

;== EPOCH-ENCODED STATE (ANTI SAVE/LOAD GAMING) ==

;===========================

; We encode small state values with the current real-time seconds so "latest state wins"
; across co-save + Shared/Mirror JSON, preventing save/load from rolling back timers/flags.

Int Function _EncodeFlag(Int nowSec, Int flag01)
    if flag01 != 0
        flag01 = 1
    endif
    ; To prevent 32-bit integer overflow when encoding real-time seconds, clamp the timestamp to a safe range.
    ; Using a 31-bit epoch ensures (trimmedNow * 2) + flag always fits in a signed Int.
    Int epochMod = 1073741824 ; 2^30
    Int chunks = nowSec / epochMod
    Int trimmedNow = nowSec - (chunks * epochMod)
    return (trimmedNow * 2) + flag01
EndFunction
Int Function _DecodeFlag(Int token)
	; Legacy values 0/1 remain valid.
	if token <= 1
		return token
	endif
	return token - ((token / 2) * 2)
EndFunction
Int Function _EncodePlayed(Int nowSec, Int playedSec)
    ; played stored in low 13 bits (0..8191), epoch in the high bits
    if playedSec < 0
        playedSec = 0
    elseif playedSec > 8191
        playedSec = 8191
    endif
    ; To prevent overflow when shifting real-time seconds, clamp the timestamp to a safe modulus.
    ; 8192 = 2^13; we restrict nowSec to 2^18 to guarantee (trimmedNow * 8192) < 2^31.
    Int epochMod = 262144 ; 2^18
    Int chunks = nowSec / epochMod
    Int trimmedNow = nowSec - (chunks * epochMod)
    return (trimmedNow * 8192) + playedSec
EndFunction
Int Function _DecodePlayed(Int token)
	; Legacy values (<8192) remain valid.
	if token < 8192
		return token
	endif
	return token - ((token / 8192) * 8192)
EndFunction

;===========================

;== CHARACTER GUID (PERSISTENT, RENAME-PROOF) ==

;===========================

String Property _guidStorageKey = "IronSoul:CharacterGUID" Auto Hidden

String Function GenerateCharacterGUID(Actor player)
	; Papyrus doesn't have true UUIDs; this is a stable-enough pseudo-GUID.
	; Stored on the player via StorageUtil so it persists in the save and survives renames.
	int a = Utility.RandomInt(100000, 999999)
	int b = Utility.RandomInt(100000, 999999)
	int c = Utility.RandomInt(100000, 999999)
	return "IS-" + a + "-" + b + "-" + c
EndFunction

;===========================
;== PROVISIONAL GUID CREATION + FINALIZATION ==
;===========================

; Creates a provisional GUID for a newly spawned character.  This GUID is generated from
; the current real‑time epoch, the player’s race form ID, sex, starting level and a
; random suffix.  It is immediately persisted into the co‑save via StorageUtil and
; written into the shared/mirror JSON stores along with creation metadata.  A
; provisional GUID does not depend on the player’s display name; the name can be
; bound later when it becomes valid (see FinalizeCharacterIdentity).
String Function BuildProvisionalGuid(Actor player)
    if !player
        return ""
    endif

    ; If a GUID already exists in the co‑save, return it without generating a new one.
    String existing = StorageUtil.GetStringValue(player, _guidStorageKey, "")
    if existing != ""
        return existing
    endif

    ; Gather entropy: epoch (seconds), race FormID, sex and starting level.
    Int nowSec = Utility.GetCurrentRealTime() as Int
    Race r = player.GetRace()
    Int raceID = 0
    if r
        raceID = r.GetFormID()
    endif
    ActorBase ab = player.GetLeveledActorBase()
    Int sex = 0
    if ab
        sex = ab.GetSex()
    endif
    Int lvl = player.GetLevel()
    if lvl <= 0
        lvl = 1
    endif
    ; Add a small random suffix to further reduce collisions.
    Int rand = Utility.RandomInt(1000, 9999)
    String guid = nowSec + "_" + raceID + "_" + sex + "_" + lvl + "_" + rand

    ; Persist the provisional GUID in the co‑save.
    StorageUtil.SetStringValue(player, _guidStorageKey, guid)

    ; Persist creation metadata into both shared and mirror stores.  These values
    ; assist with GUID recovery if the co‑save is deleted.
    JsonUtil.SetIntValue(SharedPath, "CreatedAt:" + guid, nowSec)
    JsonUtil.SetIntValue(MirrorPath, "CreatedAt:" + guid, nowSec)
    JsonUtil.SetIntValue(SharedPath, "Race:" + guid, raceID)
    JsonUtil.SetIntValue(MirrorPath, "Race:" + guid, raceID)
    JsonUtil.SetIntValue(SharedPath, "Sex:" + guid, sex)
    JsonUtil.SetIntValue(MirrorPath, "Sex:" + guid, sex)
    JsonUtil.SetIntValue(SharedPath, "StartLevel:" + guid, lvl)
    JsonUtil.SetIntValue(MirrorPath, "StartLevel:" + guid, lvl)

    ; Record the character signature and last level; these fields allow us to
    ; validate that a GUID belongs to the current character.
    String sig = BuildCharacterSignature(player)
    if sig != ""
        JsonUtil.SetStringValue(SharedPath, "CharSig:" + guid, sig)
        JsonUtil.SetStringValue(MirrorPath, "CharSig:" + guid, sig)
    endif
    JsonUtil.SetIntValue(SharedPath, "LastLevel:" + guid, lvl)
    JsonUtil.SetIntValue(MirrorPath, "LastLevel:" + guid, lvl)

    ; Mark this as the currently active GUID.  This helps recovery if the
    ; co‑save is missing.
    JsonUtil.SetStringValue(SharedPath, "ActiveGUID", guid)
    JsonUtil.SetStringValue(MirrorPath, "ActiveGUID", guid)

    ; Persist metadata immediately.  We save both stores here because this
    ; function is only called once per character.
    JsonUtil.Save(SharedPath)
    JsonUtil.Save(MirrorPath)

    return guid
EndFunction

; Finalizes a provisional GUID by binding it to the player’s display name.  When the
; name becomes valid (i.e., not empty or "Prisoner"), this function writes the
; LastKnownName and GUIDForName entries into the shared/mirror JSON stores and
; updates the ActiveGUID and signature.  This can be called repeatedly; it has
; no effect if the name is already bound.
Function FinalizeCharacterIdentity(Actor player, String guid)
    if !player || guid == ""
        return
    endif
    String name = player.GetDisplayName()
    if !IsValidPlayerName(name)
        return
    endif
    ; Record the last known name for this GUID.
    JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid, name)
    JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid, name)
    ; Record the reverse mapping from name to GUID.
    JsonUtil.SetStringValue(SharedPath, "GUIDForName:" + name, guid)
    JsonUtil.SetStringValue(MirrorPath, "GUIDForName:" + name, guid)
    ; Record the current signature and level.
    String sigNow = BuildCharacterSignature(player)
    if sigNow != ""
        JsonUtil.SetStringValue(SharedPath, "CharSig:" + guid, sigNow)
        JsonUtil.SetStringValue(MirrorPath, "CharSig:" + guid, sigNow)
    endif
    Int lvlNow = player.GetLevel()
    if lvlNow > 0
        JsonUtil.SetIntValue(SharedPath, "LastLevel:" + guid, lvlNow)
        JsonUtil.SetIntValue(MirrorPath, "LastLevel:" + guid, lvlNow)
    endif
    ; Mark as active GUID for this session.
    JsonUtil.SetStringValue(SharedPath, "ActiveGUID", guid)
    JsonUtil.SetStringValue(MirrorPath, "ActiveGUID", guid)
    ; Save changes immediately to persist finalization.
    JsonUtil.Save(SharedPath)
    JsonUtil.Save(MirrorPath)
    ; Clear waiting flag now that the identity has been bound.
    _waitingForFirstCellIdentity = False
EndFunction

;===========================

;== CHARACTER SIGNATURE (REGISTRY DISCRIMINATOR)

;===========================

String Function BuildCharacterSignature(Actor player)
	if !player
		return ""
	endif
	Race r = player.GetRace()
	int rid = 0
	if r
		rid = r.GetFormID()
	endif
	int sex = 0
	ActorBase ab = player.GetLeveledActorBase()
	if ab
		sex = ab.GetSex()
	endif
	return rid + "|" + sex
EndFunction

;===========================
;== GUID HELPER FUNCTIONS (MODULAR)
;===========================

; Retrieve an existing GUID from the co‑save and validate it against the current
; character signature and level.  If the GUID belongs to a different
; character (e.g. after loading a different save), it will be discarded and
; an empty string returned.  This helper encapsulates the signature and level
; mismatch logic previously implemented inline in GetCharacterGUID().
String Function RetrieveExistingGuid(Actor player, String curSig, Int curLevel)
    if !player
        return ""
    endif
    String guid = StorageUtil.GetStringValue(player, _guidStorageKey, "")
    if guid == ""
        return ""
    endif
    Bool mismatch = False
    ; Validate signature: discard the GUID if the stored signature does not match the current signature.
    if curSig != ""
        String sSig = JsonUtil.GetStringValue(SharedPath, "CharSig:" + guid, "")
        String mSig = JsonUtil.GetStringValue(MirrorPath, "CharSig:" + guid, "")
        String haveSig = sSig
        if haveSig == "" && mSig != ""
            haveSig = mSig
        endif
        if haveSig != "" && haveSig != curSig
            mismatch = True
        endif
    endif
    ; Validate level: discard the GUID if it reflects a more progressed character than the current one.
    if !mismatch && curLevel > 0
        Int sLv = JsonUtil.GetIntValue(SharedPath, "LastLevel:" + guid, 0)
        Int mLv = JsonUtil.GetIntValue(MirrorPath, "LastLevel:" + guid, 0)
        Int haveLv = sLv
        if haveLv == 0 && mLv > 0
            haveLv = mLv
        endif
        if haveLv > 0
            if curLevel == 1 && haveLv > 1
                mismatch = True
            elseif curLevel < (haveLv - 2)
                mismatch = True
            endif
        endif
    endif
    if mismatch
        StorageUtil.SetStringValue(player, _guidStorageKey, "")
        guid = ""
    endif
    return guid
EndFunction

; Create a provisional GUID when no valid GUID exists.  This helper calls
; BuildProvisionalGuid() and sets flags to indicate that the identity should be
; finalized once a valid player name is available.  It returns the new GUID.
String Function GenerateProvisionalGuidIfNeeded(Actor player)
    if !player
        return ""
    endif
    String guid = BuildProvisionalGuid(player)
    ; Mark that we need to finalize the identity when a valid name becomes available.
    _waitingForFirstCellIdentity = True
    _startupCheckPending = True
    return guid
EndFunction

; Update the registry with the current signature, level and active GUID.  This
; helper writes to both the shared and mirror JSON stores to ensure the new
; information is available for recovery and identity validation.  It does not
; call JsonUtil.Save(); callers should save after all updates are performed.
Function UpdateGuidRegistry(String guid, String curSig, Int curLevel)
    if guid == ""
        return
    endif
    if curSig != ""
        JsonUtil.SetStringValue(SharedPath, "CharSig:" + guid, curSig)
        JsonUtil.SetStringValue(MirrorPath, "CharSig:" + guid, curSig)
    endif
    if curLevel > 0
        JsonUtil.SetIntValue(SharedPath, "LastLevel:" + guid, curLevel)
        JsonUtil.SetIntValue(MirrorPath, "LastLevel:" + guid, curLevel)
    endif
    JsonUtil.SetStringValue(SharedPath, "ActiveGUID", guid)
    JsonUtil.SetStringValue(MirrorPath, "ActiveGUID", guid)
EndFunction

; Finalize a provisional GUID if the player's display name is valid.  This helper
; wraps FinalizeCharacterIdentity() for readability.
Function FinalizeIdentityIfValid(Actor player, String guid)
    if !player || guid == ""
        return
    endif
    String pName = player.GetDisplayName()
    if IsValidPlayerName(pName)
        FinalizeCharacterIdentity(player, guid)
    endif
EndFunction
String Function GetCharacterGUID(Actor player)
    ; Returns a stable GUID for the current character.  This modularised version
    ; delegates each step to helper functions defined above.  If a GUID is not
    ; present or fails validation, a provisional GUID is created.  Registry
    ; updates and finalisation occur after retrieval or creation.
    if !player
        return ""
    endif
    ; Compute signature and level for validation.
    String curSig = BuildCharacterSignature(player)
    Int curLevel = player.GetLevel()
    if curLevel < 0
        curLevel = 0
    endif
    ; Attempt to retrieve a valid existing GUID.
    String guid = RetrieveExistingGuid(player, curSig, curLevel)
    ; Create a provisional GUID if none exists.
    if guid == ""
        guid = GenerateProvisionalGuidIfNeeded(player)
    endif
    ; Update the registry with the latest signature, level and active GUID.
    UpdateGuidRegistry(guid, curSig, curLevel)

    ; Persist registry changes immediately to the JSON stores.
    JsonUtil.Save(SharedPath)
    JsonUtil.Save(MirrorPath)

    return guid
EndFunction

;===========================

;== NAME VALIDATION (Prisoner exception) ==

;===========================

Bool Function IsValidPlayerName(String name)
    if name == "" || name == "Prisoner" || name == "Player"
		return False
	endif
	return True
EndFunction

;===========================

;== INTERNAL RUNTIME STATE ==

;===========================

String _sessionGuid = ""

; Permanent death counter AV for UI mods (unused vanilla actor value)
String _deathAVName = "DEPRECATED05"


Float _lastCurrentSyncAt = -9999.0
Float _lastAuthHealSaveAt = -9999.0
Float _lastCooldownSaveAt = -9999.0

Bool _globalSyncDoneThisSession = False
Bool _revivePending = False
Bool _reviveConsumedSoul = False
Bool _dragonSoulResolvedThisBleedout = False


Bool _pendingDisableRespawn = False
Bool _postResurrectRecastPending = False
Bool _pendingLoadMessage = False

Bool _wasBleedingOut = False
Bool _bleedoutArmed  = False
Bool _updateQueued = False
Bool _deathEventLocked = False

Float _loadMessageAt = 0.0

Bool _pendingStartupMessage = False
Float _startupMessageAt = 0.0
Bool _startupCheckPending = False
Bool _waitingForFirstCellIdentity = False ; defer GUID/init until first cell load after chargen

; record when startup message was actually shown
Float _startupMessageShownAt = -9999.0


; Free-respawn warning message delayed until AFTER respawn completes
Bool _pendingRespawnWarning = False
Float _respawnWarningAt = 0.0
Bool _respawnWarningArmed = False

;== DEATH AV RESYNC STATE ==
; When a game is reloaded we perform a best‑effort sync of the death actor value immediately
; and then schedule one more resync roughly 10 seconds later.  These flags track the
; pending resync and the target timestamp.  OnUpdate will check and perform the
; deferred sync when appropriate.
Bool _pendingDeathResync = False
Float _deathResyncAt = 0.0
; STARTUP GATE: wait until gameplay is ready, then retry TryScheduleStartupMessage()
Bool _startupGateActive = False
Int  _startupGateTriesLeft = 0

Bool _bootstrapActive = False
Int  _bootstrapTriesLeft = 0

;===========================

;== UTILS: SAFE UPDATE QUEUE ==

;===========================

Function QueueUpdate(Float afDelay)
	if _updateQueued
		LogMsg(LOG_DBG(), "QueueUpdate skipped; already queued. delay=" + afDelay)
		return
	endif
	_updateQueued = True
	LogMsg(LOG_DBG(), "QueueUpdate scheduled. delay=" + afDelay)
	RegisterForSingleUpdate(afDelay)
EndFunction

Function RescheduleIfJobsRemain()
	if _pendingDisableRespawn || _revivePending || _postResurrectRecastPending || _pendingLoadMessage || _pendingStartupMessage || _startupGateActive
		QueueUpdate(0.10)
	else
		QueueUpdate(BleedoutPollSeconds)
	endif
EndFunction

;===========================

;== NEW CHARACTER BOOTSTRAP ==

;===========================

Function StartBootstrap()
    ; Kick off the bootstrap sequence.  This no longer waits for the player to
    ; acquire a non‑placeholder name; instead we begin with a provisional
    ; identity immediately and finalize it later.  We still retry if the
    ; player reference is not yet ready.
    _bootstrapActive = True
    _bootstrapTriesLeft = 30 ; retry up to 30 times while waiting for player
    _updateQueued = False
    QueueUpdate(1.0)
EndFunction
Bool Function BootstrapTick()
	if !_bootstrapActive
		return False
	endif

	Actor p = Game.GetPlayer()
	if !p
		_bootstrapTriesLeft -= 1

		if _bootstrapTriesLeft <= 0
			_bootstrapActive = False
			LogMsg(LOG_ERR(), "Bootstrap: player still None after 60s; continuing normal polling.")
			return False
		endif

		LogMsg(LOG_INFO(), "Bootstrap: player None; retrying (" + _bootstrapTriesLeft + "s left)")
		_updateQueued = False
		QueueUpdate(1.0)
		return True
	endif
    ; Acquire a GUID immediately; GetCharacterGUID handles provisional creation.
    String bguid = GetCharacterGUID(p)
    ; We consider the bootstrap complete after one successful pass.
    _bootstrapActive = False
    LogMsg(LOG_INFO(), "Bootstrap: player ready; initial sync + startup scheduling")

    ; Track current character by GUID (rename‑proof) and perform initial sync.
    if bguid != ""
        SyncCurrentCharacterImmediate(bguid)
        ; Record the current display name if valid for tooling/debug.
        String bnameNow = p.GetDisplayName()
        if IsValidPlayerName(bnameNow)
            JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + bguid, bnameNow)
            JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + bguid, bnameNow)
            JsonUtil.Save(SharedPath)
            JsonUtil.Save(MirrorPath)
        endif
    endif
    ; Full multi‑character heal/sync (new game bootstrap)
    if !_globalSyncDoneThisSession
        _globalSyncDoneThisSession = True
        SyncAllKnownCharactersOnce()
    endif
    EnsureVisibleLogsOnLoad()

    TryScheduleStartupMessage(p)

    ; STARTUP GATE: arm once per new game path so we retry after chargen/menus are gone
    _startupGateActive = True
    _startupGateTriesLeft = 60

    ; Only arm load message if startup is NOT pending
    if !_pendingStartupMessage
        _pendingLoadMessage = True
        ; add +1.0s delay in general
        _loadMessageAt = Utility.GetCurrentRealTime() + LoadMessageDelay
    else
        _pendingLoadMessage = False
    endif

    return False
EndFunction

;===========================

;== STARTUP MESSAGE SCHEDULER ==

;===========================

Function TryScheduleStartupMessage(Actor player)
    ; Do nothing if startup messages are globally disabled
    if _disableStartupMessage
        return
    endif
    ; Defer until a player reference exists
    if !player
        _startupCheckPending = True
        return
    endif

    ; Acquire a GUID for the current character.  If none is available yet
    ; (e.g. provisional identity during chargen), mark a pending check and bail.
    String guid = GetCharacterGUID(player)
    if guid == ""
        _startupCheckPending = True
        return
    endif

    ; Check whether the startup message has already been shown or suppressed
    String startupKey = GetStartupShownKeyById(guid)
    int shownS = JsonUtil.GetIntValue(SharedPath, startupKey, 0)
    int shownM = JsonUtil.GetIntValue(MirrorPath, startupKey, 0)
    int shown = shownS
    if shownM > shown
        shown = shownM
    endif
    if shown != 0
        ; Already handled for this GUID; do not schedule again
        return
    endif

    ; Schedule the one‑time startup message to run after the configured delay.
    ; The actual display and additional checks (death count, name validity) occur in HandleStartupMessage().
    _pendingStartupMessage = True
    _startupMessageAt = Utility.GetCurrentRealTime() + StartupMessageDelaySeconds
    ; Suppress any pending load message until after the startup notice executes
    _pendingLoadMessage = False
EndFunction

;===========================

;== TRUE DEATH HELPERS ==

;===========================
Function ResetRespawnUsed(Actor player, String guid)
	if !player || guid == ""
		return
	endif
	Int nowSec = Utility.GetCurrentRealTime() as Int
	_SetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), _EncodeFlag(nowSec, 0), False)
	LogMsg(LOG_INFO(), "ResetRespawnUsed: cleared respawnUsed for GUID=" + guid)
EndFunction

Function StartRespawnCooldown(Actor player, String guid)
	if !player || guid == ""
		return
	endif
	Int nowSec = Utility.GetCurrentRealTime() as Int
	_SetAuthInt(player, _CooldownPlayedStorageKey(guid), GetCooldownPlayedKeyById(guid), _EncodePlayed(nowSec, 0), False)
	_SetAuthInt(player, _CooldownLastStorageKey(guid), GetCooldownLastKeyById(guid), nowSec, True)
	LogMsg(LOG_INFO(), "StartRespawnCooldown: GUID=" + guid + " nowSec=" + nowSec + " target=" + _respawnCooldownSeconds)
EndFunction

Function TickRespawnCooldown(Actor player, String guid)
	if !player || guid == ""
		return
	endif

	if _respawnCooldownSeconds <= 0
		return
	endif

	float nowRT = Utility.GetCurrentRealTime()
	if nowRT < _cooldownTickAt
		_cooldownTickAt = nowRT
	endif
	if (nowRT - _cooldownTickAt) < 1.0
		return
	endif
	_cooldownTickAt = nowRT

	Int usedTok = _GetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), 0)
	Int used = _DecodeFlag(usedTok)
	if used <= 0
		return
	endif

	Int nowSec = Utility.GetCurrentRealTime() as Int
	Int lastSec = _GetAuthInt(player, _CooldownLastStorageKey(guid), GetCooldownLastKeyById(guid), nowSec)
	Int playedTok = _GetAuthInt(player, _CooldownPlayedStorageKey(guid), GetCooldownPlayedKeyById(guid), 0)
	Int played = _DecodePlayed(playedTok)

	Int delta = nowSec - lastSec
	if delta < 0
		delta = 0
	elseif delta > 60
		delta = 60
	endif

	if delta > 0
		played += delta
		_SetAuthInt(player, _CooldownPlayedStorageKey(guid), GetCooldownPlayedKeyById(guid), _EncodePlayed(nowSec, played), False)
	endif

	_SetAuthInt(player, _CooldownLastStorageKey(guid), GetCooldownLastKeyById(guid), nowSec, False)

	; Persist cooldown progress occasionally (avoid constant disk writes)
	nowRT = Utility.GetCurrentRealTime()
	if (nowRT - _lastCooldownSaveAt) >= SyncMinIntervalSeconds
		JsonUtil.Save(SharedPath)
		JsonUtil.Save(MirrorPath)
		_lastCooldownSaveAt = nowRT
	endif

	if played >= _respawnCooldownSeconds
		LogMsg(LOG_INFO(), "RespawnCooldown complete: restoring free respawn. played=" + played + " GUID=" + guid)
		_SetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), _EncodeFlag(nowSec, 0), True)
		_SetAuthInt(player, _CooldownPlayedStorageKey(guid), GetCooldownPlayedKeyById(guid), _EncodePlayed(nowSec, 0), False)
		_SetAuthInt(player, _CooldownLastStorageKey(guid), GetCooldownLastKeyById(guid), nowSec, True)

		Debug.Notification("You're feeling lucky.")

		if RespawnQuest && !RespawnQuest.IsRunning()
			LogMsg(LOG_INFO(), "RespawnCooldown: starting RespawnQuest")
			RespawnQuest.Start()
			; When respawn is enabled, ensure the player is essential so bleedout-based revive can occur
			if player
				player.GetActorBase().SetEssential(True)
			endif
		endif
	endif
EndFunction

;===========================

;== ON INIT ==

;===========================

Event OnInit()
	; Clamp registry size to literal array capacity
	if RegistryMaxNames > 128
		RegistryMaxNames = 128
	endif
	if RegistryMaxNames < 1
		RegistryMaxNames = 1
	endif
	LoadLogConfig()
	LogMsg(LOG_INFO(), "OnInit fired (script running).")
	LogPropsOnce()

	StartBootstrap()

	QueueUpdate(BleedoutPollSeconds)
EndEvent

;===========================

;== ON PLAYER LOAD GAME ==

;===========================

;===========================
;== GAME RELOAD HELPERS ==
;===========================

; Reset transient per-session state when a new character GUID is detected.  This helper
; clears various pending flags so that jobs do not leak across characters.
Function ResetTransientStateForNewGuid(String guid)
    if guid == ""
        return
    endif
    _sessionGuid = guid
    _pendingDisableRespawn = False
    _postResurrectRecastPending = False
    _revivePending = False
    _reviveConsumedSoul = False
    _dragonSoulResolvedThisBleedout = False
    _wasBleedingOut = False
    _bleedoutArmed = False
    _deathEventLocked = False
    _pendingRespawnWarning = False
    _respawnWarningArmed = False
EndFunction

; Persist active GUID and related metadata into the shared/mirror JSON stores.  This
; helper writes the active GUID, signature and optional name mapping, then saves
; the JSON files when changes have been made.  Passing an empty guid has no effect.
Function PersistGuidMetadata(Actor player, String guid, String name, String sig)
    if guid == ""
        return
    endif
    Bool sharedDirty = False
    Bool mirrorDirty = False
    ; Write the active GUID.
    JsonUtil.SetStringValue(SharedPath, "ActiveGUID", guid)
    JsonUtil.SetStringValue(MirrorPath, "ActiveGUID", guid)
    sharedDirty = True
    mirrorDirty = True
    ; Write signature for recovery/validation.
    if sig != ""
        JsonUtil.SetStringValue(SharedPath, "CharSig:" + guid, sig)
        JsonUtil.SetStringValue(MirrorPath, "CharSig:" + guid, sig)
        sharedDirty = True
        mirrorDirty = True
    endif
    ; Map display name back to GUID when the name is valid.  This assists with
    ; recovery if the co‑save is deleted.
    if IsValidPlayerName(name)
        JsonUtil.SetStringValue(SharedPath, "GUIDForName:" + name, guid)
        JsonUtil.SetStringValue(MirrorPath, "GUIDForName:" + name, guid)
        sharedDirty = True
        mirrorDirty = True
    endif
    if sharedDirty
        JsonUtil.Save(SharedPath)
    endif
    if mirrorDirty
        JsonUtil.Save(MirrorPath)
    endif
EndFunction

; Enforce the essential/respawn quest state for the current character.  This helper
; ensures that the player remains essential and that the RespawnQuest is started
; when the free respawn has not yet been consumed.  It also records the last
; known name into the JSON stores.  Name persistence is saved immediately.
Function SetEssentialAndStartQuestIfNeeded(Actor player, String guid, String name)
    if !player || guid == ""
        return
    endif
    ; Determine whether a free respawn is still available.  If so, ensure the quest is running.
    Int usedTok2 = _GetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), 0)
    Int used2 = _DecodeFlag(usedTok2)
    if used2 == 0
        if RespawnQuest && !RespawnQuest.IsRunning()
            RespawnQuest.Start()
        endif
    endif
    ; Always set the player as essential to allow bleedout-based revives.
    player.GetActorBase().SetEssential(True)
    ; Persist last known name for tooling/debug.
    if IsValidPlayerName(name)
        JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid, name)
        JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid, name)
        JsonUtil.Save(SharedPath)
        JsonUtil.Save(MirrorPath)
    endif
EndFunction

; Schedule the load and startup messages after a game load.  This helper toggles
; the load message flag and sets the appropriate timers, then arms the startup
; gate and queues the next update.  It uses the allowLoadMsg parameter to
; determine whether load messages should be shown at all.
Function ScheduleLoadAndStartupMessages(Bool isLoadGame, Actor player, String guid, Bool allowLoadMsg)
    if isLoadGame && allowLoadMsg
        _pendingLoadMessage = True
        _loadMessageAt = Utility.GetCurrentRealTime() + LoadMessageDelay
    else
        _pendingLoadMessage = False
    endif
    ; Always schedule the startup message using the shared scheduler.
    TryScheduleStartupMessage(player)
    ; Arm the startup gate to retry scheduling once gameplay is ready.
    _startupGateActive = True
    _startupGateTriesLeft = 60
    ; Ensure the update loop is rescheduled.
    _updateQueued = False
    QueueUpdate(BleedoutPollSeconds)
EndFunction

Function GameReloaded(Bool isLoadGame)
    LoadLogConfig()
    Actor player = Game.GetPlayer()
    if !player
        LogMsg(LOG_ERR(), "OnPlayerLoadGame: player None (alias not filled yet?)")
        return
    endif
    String name = player.GetDisplayName()
    String guid = GetCharacterGUID(player)
    LogMsg(LOG_INFO(), "OnPlayerLoadGame: Player=" + name + " GUID=" + guid)
    ; If the player already has a valid name, finalise the provisional GUID immediately.
    if guid != "" && IsValidPlayerName(name)
        FinalizeCharacterIdentity(player, guid)
    endif
    ; Reset transient state if this is a new character in the same session.
    if guid != "" && guid != _sessionGuid
        ResetTransientStateForNewGuid(guid)
    endif
    ; Persist metadata: active GUID, signature and name mapping.
    String sig = BuildCharacterSignature(player)
    PersistGuidMetadata(player, guid, name, sig)
    ; One-time reconcile: heal deleted/tampered stores and sync character sheet death AV.
    ; Perform an immediate sync and schedule a deferred resync 10 seconds later.  The deferred
    ; resync ensures the Character Sheet value is corrected after other systems (e.g. RaceMenu
    ; or plugins) have had time to settle following a load.
    if guid != ""
        Int deathsNow = _GetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), 0)
        _SyncDeathAV(player, deathsNow)
        ; schedule a deferred death‑AV resync ten seconds from now
        _pendingDeathResync = True
        _deathResyncAt = Utility.GetCurrentRealTime() + 10.0
    endif
    ; Sync current character and enforce essential/quest state.
    if guid != ""
        SyncCurrentCharacterImmediate(guid)
        SetEssentialAndStartQuestIfNeeded(player, guid, name)
    endif
    ; Perform one-time global heal/sync after load.
    if !_globalSyncDoneThisSession
        _globalSyncDoneThisSession = True
        SyncAllKnownCharactersOnce()
    endif
    EnsureVisibleLogsOnLoad()
    LogPropsOnce()
    ; Determine whether load messages should be allowed (only after the startup poem has been shown).
    Bool allowLoadMsg = False
    if guid != ""
        Int poemTok = _GetAuthInt(player, _PoemShownStorageKey(guid), GetPoemShownKeyById(guid), 0)
        allowLoadMsg = (_DecodeFlag(poemTok) != 0)
    endif
    ; Schedule load and startup messages using the helper.
    ScheduleLoadAndStartupMessages(isLoadGame, player, guid, allowLoadMsg)
    return
EndFunction


;===========================

;== SKYRIM CHARACTER SHEET ==

;===========================

Function _SyncDeathAV(Actor player, int deaths)
    ; Mirror authoritative deaths into DEPRECATED05 so UI mods can read it (display-only; not an authority source).
    ; This synchronization is optional and controlled via the config key EnableCharacterSheetCompatibility.  
    ; When disabled, this function returns immediately.
	if !player || deaths < 0
		return
	endif
    if !_enableCharacterSheetCompatibility
        ; Skip syncing character sheet actor value when disabled
        return
    endif

	Float cur = player.GetActorValue(_deathAVName)
	Float d = deaths as Float
	if cur != d
		player.SetActorValue(_deathAVName, d)
	endif
EndFunction

;===========================

;== ON PLAYER SLEEP START ==

;===========================

Function HandleSleepStart(float afSleepStartTime, float afDesiredSleepEndTime)
	Actor player = Game.GetPlayer()
	if !player
		LogMsg(LOG_ERR(), "OnSleepStart: player None")
		return
	endif

	String name = player.GetDisplayName()
	String guid = GetCharacterGUID(player)
	if guid == ""
		LogMsg(LOG_ERR(), "OnSleepStart: missing CharacterGUID")
		return
	endif

	; Keep latest name for tooling/debug (do not key storage off the name)
	if IsValidPlayerName(name)
		JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid, name)
		JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid, name)
	else
		name = "Player"
	endif

	LogMsg(LOG_INFO(), "OnSleepStart: sleep detected (no respawn reset in realtime mode); Player=" + name + " GUID=" + guid)

	_pendingDisableRespawn = False
	_deathEventLocked = False

	_revivePending = False
	_postResurrectRecastPending = False
	_pendingStartupMessage = False
	_pendingRespawnWarning = False
	_respawnWarningArmed = False
	_updateQueued = False
	QueueUpdate(BleedoutPollSeconds)
EndFunction

;===========================

;== ON PLAYER DYING ==

;===========================

Function HandlePlayerDying(Actor akKiller)
	Actor player = Game.GetPlayer()
	if !player
		LogMsg(LOG_ERR(), "OnDying: player None")
		return
	endif

	if _deathEventLocked
		LogMsg(LOG_DBG(), "OnDying ignored; deathEventLocked")
		return
	endif
	_deathEventLocked = True

    String name = player.GetDisplayName()
    String guid = GetCharacterGUID(player)
    ; With provisional GUIDs, we no longer ignore deaths when the display name is a placeholder.
    ; If the name is not valid (e.g., empty or Prisoner), substitute a generic label for logging.
    if !IsValidPlayerName(name)
        name = "Player"
    endif
    ; A provisional GUID is always generated by GetCharacterGUID; bail only if something went seriously wrong.
    if guid == ""
        LogMsg(LOG_ERR(), "OnDying: missing CharacterGUID; ignoring")
        _deathEventLocked = False
        return
    endif

    LogMsg(LOG_INFO(), "OnDying: Player=" + name + " GUID=" + guid)
	SyncCurrentCharacterImmediate(guid)

	int usedTok = _GetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), 0)
	int used = _DecodeFlag(usedTok)
	LogMsg(LOG_INFO(), "OnDying: respawnUsed=" + used)

	if used == 0
		LogMsg(LOG_INFO(), "OnDying: free respawn branch; marking used=1; scheduling quest stop")
		; SAFETY: ensure free-respawn works even if essential/quest state drifted during this session
		if RespawnQuest && !RespawnQuest.IsRunning()
			RespawnQuest.Start()
		endif
		player.GetActorBase().SetEssential(True)
		int nowSec = Utility.GetCurrentRealTime() as Int
		_SetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), _EncodeFlag(nowSec, 1), True)

		StartRespawnCooldown(player, guid)
				_pendingRespawnWarning = True
		_respawnWarningArmed = False
		_pendingDisableRespawn = True

		_updateQueued = False
		QueueUpdate(DisableRespawnPollSeconds)
		return
	endif

	int souls = player.GetActorValue("DragonSouls") as int
	LogMsg(LOG_INFO(), "OnDying: no free respawn; DragonSouls=" + souls)

	if souls > 0
		if !_revivePending
			LogMsg(LOG_INFO(), "OnDying: scheduling dragon-soul revive job")
			_revivePending = True
			_reviveConsumedSoul = False
			_postResurrectRecastPending = False

			_updateQueued = False
			QueueUpdate(ReviveDelaySeconds)
		endif
		return
	endif

	LogMsg(LOG_INFO(), "OnDying: TRUE DEATH (no respawn + no souls) -> log and quit")
	TrueDeathAndQuit(player)
EndFunction


;===========================

;== RESPAWN WARNING FLAVOR ==

;===========================

String Function GetRespawnFlavorLine()


    ; Determine how many flavour entries to load.
    String[] lines = new String[50]
    Int i = 0
    while i < 50
        String k = "RespawnFlavor_" + i
        if JsonUtil.HasStringValue(RespawnFlavorPath, k)
            lines[i] = JsonUtil.GetStringValue(RespawnFlavorPath, k, "")
        endif
        i += 1
    endwhile

    ; Select a random entry from the available range.  If the chosen
    ; entry is empty, fall back to a simple generic message.  Keeping
    ; the fallback message here avoids embedding a large baked-in list.
    Int count = lines.Length
    if count <= 0
        return "You narrowly escaped death."
    endif
    Int idx = Utility.RandomInt(0, count - 1)
    String msg = lines[idx]
    if msg == ""
        msg = "You narrowly escaped death."
    endif
    return msg
EndFunction

;===========================

;== BLEEDOUT DETECTION HELP ==

;===========================

Function TrueDeathAndQuit(Actor player)
	if !player
		return
	endif

	String name = player.GetDisplayName()
	String guid = GetCharacterGUID(player)
	if guid == ""
		LogMsg(LOG_ERR(), "TRUE DEATH: missing CharacterGUID; exiting without logging state")
		Debug.MessageBox("SOVNGARDE CALLS\n\nDeath occurred but IronSoul could not determine character identity. Exiting to prevent state corruption.")
		Utility.Wait(2.0)
		Debug.QuitGame()
		return
	endif

	if !IsValidPlayerName(name)
		name = "Player"
	endif

	LogMsg(LOG_INFO(), "TRUE DEATH: logging and exiting game for " + name + " GUID=" + guid)
	IncrementTrueDeath(player, guid, name)

	; TRUE DEATH cycle reset: allow a new free respawn next run, and clear cooldown (load must not do this)
	ResetRespawnUsed(player, guid)
	Int nowSec = Utility.GetCurrentRealTime() as Int
	_SetAuthInt(player, _CooldownPlayedStorageKey(guid), GetCooldownPlayedKeyById(guid), _EncodePlayed(nowSec, 0), False)
	_SetAuthInt(player, _CooldownLastStorageKey(guid), GetCooldownLastKeyById(guid), nowSec, True)

	Utility.Wait(1.0)

    player.GetActorBase().SetEssential(False)

	int deathsNow = _GetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), 0)
    ; If the character has reached or exceeded the maximum allowed deaths then
    ; immediately display the final death warning used on load (this mirrors
    ; the load‑screen behaviour where a character with no lives left sees
    ; "NO STRENGTH REMAINS TO RISE" and is returned to the menu).  Otherwise
    ; show the normal Sovngarde call with the current death count.
    if deathsNow >= _maxLives
        Debug.MessageBox("NO STRENGTH REMAINS TO RISE\nYOUR SOUL IS CLAIMED\nSOVNGARDE AWAITS THE FALLEN")
    else
	    Debug.MessageBox("SOVNGARDE CALLS\n" + "\nDeath Count: " + deathsNow)
    endif

    ; Give the player time to read the message box before quitting.  During this wait we ensure
    ; that all JSON state is flushed to disk so deaths and cooldowns are persisted.  Without
    ; explicitly saving here, the VM may exit before writes complete.
    JsonUtil.Save(SharedPath)
    JsonUtil.Save(MirrorPath)
	player.SetUnconscious(True)
	Utility.Wait(2.0)
	Debug.QuitGame()
EndFunction

Function HandleBleedoutRespawn(Actor player)
	if !player
		return
	endif

	String name = player.GetDisplayName()
	String guid = GetCharacterGUID(player)
	if guid == ""
		return
	endif

	; keep name for logs only
	if IsValidPlayerName(name)
		JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid, name)
		JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid, name)
	endif

	SyncCurrentCharacterImmediate(guid)

	int usedTok = _GetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), 0)
	int used = _DecodeFlag(usedTok)
	if used == 0
		LogMsg(LOG_INFO(), "BLEEDOUT: free respawn detected; marking used=1; scheduling quest stop")
		Int nowSec = Utility.GetCurrentRealTime() as Int
		_SetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), _EncodeFlag(nowSec, 1), True)

		; Show the Iron Soul poem only after the first free respawn (one-time per character)
		Int poemTok = _GetAuthInt(player, _PoemShownStorageKey(guid), GetPoemShownKeyById(guid), 0)
		if _DecodeFlag(poemTok) == 0
			String poem = "Some are said to carry an Iron Soul."
			poem += "\nSuch souls do not yield as others do."
			poem += "\nThey may fall, yet not be claimed at once."
			poem += "\nEach return draws deeper from the iron."
			poem += "\n\nYour soul may endure " + _maxLives + " deaths."
			poem += "\nWhen it is spent, nothing remains to rise."
			Utility.Wait(2.0)
			Debug.MessageBox(poem)
			; Also show the normal respawn reminder immediately on the first free respawn
			; (otherwise it can be delayed/suppressed while the poem MessageBox is open or until RespawnQuest stops)
			_pendingRespawnWarning = False
			_respawnWarningArmed = False
			_SetAuthInt(player, _PoemShownStorageKey(guid), GetPoemShownKeyById(guid), _EncodeFlag(nowSec, 1), True)
		endif

		StartRespawnCooldown(player, guid)
		_pendingRespawnWarning = True
		_respawnWarningArmed = False
		_pendingDisableRespawn = True

		_updateQueued = False
		QueueUpdate(DisableRespawnPollSeconds)
	else
		LogMsg(LOG_INFO(), "BLEEDOUT: respawn already used -> checking dragon souls")

		int souls = player.GetActorValue("DragonSouls") as int
		LogMsg(LOG_INFO(), "BLEEDOUT: DragonSouls=" + souls)

		if souls > 0
			LogMsg(LOG_INFO(), "BLEEDOUT: starting dragon-soul revive flow")

			if !_revivePending && !_postResurrectRecastPending
				_reviveConsumedSoul = False
				_revivePending = True

				_updateQueued = False
				QueueUpdate(ReviveDelaySeconds)
			endif
		else
			LogMsg(LOG_INFO(), "BLEEDOUT: no souls -> TRUE DEATH now")
			TrueDeathAndQuit(player)
		endif
	endif
EndFunction

;===========================

;== ON UPDATE (JOB RUNNER) ==

;===========================

;---------------------------------------------------------------
; Helpers for the OnUpdate job runner.  Breaking the monolithic
; event into well-named helper functions improves readability,
; testability, and maintainability.  Each helper returns True if
; it schedules its own update and the caller should return early.
;---------------------------------------------------------------

Bool Function HandlePlayerMissing(Actor player)
    ; Reset all job flags and schedule an update when the player
    ; reference is missing.  Returns True to signal early exit.
    if !player
        LogMsg(LOG_ERR(), "OnUpdate: player None; clearing state")
        _revivePending = False
        _pendingDisableRespawn = False
        _postResurrectRecastPending = False
        _pendingLoadMessage = False
        _pendingStartupMessage = False
        _pendingRespawnWarning = False
        _respawnWarningArmed = False
        _deathEventLocked = False
        _startupGateActive = False
        _startupGateTriesLeft = 0
        QueueUpdate(BleedoutPollSeconds)
        return True
    endif
    return False
EndFunction

Function FailSafeUnlockIfStable(Actor player)
    ; If the player is stable again and no death-related jobs are pending,
    ; unlock death handling.  Prevents stuck locks suppressing future deaths.
    if _deathEventLocked
        if !_revivePending && !_postResurrectRecastPending && !_pendingDisableRespawn
            if !player.IsDead() && !player.IsBleedingOut()
                _deathEventLocked = False
            endif
        endif
    endif
EndFunction

Function CheckStartupAliasPending(Actor player)
    ; Startup message fallback if alias fills after OnInit.
    if _startupCheckPending
        _startupCheckPending = False
        TryScheduleStartupMessage(player)
    endif
EndFunction

Bool Function HandleStartupGate(Actor player)
    ; Wait until gameplay is actually ready (3D loaded and not in menu)
    ; then retry scheduling the startup message.  Returns True if it
    ; scheduled another update and caller should return early.
    if _startupGateActive
        _startupGateTriesLeft -= 1
        if _startupGateTriesLeft <= 0
            _startupGateActive = False
        else
            if player.Is3DLoaded() && !Utility.IsInMenuMode()
                _startupGateActive = False
                TryScheduleStartupMessage(player)
            else
                _updateQueued = False
                QueueUpdate(1.0)
                return True
            endif
        endif
    endif
    return False
EndFunction

Function HandleRespawnCooldown(Actor player)
    ; Job R: realtime respawn cooldown tick
    String guidR = GetCharacterGUID(player)
    if guidR != ""
        TickRespawnCooldown(player, guidR)
    endif
EndFunction

Function HandleLoadMessage(Actor player)
    ; Job A: timed load‑game message.
    if _pendingLoadMessage && !_disableLoadMessage
        if Utility.GetCurrentRealTime() >= _loadMessageAt
            _pendingLoadMessage = False
            Bool suppress = False
            ; suppress load messages if the startup message is pending or has just been shown recently
            if _pendingStartupMessage
                suppress = True
            endif
            Float sinceStartup = Utility.GetCurrentRealTime() - _startupMessageShownAt
            if sinceStartup < 3.0
                suppress = True
            endif
            if !suppress
                String name = player.GetDisplayName()
                String guid = GetCharacterGUID(player)
                if guid == ""
                    suppress = True
                else
                    ; update last known name for tooling/debug
                    if IsValidPlayerName(name)
                        JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid, name)
                        JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid, name)
                    else
                        name = "Player"
                    endif
                    ; suppress load messages until the startup poem (first respawn) has been shown
                    Int poemTok = _GetAuthInt(player, _PoemShownStorageKey(guid), GetPoemShownKeyById(guid), 0)
                    if _DecodeFlag(poemTok) == 0
                        suppress = True
                    endif
                endif
                if !suppress
                    Int deaths = _GetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), 0)
                    Int usedTok = _GetAuthInt(player, _RespawnUsedStorageKey(guid), GetRespawnKeyById(guid), 0)
                    Int used = _DecodeFlag(usedTok)
                    ; If all lives are gone, perform the fatal quit sequence
                    if deaths >= _maxLives
                        Debug.MessageBox("NO STRENGTH REMAINS TO RISE\nYOUR SOUL IS CLAIMED\nSOVNGARDE AWAITS THE FALLEN")
                        Game.QuitToMainMenu()
                    else
                        String msg = "Your Iron Soul endures. Name: " + name + " Deaths: " + deaths
                        Debug.Notification(msg)
                        if used > 0 && !_disableFatalReminderMessage
                            Debug.Notification("Your recent trial has left you shaken.")
                        endif
                    endif
                endif
            endif
        endif
    endif
EndFunction

Bool Function HandleStartupMessage(Actor player)
    ; Job S: one‑time startup message.  Returns True if an update
    ; was scheduled due to waiting conditions.  This handler is
    ; responsible for showing the "Iron Soul initialized." notification
    ; exactly once per character, after gameplay is ready and the
    ; character identity has been finalised.
    
    ; If there is no pending startup message, nothing to do
    if !_pendingStartupMessage
        return False
    endif

    Float now = Utility.GetCurrentRealTime()

    ; Wait until the scheduled time
    if now < _startupMessageAt
        return False
    endif

    ; Wait until gameplay is ready: not in a menu, player exists, 3D loaded, and not dead
    if Utility.IsInMenuMode() || !player || !player.Is3DLoaded() || player.IsDead()
        _startupMessageAt = now + 1.0
        _updateQueued = False
        QueueUpdate(1.0)
        return True
    endif

    ; Acquire a stable GUID.  If identity is still provisional, defer until a GUID is available.
    String guid = GetCharacterGUID(player)
    if guid == ""
        _startupMessageAt = now + 1.0
        _updateQueued = False
        QueueUpdate(1.0)
        return True
    endif

    ; Check if the startup message has already been handled for this GUID
    String startupKey = GetStartupShownKeyById(guid)
    int shownS = JsonUtil.GetIntValue(SharedPath, startupKey, 0)
    int shownM = JsonUtil.GetIntValue(MirrorPath, startupKey, 0)
    int shown = shownS
    if shownM > shown
        shown = shownM
    endif
    if shown != 0
        ; Already shown or suppressed: clear the pending flag and return
        _pendingStartupMessage = False
        return False
    endif

    ; Update last known name if it is valid.  This is useful for tooling/debug purposes
    String pName = player.GetDisplayName()
    if IsValidPlayerName(pName)
        JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid, pName)
        JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid, pName)
        JsonUtil.Save(SharedPath)
        JsonUtil.Save(MirrorPath)
    endif

    ; Determine the current number of deaths and update the death actor value if enabled
    int deathsNow = _GetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), 0)
    _SyncDeathAV(player, deathsNow)

    ; Show the notification only if the character still has lives remaining
    if deathsNow < _maxLives
        Debug.Notification("Iron Soul initialized.")
        _startupMessageShownAt = now
        ; Once the init notice is shown, do not show a load message immediately afterwards
        _pendingLoadMessage = False
    endif

    ; Whether or not the notification displayed, mark the startup message as handled so it does not repeat
    JsonUtil.SetIntValue(SharedPath, startupKey, 1)
    JsonUtil.SetIntValue(MirrorPath, startupKey, 1)
    JsonUtil.Save(SharedPath)
    JsonUtil.Save(MirrorPath)

    ; Clear the pending flag now that the job has completed
    _pendingStartupMessage = False
    return False
EndFunction

Function HandleRespawnWarning(Actor player)
    ; Job W: delayed free‑respawn warning (after respawn completes)
    if _pendingRespawnWarning && _respawnWarningArmed
        if Utility.GetCurrentRealTime() >= _respawnWarningAt
            if !Utility.IsInMenuMode() && !player.IsDead()
                _pendingRespawnWarning = False
                _respawnWarningArmed = False
                if !_disableFatalReminderMessage
                    Debug.MessageBox(GetRespawnFlavorLine() + "\nPushing your luck again so soon would prove fatal.")
                endif
            endif
        endif
    endif
EndFunction

Bool Function HandleBleedoutDetection(Actor player)
    ; Job A2: detect bleedout‑based "fake death" (essential/protected)
    Bool nowBleed = player.IsBleedingOut()
    ; Entering bleedout
    if nowBleed && !_wasBleedingOut
        LogMsg(LOG_INFO(), "BLEEDOUT: entered bleedout")
        _bleedoutArmed = True
        String n0 = player.GetDisplayName()
        String guid0 = GetCharacterGUID(player)
        if guid0 != ""
            if IsValidPlayerName(n0)
                JsonUtil.SetStringValue(SharedPath, "LastKnownName:" + guid0, n0)
                JsonUtil.SetStringValue(MirrorPath, "LastKnownName:" + guid0, n0)
            endif
            int usedTok0 = _GetAuthInt(player, _RespawnUsedStorageKey(guid0), GetRespawnKeyById(guid0), 0)
            int used0 = _DecodeFlag(usedTok0)
            if used0 > 0
                int souls0 = player.GetActorValue("DragonSouls") as int
                LogMsg(LOG_INFO(), "BLEEDOUT ENTER: used=" + used0 + " souls=" + souls0)
                if souls0 <= 0
                    LogMsg(LOG_INFO(), "BLEEDOUT ENTER: no souls -> TRUE DEATH immediately")
                    _deathEventLocked = True
                    TrueDeathAndQuit(player)
                    return True
                endif
                ; If a prior respawn has already been used, OnDying may never fire (essential/protected bleedout).
                ; If we still have dragon souls, schedule our revive flow immediately.
                LogMsg(LOG_INFO(), "BLEEDOUT ENTER: souls available -> scheduling dragon‑soul revive")
                _deathEventLocked = True
                _revivePending = True
                _reviveConsumedSoul = False
                _postResurrectRecastPending = False
                ; Latch bleedout state before returning so we don't re‑trigger "entered bleedout" every tick
                _wasBleedingOut = True
                _updateQueued = False
                QueueUpdate(ReviveDelaySeconds)
                return True
            endif
        endif
    endif
    ; Exiting bleedout
    if !nowBleed && _wasBleedingOut && _bleedoutArmed
        LogMsg(LOG_INFO(), "BLEEDOUT: exited bleedout (respawn completed)")
        _bleedoutArmed = False
        if _dragonSoulResolvedThisBleedout
            LogMsg(LOG_INFO(), "BLEEDOUT EXIT: resolved by dragon soul; skipping respawn handler")
            _dragonSoulResolvedThisBleedout = False
        else
            if !_revivePending && !_pendingDisableRespawn
                HandleBleedoutRespawn(player)
            endif
        endif
        _deathEventLocked = False
    endif
    _wasBleedingOut = nowBleed
    return False
EndFunction

Bool Function HandleDisableRespawn(Actor player)
    ; Job B: stop RespawnQuest after respawn finishes
    if _pendingDisableRespawn
        LogMsg(LOG_DBG(), "JOB B: pending disable respawn. dead=" + player.IsDead() + " bleed=" + player.IsBleedingOut())
        ; If the player is truly dead (death screen / reload), respawn did not complete; stop polling.
        if player.IsDead() && !player.IsBleedingOut()
            LogMsg(LOG_INFO(), "JOB B: player truly dead; clearing pending disable-respawn state")
            _pendingDisableRespawn = False
            _pendingRespawnWarning = False
            _respawnWarningArmed = False
            return True
        endif
        if !player.IsBleedingOut() && !player.IsDead()
            if RespawnQuest && RespawnQuest.IsRunning()
                LogMsg(LOG_INFO(), "JOB B: stopping RespawnQuest")
                RespawnQuest.Stop()
            else
                LogMsg(LOG_INFO(), "JOB B: RespawnQuest not running/None")
            endif
            ; arm delayed warning AFTER respawn completes
            if _pendingRespawnWarning && !_respawnWarningArmed
                _respawnWarningArmed = True
                _respawnWarningAt = Utility.GetCurrentRealTime() + RespawnWarningDelaySeconds
            endif
            _pendingDisableRespawn = False
            _deathEventLocked = False
        else
            _updateQueued = False
            QueueUpdate(DisableRespawnPollSeconds)
            return True
        endif
    endif
    return False
EndFunction

Bool Function HandlePostResurrectRecast(Actor player)
    ; Job C: post‑resurrect recast (reapply VFX, stagger, cloak)
    if _postResurrectRecastPending
        if player.IsDead()
            _updateQueued = False
            QueueUpdate(0.10)
            return True
        endif
        LogMsg(LOG_INFO(), "JOB C: post-resurrect recast (VFX/Stagger/Cloak)")
        if DragonSoulVFXSpell
            DragonSoulVFXSpell.Cast(player, player)
        endif
        if ReviveStaggerSpell
            ReviveStaggerSpell.Cast(player, player)
        endif
        if ReviveCloakSpell
            ReviveCloakSpell.Cast(player, player)
        endif
        _postResurrectRecastPending = False
        _deathEventLocked = False
    endif
    return False
EndFunction

Bool Function HandleReviveFlow(Actor player)
    ; Job D: dragon‑soul revive flow
    if _revivePending
        LogMsg(LOG_DBG(), "JOB D: revive pending. IsDead=" + player.IsDead())
        if !player.IsDead() && !player.IsBleedingOut()
            _updateQueued = False
            QueueUpdate(0.15)
            return True
        endif
        if !_reviveConsumedSoul
            int soulsNow = player.GetActorValue("DragonSouls") as int
            LogMsg(LOG_INFO(), "JOB D: consuming soul. soulsNow=" + soulsNow)
            if soulsNow > 0
                player.ModActorValue("DragonSouls", -1)
                _reviveConsumedSoul = True
                if ShowDragonSoulPopup
                    Debug.MessageBox("A dragon soul burns within you.\nDragon Souls Remaining: " + (soulsNow - 1))
                endif
            else
                _revivePending = False
                LogMsg(LOG_ERR(), "JOB D: no souls remaining; TRUE DEATH -> log and quit")
                TrueDeathAndQuit(player)
                return True
            endif
        endif
        if DragonSoulVFXSpell
            DragonSoulVFXSpell.Cast(player, player)
        endif
        if ReviveStaggerSpell
            ReviveStaggerSpell.Cast(player, player)
        endif
        if ReviveCloakSpell
            ReviveCloakSpell.Cast(player, player)
        endif
        LogMsg(LOG_INFO(), "JOB D: reviving now")
        if player.IsDead()
            player.Resurrect()
        else
            ; bleedout/protected: force wake‑up and restore stats
            player.SetUnconscious(False)
        endif
        _dragonSoulResolvedThisBleedout = True
        player.RestoreActorValue("Health",   player.GetBaseActorValue("Health") + 500)
        player.RestoreActorValue("Magicka", player.GetBaseActorValue("Magicka") + 500)
        player.RestoreActorValue("Stamina", player.GetBaseActorValue("Stamina") + 500)
        _postResurrectRecastPending = True
        _revivePending = False
        _updateQueued = False
        QueueUpdate(PostResurrectRecastDelay)
        return True
    endif
    return False
EndFunction

;===========================

;== ON UPDATE (JOB RUNNER) ==

;===========================

Event OnUpdate()
    _updateQueued = False
    Actor player = Game.GetPlayer()
    ; Check for missing player and reset state
    if HandlePlayerMissing(player)
        return
    endif
    ; Defer initialisation bootstrap if necessary
    if BootstrapTick()
        return
    endif

    ; Deferred death‑AV resync: if a load scheduled a delayed sync, perform it once when
    ; the specified real‑time has been reached.  We check early in the update loop so the
    ; correct death count is written before other handlers run.  After syncing once the
    ; pending flag is cleared.
    if _pendingDeathResync
        Float nowRT = Utility.GetCurrentRealTime()
        if nowRT >= _deathResyncAt
            _pendingDeathResync = False
            if player
                String guidR = GetCharacterGUID(player)
                if guidR != ""
                    Int dNow = _GetAuthInt(player, _DeathsStorageKey(guidR), GetDeathKeyById(guidR), 0)
                    _SyncDeathAV(player, dNow)
                endif
            endif
        endif
    endif
    ; Fail‑safe: unlock death handling if player is stable
    FailSafeUnlockIfStable(player)
    ; Check for startup alias fallback scheduling
    CheckStartupAliasPending(player)
    ; Wait for 3D load and non‑menu gating
    if HandleStartupGate(player)
        return
    endif
    ; Respawn cooldown tick
    HandleRespawnCooldown(player)
    ; Timed load‑message handler
    HandleLoadMessage(player)
    ; Timed startup message handler
    if HandleStartupMessage(player)
        return
    endif
    ; Delayed free‑respawn warning
    HandleRespawnWarning(player)
    ; Bleedout detection and possible immediate actions
    if HandleBleedoutDetection(player)
        return
    endif
    ; Disable RespawnQuest job
    if HandleDisableRespawn(player)
        return
    endif
    ; Post‑resurrect recast job
    if HandlePostResurrectRecast(player)
        return
    endif
    ; Dragon‑soul revive job
    if HandleReviveFlow(player)
        return
    endif
    ; Very low‑frequency maintenance sync.  Keeps registry metadata (e.g. last level) fresh for identity recovery.
    SyncCurrentCharacterMaintenance()
    RescheduleIfJobsRemain()
EndEvent

;===========================

;== TRUE DEATH INCREMENT ==

;===========================

Function IncrementTrueDeath(Actor player, String guid, String displayName)
	if !player || guid == ""
		return
	endif

	int deaths = _GetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), 0) + 1

	_SetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), deaths, True)

	_SyncDeathAV(player, deaths)

	if IsValidPlayerName(displayName)
		String visFile = VisibleLogPath + "/" + displayName
		JsonUtil.SetIntValue(visFile, "Deaths", deaths)
		JsonUtil.Save(visFile)
	endif

	LogMsg(LOG_INFO(), "IncrementTrueDeath: GUID=" + guid + " deaths=" + deaths)
EndFunction

;===========================

;== SYNC TRACKING FILES ==

;===========================

;===========================

;== CHARACTER REGISTRY + GLOBAL SYNC ==

;===========================

Int Function RegistryGetCount(String regPath)
	return JsonUtil.GetIntValue(regPath, "Count", 0)
EndFunction
String Function RegistryGetName(String regPath, Int idx)
	return JsonUtil.GetStringValue(regPath, "Name_" + idx, "")
EndFunction

;===========================

;== REGISTRY SNAPSHOT / INTEGRITY ==

;===========================

String Function GetRegistryCheckPath(String regPath)
	if regPath == RegistrySharedPath
		return RegistrySharedCheckPath
	endif
	return RegistryMirrorCheckPath
EndFunction
Bool Function RegistrySnapshotExists(String checkPath)
	return JsonUtil.HasIntValue(checkPath, "Count") && JsonUtil.HasIntValue(checkPath, "Version")
EndFunction

Function WriteRegistrySnapshot(String regPath)
	String checkPath = GetRegistryCheckPath(regPath)

	int c = RegistryGetCount(regPath)
	JsonUtil.SetIntValue(checkPath, "Version", RegistryFormatVersion)
	JsonUtil.SetIntValue(checkPath, "Count", c)

	; Store a shadow copy of the registry GUIDs as the authoritative snapshot.
	int i = 0
	while i < c
		String n = RegistryGetName(regPath, i)
		JsonUtil.SetStringValue(checkPath, "Shadow_Name_" + i, n)
		i += 1
	endwhile

	; Clear any leftover shadow entries beyond count (best effort)
	int j = c
	while j < (c + 10)
		JsonUtil.SetStringValue(checkPath, "Shadow_Name_" + j, "")
		j += 1
	endwhile

	JsonUtil.Save(checkPath)
EndFunction

Function RestoreRegistryFromSnapshot(String regPath)
	String checkPath = GetRegistryCheckPath(regPath)
	if !RegistrySnapshotExists(checkPath)
		return
	endif

	int c = JsonUtil.GetIntValue(checkPath, "Count", 0)
	JsonUtil.SetIntValue(regPath, "Version", JsonUtil.GetIntValue(checkPath, "Version", RegistryFormatVersion))
	JsonUtil.SetIntValue(regPath, "Count", c)

	int i = 0
	while i < c
		String n = JsonUtil.GetStringValue(checkPath, "Shadow_Name_" + i, "")
		JsonUtil.SetStringValue(regPath, "Name_" + i, n)
		i += 1
	endwhile

	; Clear a few extra slots (best effort)
	int j = c
	while j < (c + 10)
		JsonUtil.SetStringValue(regPath, "Name_" + j, "")
		j += 1
	endwhile

	JsonUtil.Save(regPath)
EndFunction
Bool Function ValidateOrHealRegistry(String regPath)
	String checkPath = GetRegistryCheckPath(regPath)

	; If snapshot exists, enforce it: if registry is missing or differs, restore from snapshot.
	if RegistrySnapshotExists(checkPath)
		int snapCount = JsonUtil.GetIntValue(checkPath, "Count", 0)
		int regCount  = RegistryGetCount(regPath)

		Bool mismatch = False
		if regCount != snapCount
			mismatch = True
		else
			int i = 0
			Bool _breakMismatch = False
			while i < snapCount && !_breakMismatch
				String rn = RegistryGetName(regPath, i)
				String sn = JsonUtil.GetStringValue(checkPath, "Shadow_Name_" + i, "")
				if rn != sn
					mismatch = True
                    ; Exit the loop early on first mismatch
					_breakMismatch = True
				endif
				i += 1
			endwhile
		endif

		if mismatch
			LogMsg(LOG_INFO(), "Registry integrity mismatch for " + regPath + " -> restoring from snapshot")
			RestoreRegistryFromSnapshot(regPath)
		endif

		return True
	endif

	; No snapshot yet: create one from current registry contents (even if empty),
	; so future manual edits can be detected and reverted.
	WriteRegistrySnapshot(regPath)
	return True
EndFunction
Bool Function RegistryHasName(String regPath, String n)
	int c = RegistryGetCount(regPath)
	int i = 0
	while i < c
		if RegistryGetName(regPath, i) == n
			return True
		endif
		i += 1
	endwhile
	return False
EndFunction
Bool Function RegistryAddName(String regPath, String n)
    ; Skip only blank names. Under the provisional GUID system we no longer treat
    ; placeholder names like "Prisoner" as special – they are considered valid identifiers.
    if n == ""
        return False
    endif

	int c = RegistryGetCount(regPath)
	if c >= RegistryMaxNames
		return False
	endif

	; avoid duplicates
	if RegistryHasName(regPath, n)
		return False
	endif

	JsonUtil.SetStringValue(regPath, "Name_" + c, n)
	JsonUtil.SetIntValue(regPath, "Count", c + 1)
	JsonUtil.Save(regPath)
	WriteRegistrySnapshot(regPath)
	return True
EndFunction
; NOTE: parameter is the character GUID (not the display name)
Function RegisterCharacterGuid(String guid)
    ; guid should always be non-empty; skip only if blank
    if guid == ""
        return
    endif

	; Ensure BOTH registries learn about the character GUID.
	; If either registry was deleted/reset, the other will repopulate it over time.
	RegistryAddName(RegistrySharedPath, guid)
	RegistryAddName(RegistryMirrorPath, guid)
	; ensure snapshots exist even if guid already present
	ValidateOrHealRegistry(RegistrySharedPath)
	ValidateOrHealRegistry(RegistryMirrorPath)
EndFunction
Int Function BuildRegistryUnion(String[] outNames)
	; Fills outNames with the union of Shared+Mirror registry GUIDs. Returns count.
	int outCount = 0

	; Enforce snapshot integrity first (reverts manual edits to registries)
	ValidateOrHealRegistry(RegistrySharedPath)
	ValidateOrHealRegistry(RegistryMirrorPath)

	; helper: add if not already in outNames
	; (Papyrus has no sets, so we do a linear scan)
	; --- Shared registry first ---
	int cS = RegistryGetCount(RegistrySharedPath)
	int i = 0
	while i < cS
		String n = RegistryGetName(RegistrySharedPath, i)
        ; ignore blanks; provisional GUIDs are now stable identifiers so "Prisoner" is not used
        if n != ""
			Bool found = False
			int j = 0
			Bool _breakFound = False
			while j < outCount && !_breakFound
				if outNames[j] == n
					found = True
                    ; Break out of the inner loop once found to avoid redundant scans
					_breakFound = True
				endif
				j += 1
			endwhile
			if !found && outCount < RegistryMaxNames
				outNames[outCount] = n
				outCount += 1
			endif
		endif
		i += 1
	endwhile

	; --- Mirror registry ---
	int cM = RegistryGetCount(RegistryMirrorPath)
	i = 0
	while i < cM
		String n2 = RegistryGetName(RegistryMirrorPath, i)
        if n2 != ""
			Bool found2 = False
			int j2 = 0
			Bool _breakFound2 = False
			while j2 < outCount && !_breakFound2
				if outNames[j2] == n2
					found2 = True
                    ; Break out of the inner loop once found to avoid redundant scans
					_breakFound2 = True
				endif
				j2 += 1
			endwhile
			if !found2 && outCount < RegistryMaxNames
				outNames[outCount] = n2
				outCount += 1
			endif
		endif
		i += 1
	endwhile

	return outCount
EndFunction

Function EnsureBothRegistriesContainUnion(String[] names, int count)
	int i = 0
	while i < count
		String n = names[i]
        ; only skip blanks; placeholder names like "Prisoner" are not special any more
        if n != ""
            if !RegistryHasName(RegistrySharedPath, n)
                RegistryAddName(RegistrySharedPath, n)
            endif
            if !RegistryHasName(RegistryMirrorPath, n)
                RegistryAddName(RegistryMirrorPath, n)
            endif
        endif
		i += 1
	endwhile
	; refresh snapshots after union enforcement
	WriteRegistrySnapshot(RegistrySharedPath)
	WriteRegistrySnapshot(RegistryMirrorPath)
EndFunction
; NOTE: parameter is the character GUID (not the display name)
Bool Function SyncMissingKeysForName(String n)
    ; ignore only blank identifiers; GUIDs will never be "Prisoner"
    if n == ""
        return False
    endif

	Bool wrote = False

	String deathKey   = GetDeathKeyById(n)
	String respawnKey = GetRespawnKeyById(n)
	String startupKey = GetStartupShownKeyById(n)

	bool sHas
	bool mHas

	; Death key (missing-only backfill)
	sHas = JsonUtil.HasIntValue(SharedPath, deathKey)
	mHas = JsonUtil.HasIntValue(MirrorPath, deathKey)
	if !sHas && mHas
		JsonUtil.SetIntValue(SharedPath, deathKey, JsonUtil.GetIntValue(MirrorPath, deathKey, 0))
		wrote = True
	elseif !mHas && sHas
		JsonUtil.SetIntValue(MirrorPath, deathKey, JsonUtil.GetIntValue(SharedPath, deathKey, 0))
		wrote = True
	endif

	; Respawn-used key (missing-only backfill)
	sHas = JsonUtil.HasIntValue(SharedPath, respawnKey)
	mHas = JsonUtil.HasIntValue(MirrorPath, respawnKey)
	if !sHas && mHas
		JsonUtil.SetIntValue(SharedPath, respawnKey, JsonUtil.GetIntValue(MirrorPath, respawnKey, 0))
		wrote = True
	elseif !mHas && sHas
		JsonUtil.SetIntValue(MirrorPath, respawnKey, JsonUtil.GetIntValue(SharedPath, respawnKey, 0))
		wrote = True
	endif

	; Startup-shown key (missing-only backfill)
	sHas = JsonUtil.HasIntValue(SharedPath, startupKey)
	mHas = JsonUtil.HasIntValue(MirrorPath, startupKey)
	if !sHas && mHas
		JsonUtil.SetIntValue(SharedPath, startupKey, JsonUtil.GetIntValue(MirrorPath, startupKey, 0))
		wrote = True
	elseif !mHas && sHas
		JsonUtil.SetIntValue(MirrorPath, startupKey, JsonUtil.GetIntValue(SharedPath, startupKey, 0))
		wrote = True
	endif

	return wrote
EndFunction
Bool Function ReconcileKeysForName(String n)
	; For tamper/update protection: if both sides exist but values differ, pick the MAX.
    if n == ""
        return False
    endif

	Bool wrote = False

	String deathKey   = GetDeathKeyById(n)
	String respawnKey = GetRespawnKeyById(n)
	String startupKey = GetStartupShownKeyById(n)

	; Death (max)
	if JsonUtil.HasIntValue(SharedPath, deathKey) && JsonUtil.HasIntValue(MirrorPath, deathKey)
		int sD = JsonUtil.GetIntValue(SharedPath, deathKey, 0)
		int mD = JsonUtil.GetIntValue(MirrorPath, deathKey, 0)
		if sD != mD
			int maxD = sD
			if mD > maxD
				maxD = mD
			endif
			JsonUtil.SetIntValue(SharedPath, deathKey, maxD)
			JsonUtil.SetIntValue(MirrorPath, deathKey, maxD)
			wrote = True
		endif
	endif

	; RespawnUsed (max)
	if JsonUtil.HasIntValue(SharedPath, respawnKey) && JsonUtil.HasIntValue(MirrorPath, respawnKey)
		int sR = JsonUtil.GetIntValue(SharedPath, respawnKey, 0)
		int mR = JsonUtil.GetIntValue(MirrorPath, respawnKey, 0)
		if sR != mR
			int maxR = sR
			if mR > maxR
				maxR = mR
			endif
			JsonUtil.SetIntValue(SharedPath, respawnKey, maxR)
			JsonUtil.SetIntValue(MirrorPath, respawnKey, maxR)
			wrote = True
		endif
	endif

	; StartupShown (max)
	if JsonUtil.HasIntValue(SharedPath, startupKey) && JsonUtil.HasIntValue(MirrorPath, startupKey)
		int sS = JsonUtil.GetIntValue(SharedPath, startupKey, 0)
		int mS = JsonUtil.GetIntValue(MirrorPath, startupKey, 0)
		if sS != mS
			int maxS = sS
			if mS > maxS
				maxS = mS
			endif
			JsonUtil.SetIntValue(SharedPath, startupKey, maxS)
			JsonUtil.SetIntValue(MirrorPath, startupKey, maxS)
			wrote = True
		endif
	endif

	return wrote
EndFunction

;===========================

;== VISIBLE LOG POPULATION (LOAD ONLY) ==

;===========================

Function EnsureVisibleLogIfMissing(String guid)
	if guid == ""
		return
	endif

	; Use last known name for the visible per-character file (human-readable),
	; but key all authoritative state off GUID.
	String disp = JsonUtil.GetStringValue(SharedPath, "LastKnownName:" + guid, "")
	if disp == ""
		disp = JsonUtil.GetStringValue(MirrorPath, "LastKnownName:" + guid, "")
	endif
	if disp == ""
		disp = guid
	endif

	String visFile = VisibleLogPath + "/" + disp
	if JsonUtil.HasIntValue(visFile, "Deaths")
		return
	endif

	Actor player = Game.GetPlayer()
	int d = 0
	if player
		d = _GetAuthInt(player, _DeathsStorageKey(guid), GetDeathKeyById(guid), 0)
	endif

	JsonUtil.SetIntValue(visFile, "Deaths", d)
	JsonUtil.Save(visFile)
EndFunction
Bool Function _NameInList(String[] a, int count, String n)
	int i = 0
	while i < count
		if a[i] == n
			return True
		endif
		i += 1
	endwhile
	return False
EndFunction

Function EnsureVisibleLogsOnLoad()
	; Efficient: only creates visible per-character files if missing.
	; Uses both registries (Shared + Mirror) to build a union list once.
	String[] names = new String[128]
	int count = 0

	int i = 0
	while i < RegistryMaxNames
		String n = JsonUtil.GetStringValue(RegistrySharedPath, "Name_" + i, "")
		if n != "" && !_NameInList(names, count, n)
			names[count] = n
			count += 1
			if count >= RegistryMaxNames
				i = RegistryMaxNames
			endif
		endif
		i += 1
	endwhile

	i = 0
	while i < RegistryMaxNames
		String n2 = JsonUtil.GetStringValue(RegistryMirrorPath, "Name_" + i, "")
		if n2 != "" && !_NameInList(names, count, n2)
			names[count] = n2
			count += 1
			if count >= RegistryMaxNames
				i = RegistryMaxNames
			endif
		endif
		i += 1
	endwhile

	i = 0
	while i < count
		EnsureVisibleLogIfMissing(names[i])
		i += 1
	endwhile
EndFunction

Function SyncAllKnownCharactersOnce()
	; Full scan (registry union) for tamper/update healing.
	; Intended to run RARELY (on load / new-game bootstrap).
	String[] names = new String[128]
	int count = BuildRegistryUnion(names)
	if count <= 0
		return
	endif

	; If one registry was deleted/edited, heal it from the other.
	EnsureBothRegistriesContainUnion(names, count)

	Bool any = False
	int i = 0
	while i < count
		String n = names[i]
        ; skip only blank entries; placeholder names are not special under the provisional GUID system
        if n != ""
            if SyncMissingKeysForName(n)
                any = True
            endif
            if ReconcileKeysForName(n)
                any = True
            endif
        endif
		i += 1
	endwhile

	if any
		JsonUtil.Save(SharedPath)
		JsonUtil.Save(MirrorPath)
	endif
EndFunction

Function SyncCurrentCharacterMaintenance()
	; Current-character only, very low overhead. Backfills missing keys and reconciles differences.
	float now = Utility.GetCurrentRealTime()
	if (now - _lastCurrentSyncAt) < CurrentSyncMinIntervalSeconds
		return
	endif
	_lastCurrentSyncAt = now

	Actor player = Game.GetPlayer()
	if !player
		return
	endif

	; Use GUID to avoid name/registry pollution and survive renames
	String guid = GetCharacterGUID(player)
	if guid == ""
		return
	endif

	RegisterCharacterGuid(guid)

	Bool any = False
	; Persist last-known level in registry (helps identity recovery if the co-save is deleted)
	int cur = player.GetLevel()
	if cur > 0
		JsonUtil.SetIntValue(SharedPath, "LastLevel:" + guid, cur)
		JsonUtil.SetIntValue(MirrorPath, "LastLevel:" + guid, cur)
		any = True
	endif
	if SyncMissingKeysForName(guid)
		any = True
	endif
	if ReconcileKeysForName(guid)
		any = True
	endif

	if any
		JsonUtil.Save(SharedPath)
		JsonUtil.Save(MirrorPath)
	endif
EndFunction

Function SyncCurrentCharacterImmediate(String guid)
	; Forced current-character sync (no throttle). Use before critical reads (e.g., after GUID finalize or before authoritative reads).
	if guid == ""
		return
	endif

	RegisterCharacterGuid(guid)

	Bool any = False
	if SyncMissingKeysForName(guid)
		any = True
	endif
	if ReconcileKeysForName(guid)
		any = True
	endif

	if any
		JsonUtil.Save(SharedPath)
		JsonUtil.Save(MirrorPath)
	endif
EndFunction
