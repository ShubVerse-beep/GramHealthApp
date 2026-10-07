import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/offline_status_indicator.dart';
import '../widgets/offline_setup_card.dart';
import '../models/local_model_status.dart';
import '../services/connectivity_service.dart';
import '../services/ai_service.dart';
import '../services/offline_ai_service.dart';

class Message {
  final String id;
  final String text;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final bool isOffline;

  Message({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isOffline = false,
  });
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final List<Message> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<LocalModelStatus>? _modelSub;
  StreamSubscription<NetworkStatus>? _connSub;
  bool _showSetupCard = true;

  @override
  void initState() {
    super.initState();
    unawaited(OfflineAiService.instance.ensureModelLoaded());

    _modelSub = OfflineAiService.instance.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
    _connSub = ConnectivityService.instance.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add(
        Message(
          id: '1',
          text: "${context.tr('greeting')} ${context.tr('dihati_assistant')}. ${context.tr('ask_health')}",
          sender: 'ai',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _modelSub?.cancel();
    _connSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _statusSubtitle {
    final isOnline = ConnectivityService.instance.currentStatus != NetworkStatus.offline;
    if (isOnline) return 'AI • Online';
    
    final offlineService = OfflineAiService.instance;
    final status = offlineService.modelStatus;
    switch (status) {
      case LocalModelStatus.downloading:
        return 'Offline AI • Downloading ${(offlineService.downloadProgress * 100).toInt()}%';
      case LocalModelStatus.verifying:
        return 'Offline AI • Verifying';
      case LocalModelStatus.verified:
        return 'Offline AI • Verified';
      case LocalModelStatus.compatible:
        return 'Offline AI • Compatible';
      case LocalModelStatus.loadable:
      case LocalModelStatus.ready:
        return 'Offline AI • Ready';
      case LocalModelStatus.loading:
        return 'Offline AI • Starting';
      case LocalModelStatus.generating:
        return 'Offline AI • Thinking';
      case LocalModelStatus.lexiconOnly:
        return 'Offline AI • Knowledge mode';
      case LocalModelStatus.checking:
        return 'Offline AI • Checking';
      case LocalModelStatus.pending:
        return 'Offline AI • Download pending';
      case LocalModelStatus.error:
        return 'Offline AI • Retry pending';
      default:
        return 'AI • Offline';
    }
  }

  Color get _statusColor {
    final isOnline = ConnectivityService.instance.currentStatus != NetworkStatus.offline;
    return isOnline ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);
  }

  Future<void> _handleSend() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: 'user',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _inputCtrl.clear();
    });

    _scrollToBottom();

    try {
      final aiResponse = await AiService.query(text);
      
      if (!mounted) return;
      
      String responseText = aiResponse.answer ?? "I'm sorry, I couldn't understand that.";
      if (aiResponse.urgency == 'emergency') {
        responseText = "🚨 EMERGENCY 🚨\n$responseText";
      } else if (aiResponse.requiresProfessionalReview == true) {
        responseText = "⚠️ Please consult a professional.\n$responseText";
      }

      final bool isOffline = (aiResponse.agent == 'offline_ai_router') ||
          (aiResponse.routingMethod?.contains('offline') ?? false);

      final aiMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: responseText,
        sender: 'ai',
        timestamp: DateTime.now(),
        isOffline: isOffline,
      );
      
      setState(() {
        _messages.add(aiMsg);
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Sorry, I encountered an error: ${e.toString()}",
        sender: 'ai',
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMsg);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isErrorMessage(Message msg) =>
      msg.sender == 'ai' && msg.text.startsWith('Sorry, I encountered an error');

  bool _isEmergencyMessage(Message msg) =>
      msg.sender == 'ai' && msg.text.startsWith('🚨 EMERGENCY');

  @override
  Widget build(BuildContext context) {
    final isOnline = ConnectivityService.instance.currentStatus != NetworkStatus.offline;
    final showTyping = _pendingReplies > 0;
    final itemCount = _messages.length + (showTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.secondaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              title: context.tr('dihati_assistant'),
              subtitle: _statusSubtitle,
              statusColor: _statusColor,
              isOnline: isOnline,
              onBack: () => context.pop(),
            ),

            // Optional Offline Setup Banner
            if (_showSetupCard &&
                ConnectivityService.instance.currentStatus == NetworkStatus.offline &&
                OfflineAiService.instance.modelStatus != LocalModelStatus.ready &&
                OfflineAiService.instance.modelStatus != LocalModelStatus.loaded &&
                OfflineAiService.instance.modelStatus != LocalModelStatus.generating &&
                OfflineAiService.instance.modelStatus != LocalModelStatus.lexiconOnly) ...[
              OfflineSetupCard(
                onDismiss: () => setState(() => _showSetupCard = false),
              ),
            ],

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return const _MessageEntrance(
                      key: ValueKey('typing-indicator'),
                      animate: true,
                      child: _TypingIndicator(),
                    );
                  }
                  final msg = _messages[index];
                  final prev = index > 0 ? _messages[index - 1] : null;
                  final groupedWithPrevious = prev != null && prev.sender == msg.sender;
                  return _MessageEntrance(
                    key: ValueKey('msg-${msg.id}-${msg.sender}'),
                    animate: DateTime.now().difference(msg.timestamp) < const Duration(seconds: 1),
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : (groupedWithPrevious ? 6 : 18),
                      ),
                      child: _MessageBubble(
                        message: msg,
                        showAvatar: !groupedWithPrevious,
                        isError: _isErrorMessage(msg),
                        isEmergency: _isEmergencyMessage(msg),
                      ),
                    ),
                  );
                },
              ),
            ),

            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.leafGreenPale)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _inputFocus,
              builder: (context, _) {
                final focused = _inputFocus.hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: focused ? Colors.white : AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: focused ? AppColors.primaryAccent : AppColors.leafGreenPale,
                      width: focused ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: AppColors.primaryAccent,
                    style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: context.tr('ask_health'),
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(fontSize: 14.5, color: AppColors.textMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _inputCtrl,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return _SendButton(enabled: hasText, onPressed: _handleSend);
            },
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color statusColor;
  final bool isOnline;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.statusColor,
    required this.isOnline,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.leafGreenPale)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textDark),
          ),
          const SizedBox(width: 2),
          const _AssistantAvatar(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, if (current != null) current],
                        ),
                        child: Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OfflineStatusIndicator(isOnline: isOnline),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  final double size;

  const _AssistantAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.leafGreenPale,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.health_and_safety_rounded,
        size: size * 0.56,
        color: AppColors.leafGreenPrimary,
      ),
    );
  }
}

class _MessageEntrance extends StatefulWidget {
  final bool animate;
  final Widget child;

  const _MessageEntrance({super.key, required this.animate, required this.child});

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool isError;
  final bool isEmergency;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.isError,
    required this.isEmergency,
  });

  String get _time =>
      "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return message.sender == 'user' ? _buildUser(screenWidth) : _buildAssistant(screenWidth);
  }

  Widget _buildUser(double screenWidth) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.leafGreenPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: Radius.circular(showAvatar ? 18 : 8),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(6),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 15, height: 1.45, color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(_time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistant(double screenWidth) {
    const avatarSize = 30.0;
    final isAlert = isError || isEmergency;
    final accent = isAlert
        ? AppColors.error
        : (message.isOffline ? const Color(0xFFE65100) : AppColors.leafGreenPrimary);
    final label = message.isOffline ? 'AI • Offline' : 'AI • Online';

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.86),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            showAvatar ? const _AssistantAvatar(size: avatarSize) : const SizedBox(width: avatarSize),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: isAlert ? const Color(0xFFFFF6F6) : Colors.white,
                      border: Border.all(
                        color: isAlert ? AppColors.error.withValues(alpha: 0.35) : AppColors.leafGreenPale,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(showAvatar ? 6 : 18),
                        topRight: const Radius.circular(18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAlert)
                              Icon(
                                isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                                size: 14,
                                color: accent,
                              )
                            else
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          message.text,
                          style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(_time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Semantics(
        liveRegion: true,
        label: 'Assistant is typing',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AssistantAvatar(size: 30),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.leafGreenPale),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = (_ctrl.value - i * 0.18) % 1.0;
                    final wave = math.sin(phase * math.pi).clamp(0.0, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                      child: Transform.translate(
                        offset: Offset(0, -3 * wave),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent.withValues(alpha: 0.35 + 0.65 * wave),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SendButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Send',
      child: AnimatedScale(
        scale: enabled ? 1 : 0.92,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? AppColors.leafGreenPrimary : AppColors.leafGreenPale,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onPressed : null,
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 22,
                color: enabled ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
