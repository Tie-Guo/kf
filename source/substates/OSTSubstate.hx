package substates;

import flash.geom.Rectangle;
import tjson.TJSON as Json;
import haxe.format.JsonParser;
import haxe.io.Bytes;

import flixel.FlxObject;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;

import flixel.addons.transition.FlxTransitionableState;

import backend.Song;
import backend.Section;
import backend.StageData;


import objects.AttachedSprite;
import substates.Prompt;

#if sys
import flash.media.Sound;
import sys.io.File;
import sys.FileSystem;
#end

#if android
import android.flixel.FlxButton;
#else
import flixel.ui.FlxButton;
#end

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)



class OSTSubstate extends MusicBeatSubstate
{
    var waveformSprite:FlxSprite;
    public static var vocals:FlxSound;
	public function new(needVoices:Bool,bpm:Float)
	{
		super();				
		
		if (needVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();
		
		FlxG.sound.list.add(vocals);
		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
		vocals.play();
		vocals.persist = true;
		vocals.looped = true;
		vocals.volume = 0.7;		
		
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.scrollFactor.set(0,0);
		bg.setGraphicSize(Std.int(bg.width));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		
		waveformSprite = new FlxSprite().makeGraphic(1280, 720, 0xFF000000);
		waveformSprite.alpha = 0.5;.
		add(waveformSprite);
		
		
	}

	
	override function update(elapsed:Float)
	{
		if(FlxG.keys.justPressed.ESCAPE #if android || FlxG.android.justReleased.BACK #end)
		{
		    FlxG.sound.music.volume = 0;
		    destroyVocals();
		
		    FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.7);		
		    
			#if android
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
			#else
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			#end
		}
		
		waveformData();
		
		
		
		super.update(elapsed);
	}
	
	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

	var lastWaveformHeight:Int = 0;
	function updateWaveform() {
		if(waveformPrinted) {
			var width:Int = 1280;
			var height:Int = 720;
			if(lastWaveformHeight != height && waveformSprite.pixels != null)
			{
				waveformSprite.pixels.dispose();
				waveformSprite.pixels.disposeImage();
				waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
				lastWaveformHeight = height;
			}
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices) {
			//trace('Epic fail on the waveform lol');
			return;
		}
		
		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];
		
		var steps:Int = 0;
		var st:Float = FlxG.sound.music.time;
		var et:Float = st + (Conductor.stepCrochet * steps);
		
		if (FlxG.save.data.chart_waveformInst) {
			var sound:FlxSound = FlxG.sound.music;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();
				
				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					1280
				);
			}
		}
		
		if (FlxG.save.data.chart_waveformVoices) {
			var sound:FlxSound = vocals;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();
				
				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					720
				);
			}
		}
		
		// Draws
		var gSize:Int = 1280;
		var hSize:Int = 720;
		
		var lmin:Float = 0;
		var lmax:Float = 0;
		
		var rmin:Float = 0;
		var rmax:Float = 0;
		
		var size:Float = 1;
		
		var leftLength:Int = (
			wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length
		);
		
		var rightLength:Int = (
			wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length
		);
		
		var length:Int = leftLength > rightLength ? leftLength : rightLength;
		
		var index:Int;
		for (i in 0...length) {
			index = i;
			
			lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			
			rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			
			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}
		
		waveformPrinted = true;
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];
		
		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;
		
		var index:Int = Std.int(time * khz);
		
		var samples:Float = ((endTime - time) * khz);
		
		if (steps == null) steps = 0;
		
		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);
		
		var gotIndex:Int = 0;
		
		var lmin:Float = 0;
		var lmax:Float = 0;
		
		var rmin:Float = 0;
		var rmax:Float = 0;
		
		var rows:Float = 0;
		
		var midx = 720 / 2;
		
		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;
		
		while (index < length) {
			if (index >= 0) {
				var byte = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (stereo) {
					var byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					var sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}
			
			if (rows - prevRows >= samplesPerRow) {
				prevRows = rows + ((rows - prevRows) - 1);
				
				waveformSprite.drawRect(render, midx + (rmin * midx * 2), 1, (rmax - rmin) * midx * 2);
				//flashGFX2.drawRect(midx + (rmin * midx * 2), render, (rmax - rmin) * midx * 2, 1);
				
				
				
				lmin = lmax = rmin = rmax = 0;
				render++;
			}
			
			index++;
			rows++;
			if (render > 1280) break;
		}
		
		waveformSprite.endFill();
		//waveformSprite.pixels.draw(flashSpr2);
		waveformSprite.pixels.unlock();
		//left.dirty = true;
		
		return;
		
		
	}

	public static function destroyVocals() {
		if(vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}
}