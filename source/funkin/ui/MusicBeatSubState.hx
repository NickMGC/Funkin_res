package funkin.ui;

import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.text.FlxText;
import funkin.ui.mainmenu.MainMenuState;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import funkin.modding.events.ScriptEvent;
import funkin.modding.IScriptedClass.IEventHandler;
import funkin.modding.module.ModuleHandler;
import funkin.modding.PolymodHandler;
import funkin.util.SortUtil;
import flixel.util.FlxSort;
import funkin.input.Controls;

import funkin.ui.transition.CustomTransition;

/**
 * MusicBeatSubState reincorporates the functionality of MusicBeatState into an FlxSubState.
 */
class MusicBeatSubState extends FlxSubState implements IEventHandler
{
	public var leftWatermarkText:FlxText = null;
	public var rightWatermarkText:FlxText = null;

	public var conductorInUse(get, set):Conductor;

	var _conductorInUse:Null<Conductor>;

	function get_conductorInUse():Conductor
	{
		if (_conductorInUse == null) return Conductor.instance;
		return _conductorInUse;
	}

	function set_conductorInUse(value:Conductor):Conductor
	{
		return _conductorInUse = value;
	}

	public function new(bgColor:FlxColor = FlxColor.TRANSPARENT)
	{
		super();
		this.bgColor = bgColor;
		
		initCallbacks();
	}

	function initCallbacks()
	{
  		subStateOpened.add(onOpenSubStateComplete);
 		subStateClosed.add(onCloseSubStateComplete);
	}

	var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override function create():Void
	{
		super.create();
		stateTransitionIn();

		createWatermarkText();

		Conductor.beatHit.add(this.beatHit);
		Conductor.stepHit.add(this.stepHit);
		Conductor.bpmChange.add(this.bpmChange);
	}

	public function stateTransitionIn():Void
	{
		if (_parentState != null) return;

		trace('Trans in');
		if (FlxTransitionableState.skipNextTransIn)
		{
			FlxTransitionableState.skipNextTransIn = false;

			trace('Transition skipped :(');
			return;
		}

		getCurrentState().openSubState(new CustomTransition(0.6, true));
		CustomTransition.finishCallback = finishTransIn;
	}

	public static function getCurrentState():FlxState
	{
		var state = FlxG.state;
		while (state.subState != null && Type.getClass(state.subState) != CustomTransition)
			state = state.subState;

		return state;
	}

	public override function destroy():Void
	{
		super.destroy();
		Conductor.beatHit.remove(this.beatHit);
		Conductor.stepHit.remove(this.stepHit);
		Conductor.bpmChange.remove(this.bpmChange);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Emergency exit button.
		if (FlxG.keys.justPressed.F4) FlxG.switchState(() -> new MainMenuState());

		// Display Conductor info in the watch window.
		FlxG.watch.addQuick("musicTime", FlxG.sound.music?.time ?? 0.0);
		Conductor.watchQuick(conductorInUse);

		dispatchEvent(new UpdateScriptEvent(elapsed));
	}

	function reloadAssets()
	{
		PolymodHandler.forceReloadAssets();

		// Restart the current state, so old data is cleared.
		FlxG.resetState();
	}

	/**
	 * Refreshes the state, by redoing the render order of all sprites.
	 * It does this based on the `zIndex` of each prop.
	 */
	public function refresh()
	{
		sort(SortUtil.byZIndex, FlxSort.ASCENDING);
	}

	public function bpmChange():Bool
	{
		var event = new SongTimeScriptEvent(SONG_BPM_CHANGE, conductorInUse.currentBeat, conductorInUse.currentStep);

		dispatchEvent(event);

		return true;
	}

	/**
	 * Called when a step is hit in the current song.
	 * Continues outside of PlayState, for things like animations in menus.
	 * @return Whether the event should continue (not canceled).
	 */
	public function stepHit():Bool
	{
		var event:ScriptEvent = new SongTimeScriptEvent(SONG_STEP_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

		dispatchEvent(event);

		if (event.eventCanceled) return false;

		return true;
	}

	/**
	 * Called when a beat is hit in the current song.
	 * Continues outside of PlayState, for things like animations in menus.
	 * @return Whether the event should continue (not canceled).
	 */
	public function beatHit():Bool
	{
		var event:ScriptEvent = new SongTimeScriptEvent(SONG_BEAT_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

		dispatchEvent(event);

		if (event.eventCanceled) return false;

		return true;
	}

	public function dispatchEvent(event:ScriptEvent)
	{
		ModuleHandler.callEvent(event);
	}

	function createWatermarkText():Void
	{
		// Both have an xPos of 0, but a width equal to the full screen.
		// The rightWatermarkText is right aligned, which puts the text in the correct spot.
		leftWatermarkText = new FlxText(0, FlxG.height - 18, FlxG.width, '', 12);
		rightWatermarkText = new FlxText(0, FlxG.height - 18, FlxG.width, '', 12);

		// 100,000 should be good enough.
		leftWatermarkText.zIndex = 100000;
		rightWatermarkText.zIndex = 100000;
		leftWatermarkText.scrollFactor.set(0, 0);
		rightWatermarkText.scrollFactor.set(0, 0);
		leftWatermarkText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rightWatermarkText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		add(leftWatermarkText);
		add(rightWatermarkText);
	}

	/**
	 * Close this substate and replace it with a different one.
	 */
	public function switchSubState(substate:FlxSubState):Void
	{
		this.close();
		this._parentState.openSubState(substate);
	}

	override function startOutro(onComplete:() -> Void):Void
	{
		var event = new StateChangeScriptEvent(STATE_CHANGE_BEGIN, null, true);

		dispatchEvent(event);

		if (event.eventCanceled)
		{
			return;
		}
		else
		{
			FunkinSound.stopAllAudio();

			/*if (_parentState == null)
			{
				transitionOut(onComplete);
			
				if (FlxTransitionableState.skipNextTransOut)
				{
					FlxTransitionableState.skipNextTransOut = false;
					finishTransOut();
				}
			}
			else
				onComplete();*/

			_parentState == null ? stateStartOutro(onComplete) : onComplete();
		}
	}

	function stateStartOutro(onOutroComplete:() -> Void)
	{
		if (!_exiting)
		{
			// play the exit transition, and when it's done call FlxG.switchState
			_exiting = true;
			transitionOut(onOutroComplete);
			trace("KInda using transition out");
			if (FlxTransitionableState.skipNextTransOut)
			{
				FlxTransitionableState.skipNextTransOut = false;
				finishTransOut();
				trace("Okay, we skipped it :p");
			}
		}
	}


	public function transitionOut(?OnExit:Void->Void):Void
	{
		_onExit = OnExit;
		getCurrentState().openSubState(new CustomTransition(0.6, false));
		CustomTransition.finishCallback = finishTransOut;
	}

	public override function openSubState(targetSubState:FlxSubState):Void
	{
		var event = new SubStateScriptEvent(SUBSTATE_OPEN_BEGIN, targetSubState, true);

		dispatchEvent(event);

		if (event.eventCanceled) return;

		super.openSubState(targetSubState);
	}

	function onOpenSubStateComplete(targetState:FlxSubState):Void
	{
		dispatchEvent(new SubStateScriptEvent(SUBSTATE_OPEN_END, targetState, true));
	}

	public override function closeSubState():Void
	{
		var event = new SubStateScriptEvent(SUBSTATE_CLOSE_BEGIN, this.subState, true);

		dispatchEvent(event);

		if (event.eventCanceled) return;

		super.closeSubState();
	}

	function onCloseSubStateComplete(targetState:FlxSubState):Void
	{
		dispatchEvent(new SubStateScriptEvent(SUBSTATE_CLOSE_END, targetState, true));
	}

	function finishTransIn()
	{
		if (CustomTransition.currentTransition != null) CustomTransition.currentTransition.close();
	}

	var transOutFinished:Bool = false;

	var _exiting:Bool = false;
	var _onExit:Void->Void;
	function finishTransOut()
	{
		transOutFinished = true;

		if (!_exiting)
		{
			closeSubState();
		}

		if (_onExit != null)
		{
			_onExit();
		}
	}
}
