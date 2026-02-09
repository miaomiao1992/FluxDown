import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../main.dart';
import '../models/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/title_drag_area.dart';

// ─────────────────────────────────────────────
// 设置分类枚举
// ─────────────────────────────────────────────

enum _SettingsCategory {
  general(icon: LucideIcons.settings2, label: '通用', desc: '基本行为设置'),
  appearance(icon: LucideIcons.palette, label: '外观', desc: '主题与配色'),
  download(icon: LucideIcons.download, label: '下载', desc: '下载引擎配置');

  final IconData icon;
  final String label;
  final String desc;

  const _SettingsCategory({
    required this.icon,
    required this.label,
    required this.desc,
  });
}

// ─────────────────────────────────────────────
// 设置页面（带侧边栏导航）
// ─────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  final SettingsProvider settingsProvider;

  const SettingsPage({
    super.key,
    required this.onBack,
    required this.settingsProvider,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsCategory _selected = _SettingsCategory.general;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        // 顶部标题栏
        TitleDragArea(
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 12, right: 289),
            decoration: BoxDecoration(
              color: c.surface1,
              border: Border(bottom: BorderSide(color: c.border, width: 1)),
            ),
            child: Row(
              children: [
                ShadButton.ghost(
                  onPressed: widget.onBack,
                  size: ShadButtonSize.sm,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.arrowLeft,
                        size: 14,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '返回',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 主体：侧边栏 + 内容区
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧导航栏
              _SettingsSidebar(
                selected: _selected,
                onSelect: (cat) => setState(() => _selected = cat),
              ),
              // 分隔线
              Container(width: 1, color: c.border),
              // 右侧内容区
              Expanded(
                child: _SettingsContent(
                  category: _selected,
                  settingsProvider: widget.settingsProvider,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 设置侧边栏导航
// ─────────────────────────────────────────────

class _SettingsSidebar extends StatelessWidget {
  final _SettingsCategory selected;
  final ValueChanged<_SettingsCategory> onSelect;

  const _SettingsSidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 200,
      color: c.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final cat in _SettingsCategory.values)
            _SettingsNavItem(
              icon: cat.icon,
              label: cat.label,
              description: cat.desc,
              isSelected: selected == cat,
              onTap: () => onSelect(cat),
            ),
        ],
      ),
    );
  }
}

class _SettingsNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsNavItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<_SettingsNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final selected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? c.accentBg
                : _isHovered
                ? c.hoverBg
                : c.hoverBg.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? c.accent.withValues(alpha: 0.12)
                      : c.surface2,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  widget.icon,
                  size: 15,
                  color: selected ? c.accent : c.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: selected ? c.accent : c.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 10.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 设置内容区
// ─────────────────────────────────────────────

class _SettingsContent extends StatelessWidget {
  final _SettingsCategory category;
  final SettingsProvider settingsProvider;

  const _SettingsContent({
    required this.category,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(category: category),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: switch (category) {
                  _SettingsCategory.general => _GeneralContent(
                    key: const ValueKey('general'),
                    settingsProvider: settingsProvider,
                  ),
                  _SettingsCategory.appearance => const _AppearanceContent(
                    key: ValueKey('appearance'),
                  ),
                  _SettingsCategory.download => _DownloadContent(
                    key: ValueKey('download'),
                    settingsProvider: settingsProvider,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 分类标题头
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final _SettingsCategory category;

  const _SectionHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(category.desc, style: TextStyle(fontSize: 13, color: c.textMuted)),
        const SizedBox(height: 16),
        Divider(height: 1, color: c.border),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 设置卡片：每个设置项的统一容器
// ─────────────────────────────────────────────

class _SettingCard extends StatelessWidget {
  final String label;
  final String description;
  final Widget child;
  final bool vertical;

  const _SettingCard({
    required this.label,
    required this.description,
    required this.child,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border, width: 1),
      ),
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 14),
                child,
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                child,
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// 通用设置
// ─────────────────────────────────────────────

class _GeneralContent extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _GeneralContent({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsProvider,
      builder: (context, _) {
        return Column(
          children: [
            _SettingCard(
              label: '开机自启动',
              description: '系统启动时自动运行 FluxDown',
              child: ShadSwitch(
                value: settingsProvider.autoStartup,
                onChanged: (v) async {
                  final ok = await settingsProvider.setAutoStartup(v);
                  if (!ok && context.mounted) {
                    showShadDialog(
                      context: context,
                      builder: (ctx) => ShadDialog.alert(
                        title: const Text('设置失败'),
                        description: const Text('无法修改开机自启动设置，请检查系统权限。'),
                        actions: [
                          ShadButton(
                            child: const Text('确定'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              label: '关闭时最小化到托盘',
              description: '点击关闭按钮时隐藏到系统托盘，而非退出应用',
              child: ShadSwitch(
                value: settingsProvider.closeToTray,
                onChanged: (v) => settingsProvider.setCloseToTray(v),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 外观设置
// ─────────────────────────────────────────────

class _AppearanceContent extends StatelessWidget {
  const _AppearanceContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingCard(
          label: '主题模式',
          description: '选择亮色、暗色或跟随系统',
          vertical: true,
          child: const _ThemeModeSelector(),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          label: '主题色',
          description: '选择应用的主色调',
          vertical: true,
          child: const _ColorSchemeSelector(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 下载设置
// ─────────────────────────────────────────────

class _DownloadContent extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _DownloadContent({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsProvider,
      builder: (context, _) {
        return Column(
          children: [
            _SettingCard(
              label: '默认保存目录',
              description: '新建下载任务时的默认保存位置',
              vertical: true,
              child: _SaveDirPicker(settingsProvider: settingsProvider),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              label: '默认线程数',
              description: '每个下载任务的默认分片数量',
              child: _SegmentSelector(settingsProvider: settingsProvider),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              label: '最大同时下载数',
              description: '同时进行的最大下载任务数量',
              child: _ConcurrentSelector(settingsProvider: settingsProvider),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              label: '速度限制',
              description: '限制全局下载速度（0 表示不限制）',
              vertical: true,
              child: _SpeedLimitInput(settingsProvider: settingsProvider),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 下载设置子组件
// ─────────────────────────────────────────────

class _SaveDirPicker extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _SaveDirPicker({required this.settingsProvider});

  Future<void> _pickDir(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择默认保存目录',
      initialDirectory: settingsProvider.defaultSaveDir,
    );
    if (result != null) {
      settingsProvider.setDefaultSaveDir(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.border, width: 1),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              settingsProvider.defaultSaveDir,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          onPressed: () => _pickDir(context),
          child: const Text('浏览'),
        ),
      ],
    );
  }
}

class _SegmentSelector extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _SegmentSelector({required this.settingsProvider});

  // 0 = 自动（由 Rust segment_advisor 动态计算最优值）
  static const _options = [0, 4, 8, 16, 32, 64];

  static String _label(int n) => n == 0 ? '自动' : '$n 线程';

  @override
  Widget build(BuildContext context) {
    final current = settingsProvider.defaultSegments;
    return ShadSelect<int>(
      placeholder: const Text('自动'),
      initialValue: current,
      options: _options
          .map((n) => ShadOption(value: n, child: Text(_label(n))))
          .toList(),
      selectedOptionBuilder: (context, value) => Text(_label(value)),
      onChanged: (v) {
        if (v != null) settingsProvider.setDefaultSegments(v);
      },
    );
  }
}

class _ConcurrentSelector extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _ConcurrentSelector({required this.settingsProvider});

  static const _options = [1, 2, 3, 5, 8, 10];

  @override
  Widget build(BuildContext context) {
    final current = settingsProvider.maxConcurrentTasks;
    return ShadSelect<int>(
      placeholder: Text('$current'),
      initialValue: current,
      options: _options
          .map((n) => ShadOption(value: n, child: Text('$n')))
          .toList(),
      selectedOptionBuilder: (context, value) => Text('$value 个任务'),
      onChanged: (v) {
        if (v != null) settingsProvider.setMaxConcurrentTasks(v);
      },
    );
  }
}

class _SpeedLimitInput extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const _SpeedLimitInput({required this.settingsProvider});

  @override
  State<_SpeedLimitInput> createState() => _SpeedLimitInputState();
}

class _SpeedLimitInputState extends State<_SpeedLimitInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final kbps = widget.settingsProvider.speedLimitBytes ~/ 1024;
    _controller = TextEditingController(text: kbps == 0 ? '0' : '$kbps');
  }

  @override
  void didUpdateWidget(_SpeedLimitInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final kbps = widget.settingsProvider.speedLimitBytes ~/ 1024;
    final current = int.tryParse(_controller.text) ?? 0;
    if (kbps != current) {
      _controller.text = kbps == 0 ? '0' : '$kbps';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    final kbps = int.tryParse(value) ?? 0;
    widget.settingsProvider.setSpeedLimitBytes(kbps * 1024);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: ShadInput(
            controller: _controller,
            placeholder: const Text('0'),
            onSubmitted: _onSubmit,
            onChanged: _onSubmit,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'KB/s（0 = 不限制）',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 主题模式选择器（亮色 / 暗色 / 跟随系统）
// ─────────────────────────────────────────────

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  static const _modes = [
    (mode: ThemeMode.system, label: '跟随系统', icon: LucideIcons.monitor),
    (mode: ThemeMode.light, label: '亮色', icon: LucideIcons.sun),
    (mode: ThemeMode.dark, label: '暗色', icon: LucideIcons.moon),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = FluxDownApp.of(context);
    final current = provider.themeMode;
    final c = AppColors.of(context);

    return Row(
      children: [
        for (final item in _modes) ...[
          _ThemeModeCard(
            icon: item.icon,
            label: item.label,
            selected: current == item.mode,
            colors: c,
            onTap: () => provider.setThemeMode(item.mode),
          ),
          if (item != _modes.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ThemeModeCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _ThemeModeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_ThemeModeCard> createState() => _ThemeModeCardState();
}

class _ThemeModeCardState extends State<_ThemeModeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final c = widget.colors;
    final selected = widget.selected;
    final borderColor = selected ? theme.colorScheme.primary : c.border;
    final bgColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.06)
        : _isHovered
        ? c.hoverBg
        : c.bg;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: selected ? theme.colorScheme.primary : c.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? theme.colorScheme.primary : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 主题色选择器
// ─────────────────────────────────────────────

class _ColorSchemeSelector extends StatelessWidget {
  const _ColorSchemeSelector();

  @override
  Widget build(BuildContext context) {
    final provider = FluxDownApp.of(context);
    final current = provider.colorScheme;
    final c = AppColors.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final scheme in AppColorScheme.values)
          _ColorDot(
            scheme: scheme,
            selected: current == scheme,
            colors: c,
            onTap: () => provider.setColorScheme(scheme),
          ),
      ],
    );
  }
}

class _ColorDot extends StatefulWidget {
  final AppColorScheme scheme;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _ColorDot({
    required this.scheme,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_ColorDot> createState() => _ColorDotState();
}

class _ColorDotState extends State<_ColorDot> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return ShadTooltip(
      builder: (_) => Text(widget.scheme.label),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.scheme.previewColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? widget.colors.textPrimary
                    : _isHovered
                    ? widget.colors.textSecondary
                    : widget.scheme.previewColor,
                width: selected
                    ? 2.5
                    : _isHovered
                    ? 1.5
                    : 0,
              ),
              boxShadow: _isHovered || selected
                  ? [
                      BoxShadow(
                        color: widget.scheme.previewColor.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
