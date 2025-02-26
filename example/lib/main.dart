import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';

class DioClient {
  late final Dio dio;
  late final SmartCache smartCache;
  bool _isInitialized = false;

  DioClient._internal() {
    dio = Dio();
  }

  static final DioClient _instance = DioClient._internal();

  factory DioClient() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initializes SmartCache with the new SQLite-based implementation
    // Sets a default expiration time of 10 minutes
    // Now also configures automatic maintenance to take place every 30 minutes
    smartCache = SmartCache(
      defaultExpiration: const Duration(minutes: 10),
      maintenanceInterval: const Duration(minutes: 30),
    );

    dio.interceptors.add(CacheInterceptor(smartCache));

    _isInitialized = true;
  }

  Future<Response> get(
    String url, {
    bool cache = false,
    Duration? cacheExpiration,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final extraOptions = <String, dynamic>{'cache': cache};

    if (cacheExpiration != null) {
      extraOptions['cacheExpiration'] = cacheExpiration;
    }

    final options = Options(extra: extraOptions);
    final response = await dio.get(url, options: options);

    if (response.extra.containsKey('fromCache')) {
      print('Data obtained from the cache: $url');

      if (response.extra.containsKey('cacheTimestamp')) {
        final timestamp = response.extra['cacheTimestamp'] as DateTime;
        print('Cache timestamp: ${timestamp.toIso8601String()}');
      }
    } else {
      print('Data obtained from the network: $url');
    }

    return response;
  }

  Future<void> clearCache() async {
    if (_isInitialized) {
      await smartCache.clear();
    }
  }

  // Method for cache maintenance (removing expired entries)
  // This is now done automatically by SmartCache
  Future<void> performCacheMaintenance() async {
    if (_isInitialized) {
      await smartCache.maintenance();
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await smartCache.close();
      _isInitialized = false;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DioClient().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SmartCache Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String data = 'Dados ainda não carregados';
  bool isLoading = false;
  bool fromCache = false;
  String cacheInfo = '';

  final List<Map<String, dynamic>> endpoints = [
    {
      'name': 'Posts (10 min - default)',
      'url': 'https://jsonplaceholder.typicode.com/posts/1',
      'expiration': null,
    },
    {
      'name': 'Comments (30 sec)',
      'url': 'https://jsonplaceholder.typicode.com/comments/1',
      'expiration': const Duration(seconds: 30),
    },
    {
      'name': 'Albums (1 hour)',
      'url': 'https://jsonplaceholder.typicode.com/albums/1',
      'expiration': const Duration(hours: 1),
    },
  ];

  int selectedEndpointIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    DioClient().dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      fromCache = false;
      cacheInfo = '';
    });

    try {
      final endpoint = endpoints[selectedEndpointIndex];

      final response = await DioClient().get(
        endpoint['url'],
        cache: true,
        cacheExpiration: endpoint['expiration'],
      );

      String cacheDetails = '';
      if (response.extra['fromCache'] == true &&
          response.extra.containsKey('cacheTimestamp')) {
        final timestamp = response.extra['cacheTimestamp'] as DateTime;
        final now = DateTime.now();
        final age = now.difference(timestamp);

        cacheDetails = 'Cache age: ${age.inSeconds} seconds';
      }

      setState(() {
        data = response.data.toString();
        isLoading = false;
        fromCache = response.extra['fromCache'] == true;
        cacheInfo = cacheDetails;
      });
    } catch (e) {
      setState(() {
        data = 'Error loading data: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      isLoading = true;
    });

    await DioClient().clearCache();

    setState(() {
      data = 'Cache cleared successfully';
      isLoading = false;
      fromCache = false;
      cacheInfo = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartCache Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: selectedEndpointIndex,
                hint: const Text('Select an endpoint'),
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      selectedEndpointIndex = value;
                    });
                    _fetchData();
                  }
                },
                items: List.generate(
                  endpoints.length,
                  (index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text(endpoints[index]['name']),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Data request:'),
              const SizedBox(height: 10),
              if (fromCache)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.amber.shade100,
                  child: Column(
                    children: [
                      const Text('Data from cache',
                          style: TextStyle(color: Colors.deepOrange)),
                      if (cacheInfo.isNotEmpty)
                        Text(cacheInfo,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.deepOrange))
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (isLoading)
                const CircularProgressIndicator()
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(child: Text(data)),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _fetchData,
                    child: const Text('Reload Data'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _clearCache,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade300,
                    ),
                    child: const Text('Clear Cache'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.blue.shade50,
                child: const Text(
                  'The cache is automatically cleared every 30 minutes.\n'
                  'Manual cleaning is no longer necessary.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
