package com.shadow.entities 
{
	import Playtomic.*;
	
	import com.shadow.Assets;
	import com.shadow.Global;
	
	import flash.geom.Point;
	
	import net.flashpunk.Entity;
	import net.flashpunk.FP;
	import net.flashpunk.Sfx;
	import net.flashpunk.graphics.Image;
	import net.flashpunk.graphics.Spritemap;
	import net.flashpunk.tweens.sound.SfxFader;
	import net.flashpunk.utils.Input;
	import net.flashpunk.utils.Key;
	
	
	/**
	 * 
	 * @author Eric Bernier
	 */
	public class Player extends Physics
	{	
		private const WIDTH:int = 30;
		private const HEIGHT:int = 30;
		private const APPLE_JUMP:int = 25;
		private const JUMP:int = 8;
		private const ENDING_X:int = 498;
		
		private var sprite:Spritemap = new Spritemap(Assets.GROUNDHOG, WIDTH, HEIGHT, null);
		private var movement:Number = 1;
		
		// Current player direction (true = right, false = left)
		private var direction_:Boolean = true;
	
		public var onGround_:Boolean = false;
		public var ending_:Boolean = false;
		private var dead:Boolean = false;
		private var start:Point;
		private var jumpSnd_:Sfx = new Sfx(Assets.SND_JUMP);
		private var deathSnd_:Sfx = new Sfx(Assets.SND_DEATH);
		private var shadowSnd_:Sfx = new Sfx(Assets.SND_SHADOW);
		
		
		public function Player(xCoord:int, yCoord:int, shadow:Boolean = false) 
		{
			yCoord += 4;
			super(xCoord, yCoord);
			start = new Point(xCoord, yCoord);
			type = Global.PLAYER_TYPE;
			
			gravity_ = 0.4;
			maxSpeed_ = new Point(4, 8);
			friction_ = new Point(0.5, 0.5);

			sprite.add("stand", [0, 1], 6, true);
			sprite.add("idle", [0, 1], 6, true);
			sprite.add("walk", [4, 5, 6, 7], 10, true);
			sprite.add("jump", [1], 0, false);
			sprite.play("stand");
			
			this.setHitbox(25, 25, 0, -4);
			graphic = sprite;
		}
		
		
		override public function update():void 
		{
			while (this.collide(Global.SOLID_TYPE, this.x, this.y))
			{
				this.y--;
			}
			
			// Check if the player either wants to spawn or destroy a shadow
			if (Input.pressed(Global.keySpace) && Global.level < Global.NUM_LEVELS)
			{
				this.addShadow();	
			}
			
			if (ending_)
			{
				sprite.play("idle");
				return;
			}
			else if (sprite.alpha < 1) 
			{ 
				sprite.alpha += 0.1 
			}
			
            onGround_ = false;
            if (collide(Global.SOLID_TYPE, x, y + 1) || Global.onMovingPlatform) 
            { 
                onGround_ = true;
            }
            
            acceleration_.x = 0;
            if (Input.check(Global.keyLeft)  && speed_.x > -maxSpeed_.x) 
            { 
                acceleration_.x = -movement; 
                direction_ = false; 
            }
            
            if (Input.check(Global.keyRight) && speed_.x < maxSpeed_.x) 
            { 
                acceleration_.x = movement; 
                direction_ = true; 
            }
            
            // Friction (apply if we're not moving, or if our speed_.x is larger than maxspeed)
            if ((!Input.check(Global.keyLeft) && !Input.check(Global.keyRight)) || Math.abs(speed_.x) > maxSpeed_.x) 
            { 
                friction(true, false); 
            }
            
            if (Input.pressed(Global.keyUp)) 
            {
                var jumped:Boolean = false;
                if (onGround_ && Global.level < Global.NUM_LEVELS) 
                { 
                    speed_.y = -JUMP; 
                    jumped = true;
                    
                    world.add(new Particle(x, y + 30, .5, .5, .1, 0xFFFFFF));
                    world.add(new Particle(x + 5, y + 28 + 5, .5, .5, .1, 0xFFFFFF));
                    world.add(new Particle(x - 5, y + 25 - 5, .5, .5, .1, 0xFFFFFF));
                    
                    jumpSnd_.play(Global.soundVolume, 0);
                }
            }
                            
            gravity();
            
            //----------------------------------------------------------------------------------
            // Make sure we're not going too fast vertically. The reason we don't stop the 
            // player from moving too fast left/right is because that would (partially) destroy 
            // the walljumping. Instead, we just make sure the player, using the arrow keys, 
            // can't go faster than the max speed, and if we are going faster
            //than the max speed, descrease it with friction slowly.
            //----------------------------------------------------------------------------------
            maxspeed(false, true);
            
            // Variable jumping (triple gravity)
            if (speed_.y < 0 && !Input.check(Global.keyUp))
            { 
                gravity(); 
                gravity(); 
            }        

			if (onGround_)
			{
				if (speed_.x < 0 || speed_.x > 0) 
				{ 
					sprite.play("walk"); 
				}
				
				if (speed_.x == 0) 
				{
					sprite.play("stand"); 
				}
			}
			else 
			{ 
				sprite.play("jump"); 
			}

			motion();
			
			// Check if we just died, either via enemy contact or falling to our death
			if ((collide(Global.ENEMY_TYPE, x, y) && speed_.y > 0) || this.y >= Global.levelHeight)
			{
				this.killMe();
			}
			
			if (!direction_)
			{
				sprite.flipped = true;
			}
			else
			{
				sprite.flipped = false;
			}
			
			this.collectFlowers();
			
			// Check if the game is ending. This is quite the hack, and if I wanted to
			// take the time I would have created an EndingWorld that handled all of this better
			if (Global.level == Global.NUM_LEVELS)
			{
				if (this.x >= ENDING_X)
				{
					ending_ = true;
					
					FP.world.add(new Shadow(x + width + 5, y));
				}
			}
		}	
        
		
		public function killMe():void
		{
			dead = true;
			
			world.add(new Particle(x, y + 30, .5, .5, .1, 0x8D2828));
			world.add(new Particle(x + 5, y + 28 + 5, .5, .5, .1, 0x8D2828));
			world.add(new Particle(x + 10, y + 25 - 5, .5, .5, .1, 0x8D2828));
			world.add(new Particle(x, y + 20, .5, .5, .1, 0x8D2828));
			world.add(new Particle(x + 33, y + 21 + 5, .5, .5, .1, 0x8D2828));
			world.add(new Particle(x + 20, y + 22 - 5, .5, .5, .1, 0x8D2828));
			
			this.setHitbox(0, 0);
			FP.world.remove(this);
			
			deathSnd_.play(Global.soundVolume);
			Global.flowerVal = 0;
			Global.restart = true;
		}
		
		
		public function isDead():Boolean
		{
			return dead;
		}

        
		private function collectFlowers():void
		{
			var flower:Flower = collide(Global.FLOWER_TYPE, x, y) as Flower;
			
			if (flower)
			{
				flower.collect();
			}
		}
		
		
		public function bounce():void
		{
			speed_.y = -JUMP * 1.5;
		}
		
	
		public function addShadow():void
		{	
			shadowSnd_.play(Global.soundVolume);
			Global.haveShadow = true;
			FP.world.add(new Shadow(x, y));
		}
	}
}
