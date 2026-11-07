import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MobileIDEApp());
}

class MobileIDEApp extends StatelessWidget {
  const MobileIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile IDE',
      theme: ThemeData.dark(useMaterial3: true),
      home: const IDEScreen(),
    );
  }
}

class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  WebViewController? _webViewController;
  String currentFilePath = '';
  String currentFileContent = '<!-- قم باختيار ملف أو إنشاء ملف جديد -->';
  List<FileSystemEntity> _files = [];
  Directory? _projectDir;

  @override
  void initState() {
    super.initState();
    _requestStoragePermissionAndInit();
    _initWebView();
  }

  // 1. طلب أذونات التخزين وتهيئة المجلد الأساسي للمشروع
  Future<void> _requestStoragePermissionAndInit() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final docDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${docDir.path}/MyProject');
    if (!await projectDir.exists()) {
      await projectDir.create();
      // إنشاء ملف افتراضي
      final defaultFile = File('${projectDir.path}/index.html');
      await defaultFile.writeAsString('<!DOCTYPE html>\n<html>\n<body>\n  <h1>مرحباً بك في المحرر!</h1>\n</body>\n</html>');
    }

    setState(() {
      _projectDir = projectDir;
    });
    _loadFileList();
  }

  // جلب قائمة الملفات
  void _loadFileList() {
    if (_projectDir != null) {
      setState(() {
        _files = _projectDir!.listSync();
      });
    }
  }

  // 2. تهيئة محرر الكود (Monaco Editor عبر HTML/JS)
  void _initWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_getMonacoHtml(currentFileContent));

    setState(() {
      _webViewController = controller;
    });
  }

  // قراءة الملف المحدد وتحديث المحرر
  Future<void> _openFile(File file) async {
    final content = await file.readAsString();
    setState(() {
      currentFilePath = file.path;
      currentFileContent = content;
    });
    _webViewController?.loadHtmlString(_getMonacoHtml(content));
  }

  // حفظ التعديلات على الملف الحالي
  Future<void> _saveFile() async {
    if (currentFilePath.isNotEmpty && _webViewController != null) {
      // استخراج النص من المحرر
      final String? content = await _webViewController?.runJavaScriptReturningResult(
        'editor.getValue()'
      ) as String?;

      if (content != null) {
        // تنظيف السلسلة النصية القادمة من JS
        String cleanContent = content.replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
        if (cleanContent.startsWith('"') && cleanContent.endsWith('"')) {
          cleanContent = cleanContent.substring(1, cleanContent.length - 1);
        }
        await File(currentFilePath).writeAsString(cleanContent);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الملف بنجاح! 💾')),
        );
      }
    }
  }

  // إنشاء ملف جديد
  Future<void> _createNewFile() async {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء ملف جديد'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'اسم الملف (مثال: script.js)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && _projectDir != null) {
                final newFile = File('${_projectDir!.path}/${nameController.text}');
                await newFile.writeAsString('');
                Navigator.pop(context);
                _loadFileList();
                _openFile(newFile);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  // قوالب HTML لتشغيل محرر Monaco المحمول
  String _getMonacoHtml(String code) {
    String escapedCode = code.replaceAll('`', r'\`').replaceAll(r'$', r'\$');
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
      <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.39.0/min/vs/loader.min.js"></script>
      <style>
        html, body, #container { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; background-color: #1e1e1e; }
      </style>
    </head>
    <body>
      <div id="container"></div>
      <script>
        require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.39.0/min/vs' }});
        var editor;
        require(['vs/editor/editor.main'], function() {
          editor = monaco.editor.create(document.getElementById('container'), {
            value: `$escapedCode`,
            language: 'html',
            theme: 'vs-dark',
            automaticLayout: true,
            fontSize: 14,
            minimap: { enabled: false } // إيقاف الخريطة المصغرة لتوفير مساحة الشاشة
          });
        });
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentFilePath.split('/').last.isEmpty ? 'Mobile IDE' : currentFilePath.split('/').last),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.greenAccent),
            onPressed: _saveFile,
            tooltip: 'حفظ الملف',
          ),
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("مشروعي الحالي"),
              accountEmail: Text(_projectDir?.path ?? "جاري التحميل..."),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.folder),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('ملف جديد'),
              onTap: _createNewFile,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final fileName = file.path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    title: Text(fileName),
                    onTap: () {
                      if (file is File) {
                        _openFile(file);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: _webViewController == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _webViewController!),
    );
  }
}
