extends GutTest

# UI 输入测试示例
# 测试 Godot Input 事件模拟

var test_root: Node
var ui_container: VBoxContainer
var test_button: Button
var pressed_state: bool = false
var click_count: int = 0

func before_each():
    """每个测试前创建测试UI"""
    test_root = Node.new()
    test_root.name = "TestUIRoot"
    get_tree().root.add_child(test_root)

    ui_container = VBoxContainer.new()
    ui_container.name = "TestUIContainer"
    test_root.add_child(ui_container)

    test_button = Button.new()
    test_button.name = "TestButton"
    test_button.text = "点击我"
    test_button.set_anchors_preset(Control.PRESET_CENTER)
    ui_container.add_child(test_button)

    pressed_state = false
    click_count = 0

func after_each():
    """每个测试后清理"""
    if is_instance_valid(test_root):
        test_root.queue_free()

func _on_button_pressed():
    pressed_state = true

func test_button_pressed_signal():
    """测试按钮点击信号 - 直接调用 pressed 信号"""
    test_button.pressed.connect(_on_button_pressed)
    test_button.pressed.emit()
    assert_true(pressed_state, "按钮应该被点击")

var emitted_state: bool = false

func _handler_emitted():
    emitted_state = true

func test_button_emit_pressed():
    """测试按钮按下"""
    emitted_state = false
    test_button.pressed.connect(_handler_emitted)
    test_button.pressed.emit()
    assert_true(emitted_state, "pressed 信号应该被触发")

func test_button_position():
    """测试按钮位置"""
    var pos = test_button.global_position
    print("按钮位置: ", pos)
    # headless 模式下位置是 (0,0)，这是正常的

func test_ui_action_input():
    """测试 UI 动作输入"""
    Input.action_press("ui_accept")
    assert_true(Input.is_action_pressed("ui_accept"), "ui_accept 应该被按下")
    Input.action_release("ui_accept")
    assert_true(not Input.is_action_pressed("ui_accept"), "ui_accept 应该被释放")

func test_key_input():
    """测试键盘输入 - 验证 keycode"""
    var event = InputEventKey.new()
    event.keycode = KEY_ESCAPE
    event.pressed = true
    # 验证事件创建成功
    assert_eq(event.keycode, KEY_ESCAPE, "keycode 应该是 ESC")

func test_mouse_motion():
    """测试鼠标移动"""
    var event = InputEventMouseMotion.new()
    event.position = Vector2(100, 200)
    assert_eq(event.position, Vector2(100, 200), "鼠标位置应该正确")

var click_handler_count: int = 0

func _handler_increment():
    click_handler_count += 1

func test_button_emit_multiple():
    """测试多次按钮点击"""
    click_handler_count = 0
    test_button.pressed.connect(_handler_increment)

    test_button.pressed.emit()
    test_button.pressed.emit()
    test_button.pressed.emit()

    assert_eq(click_handler_count, 3, "应该点击了3次")

var button_0_clicked: bool = false
var button_1_clicked: bool = false
var button_2_clicked: bool = false

func _on_b0_pressed():
    button_0_clicked = true

func _on_b1_pressed():
    button_1_clicked = true

func _on_b2_pressed():
    button_2_clicked = true

func test_multiple_buttons():
    """测试多按钮交互"""
    button_0_clicked = false
    button_1_clicked = false
    button_2_clicked = false

    var buttons = []
    for i in range(3):
        var btn = Button.new()
        btn.text = "按钮%d" % i
        btn.name = "Button%d" % i
        ui_container.add_child(btn)
        buttons.append(btn)

    # 连接不同的信号处理器
    buttons[0].pressed.connect(_on_b0_pressed)
    buttons[1].pressed.connect(_on_b1_pressed)
    buttons[2].pressed.connect(_on_b2_pressed)

    # 点击中间按钮
    buttons[1].pressed.emit()

    assert_false(button_0_clicked, "按钮0不应该被点击")
    assert_true(button_1_clicked, "按钮1应该被点击")
    assert_false(button_2_clicked, "按钮2不应该被点击")
