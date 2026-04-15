extends SceneTree

var _test_completed = false

func _init():
    print(">>> [Test] SceneTree initialized")
    _run_test()

func _run_test():
    var board_scene = load("res://scenes/game_board.tscn")
    if board_scene == null:
        print(">>> [Test] Failed to load game_board.tscn")
        quit()
        return
    
    var board = board_scene.instantiate()
    if board == null:
        print(">>> [Test] Failed to instantiate game_board")
        quit()
        return
    
    get_root().add_child(board)
    print(">>> [Test] Board added to tree")
    
    # Wait for ready
    await get_root().process_frame
    await get_root().process_frame
    
    var gc = board.find_child("GridContainer", true, false)
    if gc == null:
        print(">>> [Test] GridContainer not found")
        board.queue_free()
        quit()
        return
    
    print(">>> [Test] GridContainer children: %d" % gc.get_child_count())
    
    if gc.get_child_count() > 0:
        var cell = gc.get_child(0)
        print(">>> [Test] Cell 0: %s" % cell.name)
        print(">>> [Test] Cell 0 type: %s" % typeof(cell))
        print(">>> [Test] Cell 0 mouse_filter: %d (2=STOP)" % cell.mouse_filter)
        print(">>> [Test] Cell 0 layout_mode: %d" % cell.layout_mode)
        
        # Check connections
        var connections = cell.gui_input.get_connections()
        print(">>> [Test] Cell 0 gui_input connections: %d" % connections.size())
        for conn in connections:
            print(">>> [Test]   Connection: %s" % conn)
        
        # Check if cell is a Control
        if cell is Control:
            print(">>> [Test] Cell is a Control")
        else:
            print(">>> [Test] Cell is NOT a Control: %s" % cell.get_class())
    
    board.queue_free()
    print(">>> [Test] Test complete")
    quit()
