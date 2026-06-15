import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';

/// 数据库调试页面 - 可视化查看所有表数据
class DatabaseViewerPage extends StatefulWidget {
  const DatabaseViewerPage({super.key});

  @override
  State<DatabaseViewerPage> createState() => _DatabaseViewerPageState();
}

class _DatabaseViewerPageState extends State<DatabaseViewerPage> {
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ========== 样式常量 ==========
  static const double _defaultPadding = 16.0;
  static const double _dropdownRadius = 8.0;
  static const Color _backgroundColor = Colors.white;
  static const Color _textPrimary = Colors.black;
  static const Color _textSecondary = Colors.grey;
  static const Color _errorBackground = Color(0xFFFFF0F0);
  static const Color _errorBorder = Color(0xFFFFCDD2);
  static const Color _errorText = Color(0xFFD32F2F);
  static const Color _tableBorder = Color(0xFFE0E0E0);
  static const Color _recordCountColor = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  /// 加载所有表名
  Future<void> _loadTables() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tables = await AppDatabase().getAllTableNames();
      setState(() {
        _tables = tables;
        _isLoading = false;
        if (tables.isNotEmpty && _selectedTable == null) {
          _selectedTable = tables.first;
          _loadData();
        }
      });
    } catch (e) {
      debugPrint('加载表列表失败: $e');
      setState(() {
        _tables = [];
        _isLoading = false;
        _errorMessage = '加载表列表失败: $e';
      });
    }
  }

  /// 加载选中表的数据
  Future<void> _loadData() async {
    if (_selectedTable == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AppDatabase().queryTable(_selectedTable!);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('查询表 $_selectedTable 失败: $e');
      setState(() {
        _data = [];
        _isLoading = false;
        _errorMessage = '查询失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          _buildTableSelector(),
          if (_selectedTable != null) _buildRecordCount(),
          const SizedBox(height: 8),
          if (_errorMessage != null) _buildErrorMessage(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _selectedTable != null) _buildDataArea(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('数据库调试'),
      backgroundColor: _backgroundColor,
      foregroundColor: _textPrimary,
      elevation: 0,
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTables),
      ],
    );
  }

  Widget _buildTableSelector() {
    return Container(
      margin: const EdgeInsets.all(_defaultPadding),
      padding: const EdgeInsets.symmetric(horizontal: _defaultPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(_dropdownRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTable,
          isExpanded: true,
          hint: const Text('选择表'),
          items: _tables
              .map((table) => DropdownMenuItem(value: table, child: Text(table)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedTable = value);
              _loadData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildRecordCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _defaultPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '共 ${_data.length} 条记录',
          style: const TextStyle(color: _recordCountColor, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.all(_defaultPadding),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorBackground,
        borderRadius: BorderRadius.circular(_dropdownRadius),
        border: Border.all(color: _errorBorder),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: _errorText),
      ),
    );
  }

  Widget _buildDataArea() {
    if (_data.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_defaultPadding),
          child: _buildDataTable(),
        ),
      ),
    );
  }

  /// 构建数据表格
  Widget _buildDataTable() {
    if (_data.isEmpty) return const SizedBox.shrink();

    final columns = _data.first.keys.toList();

    return DataTable(
      border: TableBorder.all(color: _tableBorder),
      columns: columns
          .map((col) => DataColumn(
        label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold)),
      ))
          .toList(),
      rows: _data.map((row) {
        return DataRow(
          cells: columns.map((col) {
            final value = row[col];
            return DataCell(Text(value?.toString() ?? 'NULL'));
          }).toList(),
        );
      }).toList(),
    );
  }
}