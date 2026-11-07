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
      title: 'Bisho IDE',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1e1e1e)),
      ),
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
  }

  // 1. طلب أذونات التخزين وتهيئة المجلد الأساسي للمشروع
  Future<void> _requestStoragePermissionAndInit() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final docDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${docDir.path}/BishoProject');
    if (!await projectDir.exists()) {
      await projectDir.create();
      final defaultFile = File('${projectDir.path}/index.html');
      await defaultFile.writeAsString('''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>مرحباً بك في Bisho IDE</title>
    <style>
        body { font-family: Tahoma, sans-serif; background: #121212; color: #fff; text-align: center; padding-top: 50px; }
        h1 { color: #ff79c6; }
        p { color: #8be9fd; }
    </style>
</head>
<body>
    <h1>مرحباً بك في محرك بيشو توب!</h1>
    <p>هذا الموقع تم كتابته وتنسيقه بالكامل من الهاتف المحمول.</p>
</body>
</html>''');
    }

    setState(() {
      _projectDir = projectDir;
    });
    _loadFileList();
    
    final defaultOpen = File('${projectDir.path}/index.html');
    if (defaultOpen.existsSync()) {
      _openFile(defaultOpen);
    }
  }

  // جلب قائمة الملفات
  void _loadFileList() {
    if (_projectDir != null) {
      setState(() {
        _files = _projectDir!.listSync();
      });
    }
  }

  // 2. تهيئة محرر الكود (Monaco Editor) مع تفعيل التركيز التلقائي
  void _initWebView(String content) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..loadHtmlString(_getMonacoHtml(content));

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
    _initWebView(content);
  }

  // حذف ملف من المشروع
  Future<void> _deleteFile(File file) async {
    final fileName = file.path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملف'),
        content: Text('هل أنت متأكد من حذف الملف "$fileName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (await file.exists()) {
                await file.delete();
              }
              Navigator.pop(context);
              _loadFileList();
              // إذا كان الملف المحذوف هو المفتوح حالياً، قم بتفريغ المحرر
              if (currentFilePath == file.path) {
                setState(() {
                  currentFilePath = '';
                  currentFileContent = '<!-- قم باختيار ملف آخر -->';
                });
                _initWebView(currentFileContent);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الملف بنجاح! 🗑️', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // حفظ التعديلات على الملف الحالي
  Future<void> _saveFile() async {
    if (currentFilePath.isNotEmpty && _webViewController != null) {
      final String? content = await _webViewController?.runJavaScriptReturningResult(
        'editor.getValue()'
      ) as String?;

      if (content != null) {
        String cleanContent = content;
        if (cleanContent.startsWith('"') && cleanContent.endsWith('"')) {
          cleanContent = cleanContent.substring(1, cleanContent.length - 1);
        }
        cleanContent = cleanContent.replaceAll(r'\"', '"').replaceAll(r'\n', '\n').replaceAll(r'\t', '\t');
        
        await File(currentFilePath).writeAsString(cleanContent);
        setState(() {
          currentFileContent = cleanContent;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الملف بنجاح! 💾', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // 3. تنسيق الكود تلقائياً (Code Formatter)
  Future<void> _formatCode() async {
    if (_webViewController != null) {
      await _webViewController?.runJavaScript(
        "editor.getAction('editor.action.formatDocument').run()"
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تنسيق وترتيب الكود بنجاح! ✨', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.purpleAccent,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // 4. فحص الأخطاء (Diagnostics Checker)
  Future<void> _checkErrors() async {
    if (_webViewController != null) {
      final String? markersJson = await _webViewController?.runJavaScriptReturningResult(
        "JSON.stringify(monaco.editor.getModelMarkers({}))"
      ) as String?;

      int errorCount = 0;
      if (markersJson != null && markersJson.length > 4) {
        errorCount = markersJson.split('severity').length - 1;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تقرير فحص الأخطاء 🔍'),
          content: Text(
            errorCount > 0 
              ? 'تم العثور على $errorCount مشكلة أو خطأ في الكود. تحقق من الخطوط الحمراء داخل المحرر.'
              : 'ممتاز! الكود خالي من الأخطاء الظاهرة وحسب القواعد البرمجية. ✅',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  // 5. تشغيل المعاينة الحية للموقع
  Future<void> _openLivePreview() async {
    if (_webViewController != null) {
      final String? content = await _webViewController?.runJavaScriptReturningResult(
        'editor.getValue()'
      ) as String?;

      String previewContent = content ?? currentFileContent;
      if (previewContent.startsWith('"') && previewContent.endsWith('"')) {
        previewContent = previewContent.substring(1, previewContent.length - 1);
      }
      previewContent = previewContent.replaceAll(r'\"', '"').replaceAll(r'\n', '\n').replaceAll(r'\t', '\t');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(htmlContent: previewContent),
        ),
      );
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

  // قوالب HTML لتشغيل محرر Monaco المحمول مع تفعيل التركيز التلقائي
  String _getMonacoHtml(String code) {
    String escapedCode = code.replaceAll('`', r'\`').replaceAll(r'$', r'\$');
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
      <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.39.0/min/vs/loader.min.js"></script>
      <style>
        html, body, #container { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; background-color: #121212; }
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
            minimap: { enabled: false }
          });
          // تركيز تلقائي للمحرر ليبدأ في استقبال الكتابة فوراً
          setTimeout(function() {
            editor.focus();
          }, 300);
        });
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    String fileName = currentFilePath.isEmpty ? 'Bisho IDE' : currentFilePath.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.pinkAccent),
            onPressed: _formatCode,
            tooltip: 'تنسيق الكود',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: Colors.amberAccent),
            onPressed: _checkErrors,
            tooltip: 'فحص الأخطاء',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
            onPressed: _openLivePreview,
            tooltip: 'معاينة حية',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.cyanAccent),
            onPressed: _saveFile,
            tooltip: 'حفظ الملف',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1e1e1e)),
              accountName: const Text("محرك Bisho IDE"),
              accountEmail: Text(_projectDir?.path ?? "جاري التحميل..."),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.purpleAccent,
                child: Icon(Icons.code, color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.amber),
              title: const Text('ملف جديد'),
              onTap: _createNewFile,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final name = file.path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    title: Text(name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        if (file is File) {
                          _deleteFile(file);
                        }
                      },
                    ),
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

// شاشة المعاينة الحية
class PreviewScreen extends StatelessWidget {
  final String htmlContent;
  const PreviewScreen({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final previewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعاينة الحية (Live Preview)'),
        backgroundColor: const Color(0xFF1e1e1e),
      ),
      body: WebViewWidget(controller: previewController),
    );
  }
}
