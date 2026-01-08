Scriptname DragonsoulOnDying extends ActiveMagicEffect 

Spell Property RestoreSpell Auto 
Spell Property DisSpell Auto 
Bool Property bDispel = True Auto ;Whether Dispel heal magic and potion on you when you die

Float Property time1 = 6.0 Auto ;time delay of resurrect
Float Property time2 = 3.0 Auto ;time delay of restore full health, magicka and stamina
Float Property time3 = 1.0 Auto ;time delay of getup after resurrect spell cast
Float Property time4 = 3.0 Auto ;time of Ghost status remains after get up
Float Property time5 = 3.0 Auto ;time of resurrect spell remains after Ghost status is end
FormList Property BeastList Auto
Globalvariable Property DRIsDead Auto

Bool Property bPlaysound = True Auto ;Play Sound or not
sound property NPCDragonDeathSequenceWind Auto
sound property NPCDragonDeathSequenceExplosion Auto

Bool Property bPlayVisualEffect = True Auto ;Play VisualEffect or not
VisualEffect Property AbsorbEffect Auto
VisualEffect Property AbsorbEffectTarget Auto
Float Property Playtime = 8.0 Auto ; How long AbsorbEffect plays

Activator Property Marker Auto

WorldSpace Property DLC2ApocryphaWorld Auto
Quest Property DLC2MQ06 Auto

Objectreference MarkerRef

Event OnEffectStart(Actor Target, Actor Caster)

	;Debug.Notification("Start OnDying")
	if bDispel
		DisSpell.Cast(Target, Target)
	endif
;if Target.IsEssential() || (Target.GetWorldSpace() == DLC2ApocryphaWorld && !(DLC2MQ06.GetStage()>=400 && DLC2MQ06.GetStage()<500))
if Target.IsEssential()

	;Debug.Notification("IsEssential")
	;Target.DamageAV("Health", 1000)
	Target.EndDeferredKill()
	;game.EnablePlayerControls()
	Utility.Wait(time1)
	;Target.RestoreAV("Health", Target.GetAVMax("Health")-Target.GetAV("Health"))
	Target.StartDeferredKill()
	
else

	
	DRIsDead.SetValue(1)
	Target.SetGhost(true)
	Target.PushActorAway(Target, 0.1)
	Target.SetAV("Paralysis", 1.0)
	Target.RestoreAV("Health", -(Target.GetAV("Health")+100))

	Utility.Wait(time1)

	if  !(BeastList.hasform(Target.GetRace())) && (Target.GetAV("DragonSouls") >= 1)
		;Debug.Notification("Cast Spell")

		Target.DamageAV("DragonSouls", 1.0)
		Int soulsRemaining = Target.GetAV("DragonSouls") as Int
		Debug.MessageBox("A dragon soul burns within you.\nDragon Souls Remaining: " + soulsRemaining)
		Target.AddSpell(RestoreSpell,false)
		DRIsDead.SetValue(0)


		if bPlayVisualEffect
			MarkerRef = Target.PlaceAtMe(Marker)
			MarkerRef.MoveTo(Target)
			AbsorbEffect.Play(MarkerRef, Playtime, Target)
			AbsorbEffectTarget.Play(Target, Playtime, MarkerRef)
		endif

		if bPlaysound
			NPCDragonDeathSequenceWind.play(Target) 
			NPCDragonDeathSequenceExplosion.play(Target)
		endif

		Utility.Wait(time2)

		Target.RestoreAV("Stamina", Target.GetAVMax("Stamina"))
		Target.RestoreAV("Magicka", Target.GetAVMax("Magicka"))
		Target.RestoreAV("Health", Target.GetAVMax("Health")-Target.GetAV("Health"))


	else
		;Debug.Notification("DO not Cast")
		Target.EndDeferredKill()

	endif
endif

Endevent

Event OnEffectFinish(Actor Target, Actor Caster)

	;Debug.Notification("Finish OnDying")

	Utility.Wait(time3)
	Target.SetAV("Paralysis", 0.0)
	Utility.Wait(time4)
	Target.SetGhost(false)
	Utility.Wait(time5)
	Target.RemoveSpell(RestoreSpell)

	if (MarkerRef != none)
		MarkerRef.disable()
		MarkerRef.delete()
	endif

Endevent