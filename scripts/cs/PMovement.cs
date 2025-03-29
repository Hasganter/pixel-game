using Godot;
using System;

public partial class PMovement : RigidBody2D
{
	public float speed = 200;
	public float dashStrength = 0.5f;
	public float dashCooldown = 1; // In seconds
	public float dashCooldownProgress = 0; // Tracks cooldown progress
	private Vector2 lastDirection = new Vector2(1, 0);
	private Tween dashTween; // Tween for dashing

	public override void _Ready()
	{	
		dashTween = GetNodeOrNull<Tween>("DashTween");
		if (dashTween == null)
		{
			dashTween = CreateTween();
			dashTween.BindNode(this);
		}
		dashTween.Stop();
	}
	public void _process(float delta)
	{
		Vector2 movement = new Vector2();

		// Handle movement input
		if (Input.IsActionPressed("player-up"))
		{
			movement.Y -= 1;
		}
		if (Input.IsActionPressed("player-down"))
		{
			movement.Y += 1;
		}
		if (Input.IsActionPressed("player-left"))
		{
			movement.X -= 1;
		}
		if (Input.IsActionPressed("player-right"))
		{
			movement.X += 1;
		}

		// Normalize movement and apply speed
		if (movement.Length() > 0)
		{
			movement = movement.Normalized() * speed;
			// Apply the calculated linear velocity to the RigidBody2D
			LinearVelocity = movement;

			// Update last direction for movement
			if (movement.X != 0)
			{
				lastDirection.X = Mathf.Sign(movement.X);
			}
			else
			{
				lastDirection.X = 0.5f * Mathf.Sign(lastDirection.X); // Retain horizontal bias
			}
			lastDirection.Y = Mathf.Sign(movement.Y);

			// Play movement animations
			if (movement.X != 0)
			{
				this.GetChild<AnimatedSprite2D>(0).Play(movement.X > 0 ? "move-right" : "move-left");
			}
			else if (movement.Y != 0)
			{
				this.GetChild<AnimatedSprite2D>(0).Play(lastDirection.X > 0 ? "move-right" : "move-left");
			}
		}
		else
		{
			// Set linear velocity to zero when no movement input is given
			LinearVelocity = Vector2.Zero;
			// Play idle animation based on last horizontal direction
			this.GetChild<AnimatedSprite2D>(0).Play(lastDirection.X > 0 ? "idle-right" : "idle-left");
		}

		// Handle dashing
		if (Input.IsActionJustPressed("player-dash") && dashCooldownProgress <= 0 && !dashTween.IsRunning())
		{
			Vector2 dashTarget;
			if (Mathf.Floor(lastDirection.X) != 0)
			{
				dashTarget = this.Position + lastDirection.Normalized() * speed * dashStrength;
			}
			else
			{
				dashTarget = this.Position + new Vector2(0, lastDirection.Y).Normalized() * speed * dashStrength;
			}

			dashTween = GetNodeOrNull<Tween>("DashTween");
			if (dashTween == null)
			{
				dashTween = CreateTween();
				dashTween.BindNode(this);
			}
			dashTween.TweenProperty(this, "position", dashTarget, 0.2f)
					 .SetTrans(Tween.TransitionType.Sine)
					 .SetEase(Tween.EaseType.Out);
			dashTween.Play();

			this.GetChild<AnimatedSprite2D>(0).Play(lastDirection.X > 0 ? "dash-right" : "dash-left");
			dashCooldownProgress = dashCooldown;
		}

		// Update dash cooldown
		if (dashCooldownProgress > 0)
		{
			dashCooldownProgress -= delta;
		}
	}
}
