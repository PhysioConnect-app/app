// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'ai_models.dart';
import 'ai_service.dart';
import 'financial_ai_audit_service.dart';

// ── Quick suggestion chips ────────────────────────────────────────────────────

const _kSuggestions = [
  'Show unpaid invoices',
  'How much revenue this month?',
  'List expenses above \$500',
  'Add expense: Electricity \$120',
  'Compare this month to last month',
  'What are my top expense categories?',
  'Show overdue invoices',
  'Summarize clinic performance',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class FinancialAiChatScreen extends StatefulWidget {
  const FinancialAiChatScreen({super.key});

  @override
  State<FinancialAiChatScreen> createState() => _FinancialAiChatScreenState();
}

class _FinancialAiChatScreenState extends State<FinancialAiChatScreen> {
  static const _kPrimary = Color(0xFF1565C0);

  final _supabase = Supabase.instance.client;
  final _uid      = Supabase.instance.client.auth.currentUser!.id;

  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  final List<AiChatMessage> _messages = [];
  bool _isSending = false;
  AiUsage? _lastUsage;

  // Cache of financial context — refreshed on each send
  Map<String, dynamic> _revenueCtx  = {};
  Map<String, dynamic> _expenseCtx  = {};

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(AiChatMessage(
      role: ChatRole.assistant,
      content:
          'Hi! I\'m your Financial AI Assistant. I can help you manage revenues, '
          'expenses, and analyze your clinic\'s financial performance.\n\n'
          'Try asking me:\n'
          '• "Show unpaid invoices"\n'
          '• "Add expense: Electricity \$120"\n'
          '• "How much did I collect this month?"',
    ));
  }

  // ── Financial context builder ────────────────────────────────────────────

  Future<void> _refreshFinancialContext() async {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    final end   = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

    // Revenue context
    try {
      final invs = await _supabase
          .from('invoices')
          .select('amount, status, paid_amount, invoice_date')
          .eq('doctor_id', _uid)
          .gte('invoice_date', start)
          .lte('invoice_date', end);

      double collected = 0, pending = 0, overdue = 0;
      int invoiceCount = 0;
      final overdueThreshold =
          DateTime.now().subtract(const Duration(days: 30));

      for (final inv in (invs as List)) {
        final amt = (inv['amount'] as num?)?.toDouble() ?? 0;
        final st  = inv['status'] as String? ?? 'pending';
        if (st == 'cancelled' || st == 'awaiting_review') continue;
        invoiceCount++;
        if (st == 'paid') {
          collected += amt;
        } else if (st == 'partially_paid') {
          final pAmt = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
          collected += pAmt;
          pending   += (amt - pAmt).clamp(0, double.infinity);
        } else {
          final dateStr = inv['invoice_date'] as String?;
          final dt = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
          if (dt.isBefore(overdueThreshold)) {
            overdue += amt;
          } else {
            pending += amt;
          }
        }
      }

      _revenueCtx = {
        'period':       DateFormat('MMMM yyyy').format(now),
        'collected':    'USD ${NumberFormat('#,##0.00').format(collected)}',
        'pending':      'USD ${NumberFormat('#,##0.00').format(pending)}',
        'overdue':      'USD ${NumberFormat('#,##0.00').format(overdue)}',
        'invoiceCount': invoiceCount,
      };
    } catch (_) {
      _revenueCtx = {'period': DateFormat('MMMM yyyy').format(now)};
    }

    // Expense context
    try {
      final exps = await _supabase
          .from('expenses')
          .select('amount, status, category, expense_date')
          .eq('doctor_id', _uid)
          .gte('expense_date', start)
          .lte('expense_date', end);

      double total = 0, expPending = 0;
      final catTotals = <String, double>{};
      for (final exp in (exps as List)) {
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0;
        final cat = exp['category'] as String? ?? 'Other';
        total += amt;
        if ((exp['status'] as String? ?? 'pending') == 'pending') {
          expPending += amt;
        }
        catTotals[cat] = (catTotals[cat] ?? 0) + amt;
      }

      String topCat = '—', topCatAmt = 'USD 0.00';
      if (catTotals.isNotEmpty) {
        final top = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
        topCat    = top.key;
        topCatAmt = 'USD ${NumberFormat('#,##0.00').format(top.value)}';
      }

      _expenseCtx = {
        'period':             DateFormat('MMMM yyyy').format(now),
        'total':              'USD ${NumberFormat('#,##0.00').format(total)}',
        'pendingAmount':      'USD ${NumberFormat('#,##0.00').format(expPending)}',
        'topCategory':        topCat,
        'topCategoryAmount':  topCatAmt,
      };
    } catch (_) {
      _expenseCtx = {'period': DateFormat('MMMM yyyy').format(now)};
    }
  }

  // ── Tool execution engine ────────────────────────────────────────────────

  /// Executes a read tool and returns the result.
  Future<Map<String, dynamic>> _executeReadTool(FinancialActionData action) async {
    final filters = action.filters ?? {};
    final now     = DateTime.now();

    switch (action.type) {
      case 'getRevenueRecords': {
        var fb = _supabase
            .from('invoices')
            .select('id, patient_name, service, amount, currency, status, invoice_date, note')
            .eq('doctor_id', _uid);

        final status = filters['status'] as String?;
        if (status != null && status.isNotEmpty) fb = fb.eq('status', status);
        final dateFrom = filters['dateFrom'] as String?;
        if (dateFrom != null) fb = fb.gte('invoice_date', dateFrom);
        final dateTo = filters['dateTo'] as String?;
        if (dateTo != null) fb = fb.lte('invoice_date', dateTo);

        final rows = await fb.order('invoice_date', ascending: false).limit(20);
        final records = (rows as List).cast<Map<String, dynamic>>();
        return {
          'records': records.map((r) => {
            'id':           r['id'],
            'patientName':  r['patient_name'],
            'service':      r['service'],
            'amount':       r['amount'],
            'status':       r['status'],
            'date':         (r['invoice_date'] as String?)?.split('T').first,
            'note':         r['note'],
          }).toList(),
          'count': records.length,
        };
      }

      case 'getExpenseRecords': {
        var fb = _supabase
            .from('expenses')
            .select('id, category, description, amount, status, expense_date, note')
            .eq('doctor_id', _uid);

        final status = filters['status'] as String?;
        if (status != null && status.isNotEmpty) fb = fb.eq('status', status);
        final category = filters['category'] as String?;
        if (category != null && category.isNotEmpty) {
          fb = fb.ilike('category', '%$category%');
        }
        final dateFrom = filters['dateFrom'] as String?;
        if (dateFrom != null) fb = fb.gte('expense_date', dateFrom);
        final dateTo = filters['dateTo'] as String?;
        if (dateTo != null) fb = fb.lte('expense_date', dateTo);

        final rows = await fb.order('expense_date', ascending: false).limit(20);
        final records = (rows as List).cast<Map<String, dynamic>>();
        return {
          'records': records.map((r) => {
            'id':          r['id'],
            'category':    r['category'],
            'description': r['description'],
            'amount':      r['amount'],
            'status':      r['status'],
            'date':        (r['expense_date'] as String?)?.split('T').first,
          }).toList(),
          'count': records.length,
        };
      }

      case 'getClinicSummary': {
        final start = DateTime(now.year, now.month, 1).toIso8601String();
        final end   = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();
        final prevStart = DateTime(now.year, now.month - 1, 1).toIso8601String();
        final prevEnd   = DateTime(now.year, now.month, 0, 23, 59, 59).toIso8601String();

        final thisMonthInvs = await _supabase
            .from('invoices')
            .select('amount, status')
            .eq('doctor_id', _uid)
            .gte('invoice_date', start)
            .lte('invoice_date', end);

        final prevMonthInvs = await _supabase
            .from('invoices')
            .select('amount, status')
            .eq('doctor_id', _uid)
            .gte('invoice_date', prevStart)
            .lte('invoice_date', prevEnd);

        double thisCollected = 0, prevCollected = 0;
        for (final inv in (thisMonthInvs as List)) {
          if (inv['status'] == 'paid') {
            thisCollected += (inv['amount'] as num?)?.toDouble() ?? 0;
          }
        }
        for (final inv in (prevMonthInvs as List)) {
          if (inv['status'] == 'paid') {
            prevCollected += (inv['amount'] as num?)?.toDouble() ?? 0;
          }
        }

        return {
          'thisMonth':     DateFormat('MMMM yyyy').format(now),
          'collected':     thisCollected,
          'prevMonth':     DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1)),
          'prevCollected': prevCollected,
          'growth':        prevCollected > 0
              ? ((thisCollected - prevCollected) / prevCollected * 100).toStringAsFixed(1)
              : '—',
        };
      }

      default:
        return {'error': 'Unknown read tool: ${action.type}'};
    }
  }

  /// Executes a write tool (add / update / delete) against Supabase.
  Future<Map<String, dynamic>> _executeWriteTool(FinancialActionData action) async {
    final data     = action.data ?? {};
    final recordId = action.recordId;

    switch (action.type) {
      // ── Revenue ──
      case 'addRevenue': {
        final row = {
          'doctor_id':    _uid,
          'patient_name': data['patient_name'] ?? data['patientName'] ?? 'Unknown',
          'service':      data['service'] ?? 'Physical Therapy',
          'amount':       (data['amount'] as num?)?.toDouble() ?? 0,
          'currency':     data['currency'] ?? 'USD',
          'status':       data['status'] ?? 'pending',
          'note':         data['note'] ?? '',
          'invoice_date': data['invoice_date'] ??
              data['invoiceDate'] ??
              DateTime.now().toIso8601String(),
          'created_at':   DateTime.now().toIso8601String(),
        };
        final result = await _supabase.from('invoices').insert(row).select().single();
        await FinancialAiAuditService.log(
          actionType: 'addRevenue',
          recordId:   result['id'] as String?,
          newValue:   row,
        );
        return {'success': true, 'id': result['id'], 'message': 'Revenue record added.'};
      }

      case 'updateRevenue': {
        if (recordId == null) return {'error': 'Record ID required for update.'};
        final existing = await _supabase
            .from('invoices').select().eq('id', recordId).maybeSingle();
        await _supabase.from('invoices').update(data).eq('id', recordId);
        await FinancialAiAuditService.log(
          actionType:    'updateRevenue',
          recordId:      recordId,
          previousValue: existing?.cast<String, dynamic>(),
          newValue:      data,
        );
        return {'success': true, 'message': 'Revenue record updated.'};
      }

      case 'deleteRevenue': {
        if (recordId == null) return {'error': 'Record ID required for delete.'};
        final existing = await _supabase
            .from('invoices').select().eq('id', recordId).maybeSingle();
        await _supabase.from('invoices').delete().eq('id', recordId);
        await FinancialAiAuditService.log(
          actionType:    'deleteRevenue',
          recordId:      recordId,
          previousValue: existing?.cast<String, dynamic>(),
        );
        return {'success': true, 'message': 'Revenue record deleted.'};
      }

      // ── Expenses ──
      case 'addExpense': {
        final row = {
          'doctor_id':    _uid,
          'category':     data['category'] ?? 'Other',
          'description':  data['description'] ?? '',
          'amount':       (data['amount'] as num?)?.toDouble() ?? 0,
          'status':       data['status'] ?? 'pending',
          'note':         data['note'] ?? '',
          'expense_date': data['expense_date'] ??
              data['expenseDate'] ??
              DateTime.now().toIso8601String(),
          'created_at':   DateTime.now().toIso8601String(),
        };
        final result = await _supabase.from('expenses').insert(row).select().single();
        await FinancialAiAuditService.log(
          actionType: 'addExpense',
          recordId:   result['id'] as String?,
          newValue:   row,
        );
        return {'success': true, 'id': result['id'], 'message': 'Expense added.'};
      }

      case 'updateExpense': {
        if (recordId == null) return {'error': 'Record ID required for update.'};
        final existing = await _supabase
            .from('expenses').select().eq('id', recordId).maybeSingle();
        await _supabase.from('expenses').update(data).eq('id', recordId);
        await FinancialAiAuditService.log(
          actionType:    'updateExpense',
          recordId:      recordId,
          previousValue: existing?.cast<String, dynamic>(),
          newValue:      data,
        );
        return {'success': true, 'message': 'Expense updated.'};
      }

      case 'deleteExpense': {
        if (recordId == null) return {'error': 'Record ID required for delete.'};
        final existing = await _supabase
            .from('expenses').select().eq('id', recordId).maybeSingle();
        await _supabase.from('expenses').delete().eq('id', recordId);
        await FinancialAiAuditService.log(
          actionType:    'deleteExpense',
          recordId:      recordId,
          previousValue: existing?.cast<String, dynamic>(),
        );
        return {'success': true, 'message': 'Expense deleted.'};
      }

      default:
        return {'error': 'Unknown write tool: ${action.type}'};
    }
  }

  // ── Send message flow ────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _msgCtrl.clear();
    setState(() {
      _messages.add(AiChatMessage(role: ChatRole.user, content: trimmed));
      _isSending = true;
    });
    _scrollToBottom();

    await _refreshFinancialContext();

    // Build conversation history (exclude welcome, last 6 exchanges)
    final history = _messages
        .where((m) => !m.isLoading)
        .skip(1) // skip welcome
        .map((m) => m.toHistoryMap())
        .toList();
    if (history.isNotEmpty) history.removeLast(); // remove the message we just added

    await _processUserMessage(trimmed, history);

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  Future<void> _processUserMessage(
    String userMessage,
    List<Map<String, dynamic>> history, {
    Map<String, dynamic>? toolResult,
    String? executedTool,
  }) async {
    // Add loading bubble
    final loadingMsg = AiChatMessage(role: ChatRole.assistant, content: '', isLoading: true);
    setState(() => _messages.add(loadingMsg));
    _scrollToBottom();

    final result = await AiDoctorAssistantService.financialChat(
      userMessage:          userMessage,
      revenueContext:       _revenueCtx,
      expenseContext:       _expenseCtx,
      conversationHistory:  history,
      toolResult:           toolResult,
      executedTool:         executedTool,
    );

    // Remove loading bubble
    setState(() => _messages.removeWhere((m) => m.isLoading));

    if (!result.isSuccess) {
      setState(() {
        _messages.add(AiChatMessage(
          role:    ChatRole.assistant,
          content: result.error ?? 'Something went wrong. Please try again.',
        ));
      });
      return;
    }

    if (result.usage != null) _lastUsage = result.usage;

    final chatResult = result.data!;

    switch (chatResult.responseType) {
      case FinancialResponseType.text:
      case FinancialResponseType.clarification:
        setState(() {
          _messages.add(AiChatMessage(
            role:    ChatRole.assistant,
            content: chatResult.message,
          ));
        });

      case FinancialResponseType.action:
        final action = chatResult.action;
        if (action == null) {
          setState(() {
            _messages.add(AiChatMessage(
              role:    ChatRole.assistant,
              content: chatResult.message,
            ));
          });
          return;
        }

        if (action.isReadOnly) {
          // Execute read tools immediately — no confirmation needed
          setState(() {
            _messages.add(AiChatMessage(
              role:    ChatRole.assistant,
              content: chatResult.message,
            ));
          });
          _scrollToBottom();

          try {
            final toolRes = await _executeReadTool(action);
            // Feed result back to AI for a human-readable response
            await _processUserMessage(
              userMessage,
              [
                ...history,
                {'role': 'user',      'content': userMessage},
                {'role': 'assistant', 'content': chatResult.message},
              ],
              toolResult:   toolRes,
              executedTool: action.type,
            );
          } catch (e) {
            setState(() {
              _messages.add(AiChatMessage(
                role:    ChatRole.assistant,
                content: 'I couldn\'t fetch the records: $e',
              ));
            });
          }
        } else {
          // Write action — show confirmation dialog first
          setState(() {
            _messages.add(AiChatMessage(
              role:          ChatRole.assistant,
              content:       chatResult.message,
              pendingAction: action,
            ));
          });
        }
    }
  }

  // ── Confirmation execution ───────────────────────────────────────────────

  Future<void> _confirmAction(AiChatMessage msg) async {
    final action = msg.pendingAction;
    if (action == null) return;

    // Replace pending message with executing state
    setState(() {
      final idx = _messages.indexOf(msg);
      if (idx != -1) {
        _messages[idx] = AiChatMessage(
          role:    ChatRole.assistant,
          content: '${msg.content}\n\n_Executing…_',
        );
      }
    });

    try {
      final toolRes = await _executeWriteTool(action);
      await _refreshFinancialContext();

      // Tell AI the action succeeded to get a confirmation message
      final history = _messages
          .where((m) => !m.isLoading)
          .skip(1)
          .map((m) => m.toHistoryMap())
          .toList();

      await _processUserMessage(
        'Action confirmed and executed.',
        history,
        toolResult:   toolRes,
        executedTool: action.type,
      );
    } catch (e) {
      setState(() {
        _messages.add(AiChatMessage(
          role:    ChatRole.assistant,
          content: 'The action failed: $e\n\nPlease try again or do it manually.',
        ));
      });
    }
  }

  void _cancelAction(AiChatMessage msg) {
    final idx = _messages.indexOf(msg);
    if (idx == -1) return;
    setState(() {
      _messages[idx] = AiChatMessage(
        role:    ChatRole.assistant,
        content: '${msg.content}\n\n_Action cancelled._',
      );
    });
  }

  // ── Scroll ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financial AI Assistant',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text('Powered by AI Doctor Assistant',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ]),
        actions: [
          if (_lastUsage != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_lastUsage!.remaining} left',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────────────────────

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isUser = msg.role == ChatRole.user;

    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4, offset: const Offset(0, 2),
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 10),
            Text('Thinking…',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic)),
          ]),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10,
          left:  isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _kPrimary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4, offset: const Offset(0, 2),
                )],
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1A2332),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            // Confirmation buttons for pending write actions
            if (msg.pendingAction != null && !msg.pendingAction!.isReadOnly)
              _buildConfirmationBar(msg),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                DateFormat('HH:mm').format(msg.timestamp),
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationBar(AiChatMessage msg) {
    final action = msg.pendingAction!;
    final isDelete = action.type.contains('delete') || action.type.contains('Delete');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDelete
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDelete
                    ? const Color(0xFFC62828).withValues(alpha: 0.3)
                    : _kPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    isDelete ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: isDelete ? const Color(0xFFC62828) : _kPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDelete ? 'Confirm Delete' : 'Action Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDelete ? const Color(0xFFC62828) : _kPrimary,
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(action.description,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
                if (action.data != null && action.data!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._buildDataPreview(action.data!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel', style: TextStyle(fontSize: 13)),
                onPressed: () => _cancelAction(msg),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDelete
                      ? const Color(0xFFC62828)
                      : _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                icon: Icon(
                  isDelete ? Icons.delete_rounded : Icons.check_rounded,
                  size: 16,
                ),
                label: Text(
                  isDelete ? 'Delete' : 'Confirm',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _confirmAction(msg),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildDataPreview(Map<String, dynamic> data) {
    final displayKeys = ['category', 'description', 'amount', 'status',
                         'expense_date', 'patient_name', 'service',
                         'invoice_date', 'note'];
    return data.entries
        .where((e) => displayKeys.contains(e.key) && e.value != null)
        .map((e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Text(
                    '${_prettyKey(e.key)}: ',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  Flexible(
                    child: Text(
                      '${e.value}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  String _prettyKey(String key) => switch (key) {
    'patient_name'  => 'Patient',
    'invoice_date'  => 'Date',
    'expense_date'  => 'Date',
    'category'      => 'Category',
    'description'   => 'Description',
    'amount'        => 'Amount',
    'status'        => 'Status',
    'service'       => 'Service',
    'note'          => 'Note',
    _               => key,
  };

  // ── Suggestion chips ──────────────────────────────────────────────────────

  Widget _buildSuggestions() {
    if (_messages.length > 2) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _kSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_kSuggestions[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
            ),
            child: Text(
              _kSuggestions[i],
              style: TextStyle(
                  color: _kPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller:  _msgCtrl,
            focusNode:   _focusNode,
            maxLines:    4,
            minLines:    1,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Ask anything about your finances…',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 14),
              filled:    true,
              fillColor: const Color(0xFFF0F4FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
            onSubmitted: (v) {
              if (!_isSending) _send(v);
            },
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isSending ? null : () => _send(_msgCtrl.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _isSending
                  ? Colors.grey.shade300
                  : _kPrimary,
              shape: BoxShape.circle,
            ),
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
