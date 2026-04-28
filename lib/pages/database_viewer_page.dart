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
        if (tables.isNotEmpty) {
          _selectedTable = tables.first;
          _loadData();
        }
      });
    } catch (e) {
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
      appBar: AppBar(
        title: const Text('数据库调试'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTables),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 表选择下拉框
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTable,
                isExpanded: true,
                hint: const Text('选择表'),
                items: _tables.map((table) {
                  return DropdownMenuItem<String>(
                    value: table,
                    child: Text(table),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedTable = value;
                    });
                    _loadData();
                  }
                },
              ),
            ),
          ),

          // 记录数显示
          if (_selectedTable != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '共 ${_data.length} 条记录',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // 错误提示
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),

          // 加载中
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          // 数据表格
          if (!_isLoading && _selectedTable != null)
            Expanded(
              child: _data.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildDataTable(),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  /// 构建数据表格
  Widget _buildDataTable() {
    if (_data.isEmpty) return const SizedBox.shrink();

    // 获取所有列名
    final columns = _data.first.keys.toList();

    return DataTable(
      border: TableBorder.all(color: Colors.grey.shade300),
      columns: columns.map((col) {
        return DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      }).toList(),
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
