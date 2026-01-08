IronSoulControllerQuestScript Property Controller Auto

Event OnInit()
	if Controller
		Actor p = Game.GetPlayer()
		if p
			; If the player already has a stable, non-placeholder name,
			; allow the controller to establish or recover identity.
			; During new game chargen the name is often "Prisoner"/"Player",
			; so we intentionally avoid GUID work here and defer it to load.
			String n = p.GetDisplayName()
			if n != "" && n != "Prisoner" && n != "Player"
				Controller.GetCharacterGUID(p)
			endif
		endif
	endif
EndEvent

Event OnPlayerLoadGame()
	if Controller
		; Load-game is the authoritative point for identity finalization:
		; - player name is stable
		; - JSON state is available
		; - GUID recovery and synchronization are safe
		Controller.GameReloaded(True)
	endif
EndEvent

Event OnDying(Actor akKiller)
	if Controller
		Controller.HandlePlayerDying(akKiller)
	endif
EndEvent