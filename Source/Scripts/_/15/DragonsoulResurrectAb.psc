Scriptname DragonsoulResurrectAb extends ActiveMagicEffect  


Event OnEffectStart(Actor Target, Actor Caster)

	;Debug.Notification("Start DeferredKill")

	Target.StartDeferredKill()
	;Game.GetPlayer().StartDeferredKill()
Endevent