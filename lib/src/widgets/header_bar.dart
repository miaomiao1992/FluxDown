import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';
import '../../main.dart';
import '../models/download_controller.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import 'title_drag_area.dart';

class HeaderBar extends StatelessWidget {
  final VoidCallback onNewDownload;

  const HeaderBar({super.key, required this.onNewDownload});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TitleDragArea(
      child: Container(
        height: 48,
        // right 预留 WindowControls 区域宽度：
        // 4 工具按钮(40*4) + 分隔线(9) + 3 窗口按钮(40*3) = 289
        padding: const EdgeInsets.only(left: 16, right: 289),
        decoration: BoxDecoration(
          color: c.surface1,
          border: Border(bottom: BorderSide(color: c.border, width: 1)),
        ),
        child: Row(
          children: [
            // New download button
            ShadButton(
              onPressed: onNewDownload,
              backgroundColor: c.accent,
              hoverBackgroundColor: c.accentHover,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '新建下载',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Search
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: ShadInput(
                  placeholder: const Text('搜索下载任务...'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  constraints: const BoxConstraints(
                    minHeight: 30,
                    maxHeight: 30,
                  ),
                  gap: 6,
                  leading: Icon(
                    LucideIcons.search,
                    size: 14,
                    color: c.textMuted,
                  ),
                  style: const TextStyle(fontSize: 13),
                  decoration: const ShadDecoration(
                    secondaryFocusedBorder: ShadBorder.none,
                    secondaryBorder: ShadBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 窗口右上角控制区：全部暂停 | 全部恢复 | 设置 | 主题切换 || 最小化 | 最大化 | 关闭
/// 通过 Positioned 悬浮在窗口右上角，确保这些按钮始终紧挨在一起
class WindowControls extends StatelessWidget {
  final DownloadController controller;
  final VoidCallback? onSettings;
  final bool isSettingsActive;

  const WindowControls({
    super.key,
    required this.controller,
    this.onSettings,
    this.isSettingsActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final themeProvider = FluxDownApp.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 全部暂停
          _ToolButton(
            icon: LucideIcons.circlePause,
            tooltip: '全部暂停',
            onPressed: () => controller.pauseAll(),
            iconSize: 16,
          ),
          // 全部恢复
          _ToolButton(
            icon: LucideIcons.circlePlay,
            tooltip: '全部恢复',
            onPressed: () => controller.resumeAll(),
            iconSize: 16,
          ),
          // 设置按钮
          _ToolButton(
            icon: LucideIcons.settings,
            tooltip: '设置',
            onPressed: () => onSettings?.call(),
            iconSize: 16,
            isActive: isSettingsActive,
          ),
          // 主题切换按钮
          _ToolButton(
            icon: themeProvider.isDark(context)
                ? LucideIcons.sun
                : LucideIcons.moon,
            tooltip: themeProvider.isDark(context) ? '切换到亮色模式' : '切换到暗色模式',
            onPressed: () => themeProvider.toggleTheme(context),
            iconSize: 15,
          ),
          // 分隔线
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(width: 1, height: 16, color: c.border),
          ),
          // 窗口控制按钮
          _WindowButton(
            icon: LucideIcons.minus,
            onPressed: () {
              logInfo('WindowCtrl', 'minimize clicked');
              windowManager.minimize();
            },
            colors: c,
          ),
          _WindowButton(
            icon: LucideIcons.square,
            iconSize: 12,
            onPressed: () async {
              logInfo('WindowCtrl', 'maximize/restore clicked');
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            colors: c,
          ),
          _WindowButton(
            icon: LucideIcons.x,
            onPressed: () {
              logInfo('WindowCtrl', 'close clicked');
              windowManager.close();
            },
            colors: c,
            isClose: true,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final AppColors colors;
  final bool isClose;
  final double iconSize;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.colors,
    this.isClose = false,
    this.iconSize = 14,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 48,
          color: _isHovered
              ? (widget.isClose
                    ? AppColors.red.withValues(alpha: 0.9)
                    : c.surface3)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered && widget.isClose
                ? Colors.white
                : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 工具栏按钮（暂停、恢复、设置、主题切换等），与窗口控制按钮同组，hover 效果一致
class _ToolButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;
  final String? tooltip;
  final bool isActive;

  const _ToolButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 16,
    this.tooltip,
    this.isActive = false,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isActive = widget.isActive;
    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? c.accentBg
                : _isHovered
                ? c.surface3
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: isActive ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = ShadTooltip(
        builder: (_) => Text(widget.tooltip!),
        child: button,
      );
    }
    return button;
  }
}
