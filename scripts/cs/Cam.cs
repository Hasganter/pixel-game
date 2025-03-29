using Godot;
using System;

public partial class Cam : Camera2D
{
    private int zoomFactor = 0;
    public void _process(float delta)
    {
        if (zoomFactor != 0)
        {
            if ((Zoom.Length() <= 9 && zoomFactor == 1) ^ (Zoom.Length() >= 1 && zoomFactor == -1))
            {
                Zoom += new Vector2(zoomFactor * 0.25f, zoomFactor * 0.25f);
            }
            zoomFactor = 0; 
        }
    }
    public override void _UnhandledInput(InputEvent @event){
        if (@event is InputEventMouseButton){
            InputEventMouseButton emb = (InputEventMouseButton)@event;
            if (emb.IsPressed()){
                if (emb.ButtonIndex == MouseButton.WheelUp){
                    zoomFactor = 1;
                }
                if (emb.ButtonIndex == MouseButton.WheelDown){
                    zoomFactor = -1;
                }
            }
        }
    }
}
