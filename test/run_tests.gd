#!/usr/bin/env godot
# 运行所有测试的脚本
# 用法: godot --headless --path . --script test/run_tests.gd

extends SceneTree

func _init():
    print("========================================")
    print("  GUT 测试框架 - Godot 自动化测试")
    print("========================================")
    print("")

    # 加载 GUT 插件
    var gut = load("res://addons/gut/gut.gd").new()
    add_child(gut)

    # 配置 GUT
    gut.set_directory("res://test", true, true)  # 测试目录
    gut.set_include_patterns(["*.gd"])           # 包含的测试文件
    gut.set_exclude_patterns([])                # 排除的文件
    gut.set_log_level(gut.LOG_LEVEL_INFO)        # 日志级别

    # 打印测试配置
    print("测试目录: res://test")
    print("包含模式: *.gd")
    print("")

    # 收集测试脚本
    gut.collect_tests()

    # 运行测试
    print("开始运行测试...")
    print("")

    # 等待一帧让测试完成
    await Engine.main_loop_frame
    await get_tree().create_timer(0.1).timeout

    # 获取测试结果
    var summary = gut.get_summary()
    print("")
    print("========================================")
    print("  测试结果")
    print("========================================")
    print("总测试数: ", summary.tests)
    print("通过: ", summary.passed)
    print("失败: ", summary.failed)
    print("跳过: ", summary.skipped)

    if summary.failed > 0:
        print("")
        print("失败的测试:")
        for test in summary.failed_tests:
            print("  - ", test)

    print("")

    # 退出
    quit(0 if summary.failed == 0 else 1)
