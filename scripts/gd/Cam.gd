extends Camera2D

var zoom_factor = 0

func _process(delta):
    if zoom_factor != 0:
        if (zoom.length() <= 9 and zoom_factor == 1) != (zoom.length() >= 1 and zoom_factor == -1):
            zoom += Vector2(zoom_factor, zoom_factor) * 3 * delta
        zoom_factor = 0

func _unhandled_input(event):
    if event is InputEventMouseButton:
        if event.is_pressed():
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                zoom_factor = 1
            if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                zoom_factor = -1
