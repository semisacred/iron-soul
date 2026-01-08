Scriptname IronSoulPlayerAliasScript extends ReferenceAlias

IronSoulControllerQuestScript Property Controller Auto

Event OnInit()
	if Controller
		Actor p = Game.GetPlayer()
		if p
			; Ensure GUID exists as early as possible (new game safe)
			Controller.GetCharacterGUID(p)
		endif
	endif
EndEvent

Event OnPlayerLoadGame()
	if Controller
		; Re-run load initialization (rare sync + startup gating handled by controller)
		Controller.GameReloaded(True)
	endif
EndEvent

Event OnSleepStart(float afSleepStartTime, float afDesiredSleepEndTime)
	if Controller
		Controller.HandleSleepStart(afSleepStartTime, afDesiredSleepEndTime)
	endif
EndEvent

Event OnDying(Actor akKiller)
	if Controller
		Controller.HandlePlayerDying(akKiller)
	endif
EndEvent
